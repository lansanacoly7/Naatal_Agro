"""
Orchestration des fournisseurs de modèles de langage (cahier des charges §7, §8 et §10).

Objectifs, dans l'ordre :
1. Le reste de l'application ne connaît AUCUN fournisseur : il demande une réponse à ``generate`` et reçoit un
   ``LLMResult`` (texte, ou raison précise de l'échec). Changer ou ajouter un fournisseur = écrire une classe
   ``Provider`` et l'inscrire dans ``PROVIDER_CLASSES`` ; rien d'autre ne change.
2. Une demande ne dépasse JAMAIS son budget de temps (``AI_TOTAL_BUDGET_SECONDS``, 40 s par défaut, sous le timeout
   de 60 s de gunicorn/nginx), quel que soit le nombre de fournisseurs et de modèles de repli essayés. L'ancien
   enchaînement pouvait durer plus de deux minutes et finissait en erreur 502.
3. Un fournisseur en panne n'est pas rappelé à chaque demande : un disjoncteur le met de côté quelques instants.
4. Chaque tentative est journalisée (``LLMUsage``) sans jamais enregistrer le texte échangé.
5. Une analyse de photo n'est JAMAIS repliée vers un modèle sans vision : il « analyserait » une image qu'il ne voit pas.
"""
import dataclasses
import logging
import threading
import time
from dataclasses import dataclass, field

import requests
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone

from .prompt_safety import clean_model_output

logger = logging.getLogger(__name__)

CONNECT_TIMEOUT = 4.0       # secondes pour établir la connexion
MIN_ATTEMPT_SECONDS = 2.0   # en dessous, on n'ouvre plus de tentative : elle n'aurait aucune chance d'aboutir

# Raisons d'échec d'une tentative
TIMEOUT, RATE_LIMITED, AUTH, SERVER, BAD_RESPONSE, NETWORK = (
    'timeout', 'rate_limited', 'auth', 'server', 'bad_response', 'network')
# Résultat global
OK, NOT_CONFIGURED, UNAVAILABLE, BUDGET_EXHAUSTED, DAILY_LIMIT, UNUSABLE = (
    'ok', 'not_configured', 'unavailable', 'budget_exhausted', 'daily_limit', 'unusable')

FAILURES_BEFORE_COOLDOWN = 3
FAILURE_WINDOW_SECONDS = 120
SHORT_COOLDOWN_SECONDS = 30
AUTH_COOLDOWN_SECONDS = 600
MISSING_MODEL_COOLDOWN_SECONDS = 300


class ProviderError(Exception):
    """Échec d'une tentative auprès d'un fournisseur (jamais le texte de la requête ni de la réponse)."""

    def __init__(self, kind, message='', retry_after=None, permanent=False):
        super().__init__(message or kind)
        self.kind = kind
        self.retry_after = retry_after
        self.permanent = permanent  # ex. modèle inexistant : inutile de réessayer avant longtemps


@dataclass(frozen=True)
class LLMRequest:
    system: str
    prompt: str
    image_base64: str | None = None
    image_mime: str = 'image/jpeg'
    max_tokens: int = 700
    temperature: float = 0.3
    feature: str = 'chat'  # chat | vision | advice (pour le journal d'usage)


@dataclass(frozen=True)
class Unit:
    """Une façon d'interroger un fournisseur : une clé (par rang) et un modèle."""
    provider: str
    credential: int
    model: str

    @property
    def label(self):
        return f"{self.provider}#{self.credential}/{self.model}"

    @property
    def credential_scope(self):
        return f"{self.provider}#{self.credential}"


@dataclass
class Completion:
    text: str
    prompt_tokens: int | None = None
    completion_tokens: int | None = None


@dataclass
class Attempt:
    unit: str
    ok: bool
    kind: str
    latency_ms: int


@dataclass
class LLMResult:
    text: str | None
    reason: str
    provider: str = ''
    model: str = ''
    attempts: list = field(default_factory=list)
    latency_ms: int = 0

    @property
    def ok(self):
        return self.text is not None


# --------------------------------------------------------------------------------------------------------------
# Fournisseurs
# --------------------------------------------------------------------------------------------------------------
def _csv(value):
    return [item.strip() for item in str(value or '').split(',') if item.strip()]


def _unique(items):
    return list(dict.fromkeys(item for item in items if item))


def _check_status(response):
    """Convertit un statut HTTP d'échec en ``ProviderError`` (sans exposer le corps de la réponse)."""
    status = response.status_code
    if status == 200:
        return
    if status == 429:
        try:
            retry_after = float(response.headers.get('retry-after', ''))
        except (TypeError, ValueError):
            retry_after = None
        raise ProviderError(RATE_LIMITED, 'HTTP 429', retry_after=retry_after)
    if status in (401, 403):
        raise ProviderError(AUTH, f'HTTP {status}')
    if status == 404:
        raise ProviderError(BAD_RESPONSE, 'HTTP 404 (modèle introuvable)', permanent=True)
    if status == 408:
        raise ProviderError(TIMEOUT, 'HTTP 408')
    if status >= 500:
        raise ProviderError(SERVER, f'HTTP {status}')
    raise ProviderError(BAD_RESPONSE, f'HTTP {status}')


def _post(url, *, headers, payload, timeout):
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=(CONNECT_TIMEOUT, timeout))
    except requests.Timeout as exc:
        raise ProviderError(TIMEOUT, 'délai dépassé') from exc
    except requests.RequestException as exc:
        raise ProviderError(NETWORK, type(exc).__name__) from exc
    _check_status(response)
    try:
        return response.json()
    except ValueError as exc:
        raise ProviderError(BAD_RESPONSE, 'réponse non JSON') from exc


class Provider:
    """Interface d'un fournisseur. Les sous-classes n'ont besoin que de ces quatre éléments."""
    name = ''
    supports_vision = False

    def credentials(self):
        raise NotImplementedError

    def models(self, request):
        raise NotImplementedError

    def complete(self, unit, request, timeout):
        raise NotImplementedError

    def configured(self):
        return bool(self.credentials())

    def units(self, request):
        # Le modèle prioritaire est tenté avec chaque clé AVANT de passer au modèle de repli
        credentials = self.credentials()
        return [Unit(self.name, index, model) for model in self.models(request) for index in range(len(credentials))]


class GroqProvider(Provider):
    name = 'groq'
    supports_vision = True
    URL = 'https://api.groq.com/openai/v1/chat/completions'

    def credentials(self):
        return [settings.GROQ_API_KEY] if getattr(settings, 'GROQ_API_KEY', None) else []

    def models(self, request):
        if request.image_base64:
            return _unique([getattr(settings, 'GROQ_VISION_MODEL', None) or settings.GROQ_MODEL])
        return _unique([settings.GROQ_MODEL, *_csv(getattr(settings, 'AI_GROQ_FALLBACK_MODELS', ''))])

    def complete(self, unit, request, timeout):
        user_content = request.prompt
        if request.image_base64:
            user_content = [
                {'type': 'text', 'text': request.prompt},
                {'type': 'image_url', 'image_url': {'url': f"data:{request.image_mime};base64,{request.image_base64}"}},
            ]
        data = _post(
            self.URL,
            headers={'Authorization': f"Bearer {self.credentials()[unit.credential]}", 'Content-Type': 'application/json'},
            payload={
                'model': unit.model,
                'messages': [{'role': 'system', 'content': request.system}, {'role': 'user', 'content': user_content}],
                'temperature': request.temperature,
                'max_tokens': request.max_tokens,
            },
            timeout=timeout,
        )
        try:
            text = data['choices'][0]['message']['content']
        except (KeyError, IndexError, TypeError) as exc:
            raise ProviderError(BAD_RESPONSE, 'structure inattendue') from exc
        usage = data.get('usage') or {}
        return Completion(text or '', usage.get('prompt_tokens'), usage.get('completion_tokens'))


class GeminiProvider(Provider):
    name = 'gemini'
    supports_vision = True
    URL = 'https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent'

    def credentials(self):
        return list(getattr(settings, 'GEMINI_API_KEYS', None) or [])

    def models(self, request):
        return _unique([settings.GEMINI_MODEL, *_csv(getattr(settings, 'AI_GEMINI_FALLBACK_MODELS', ''))])

    def complete(self, unit, request, timeout):
        parts = [{'text': request.prompt}]
        if request.image_base64:
            parts.append({'inline_data': {'mime_type': request.image_mime, 'data': request.image_base64}})
        data = _post(
            self.URL.format(model=unit.model),
            headers={'x-goog-api-key': self.credentials()[unit.credential], 'Content-Type': 'application/json'},
            payload={
                'systemInstruction': {'parts': [{'text': request.system}]},
                'contents': [{'role': 'user', 'parts': parts}],
                'generationConfig': {'temperature': request.temperature, 'maxOutputTokens': request.max_tokens},
            },
            timeout=timeout,
        )
        if (data.get('promptFeedback') or {}).get('blockReason'):
            raise ProviderError(BAD_RESPONSE, 'demande bloquée par le fournisseur')
        try:
            candidate_parts = data['candidates'][0]['content']['parts']
        except (KeyError, IndexError, TypeError) as exc:
            raise ProviderError(BAD_RESPONSE, 'structure inattendue') from exc
        text = ''.join(part.get('text', '') for part in candidate_parts)
        usage = data.get('usageMetadata') or {}
        return Completion(text, usage.get('promptTokenCount'), usage.get('candidatesTokenCount'))


# Pour ajouter un fournisseur : écrire une sous-classe de ``Provider`` ici, l'inscrire, puis l'ajouter à AI_PROVIDER_ORDER.
PROVIDER_CLASSES = {GroqProvider.name: GroqProvider, GeminiProvider.name: GeminiProvider}


# --------------------------------------------------------------------------------------------------------------
# Disjoncteurs (en mémoire de processus : une panne observée par un worker n'est pas partagée avec les autres)
# --------------------------------------------------------------------------------------------------------------
def _cache_key(kind, scope):
    return f"llm:{kind}:{scope}"


def in_cooldown(unit):
    return bool(cache.get(_cache_key('cool', unit.credential_scope)) or cache.get(_cache_key('cool', unit.label)))


def _start_cooldown(scope, seconds):
    cache.set(_cache_key('cool', scope), True, max(1, int(seconds)))


def _note_success(unit):
    cache.delete(_cache_key('fail', unit.label))


def _note_failure(unit, error):
    if error.kind == RATE_LIMITED:
        _start_cooldown(unit.credential_scope, min(max(error.retry_after or 60, 5), 600))
    elif error.kind == AUTH:
        _start_cooldown(unit.credential_scope, AUTH_COOLDOWN_SECONDS)
    elif error.permanent:
        _start_cooldown(unit.label, MISSING_MODEL_COOLDOWN_SECONDS)
    elif error.kind in (TIMEOUT, SERVER, NETWORK):
        key = _cache_key('fail', unit.label)
        cache.add(key, 0, FAILURE_WINDOW_SECONDS)
        try:
            failures = cache.incr(key)
        except ValueError:  # clé expirée entre add et incr
            failures = 1
        if failures >= FAILURES_BEFORE_COOLDOWN:
            _start_cooldown(unit.label, SHORT_COOLDOWN_SECONDS)
            cache.delete(key)


# --------------------------------------------------------------------------------------------------------------
# Orchestrateur
# --------------------------------------------------------------------------------------------------------------
_local = threading.local()


def last_result():
    """Résultat du dernier appel fait par CE thread (sert à expliquer un échec sans changer les signatures)."""
    return getattr(_local, 'last', None)


def mark_unusable():
    """Le fournisseur a répondu, mais le texte est inexploitable (fuite de consignes, répétitions) : il n'est pas montré."""
    previous = getattr(_local, 'last', None)
    if previous is not None:
        _local.last = dataclasses.replace(previous, text=None, reason=UNUSABLE)


def reset_last_result():
    """À appeler avant une série d'appels : évite de lire l'échec d'une demande précédente du même thread."""
    _local.last = None


def _daily_limit_reached(user):
    limit = getattr(settings, 'AI_DAILY_CALLS_PER_USER', 0)
    if not user or not getattr(user, 'is_authenticated', False) or not limit:
        return False
    from .models import LLMUsage
    midnight = timezone.localtime().replace(hour=0, minute=0, second=0, microsecond=0)
    return LLMUsage.objects.filter(user=user, ok=True, created_at__gte=midnight).count() >= limit


def _record(unit, request, user, ok, kind, latency_ms, completion):
    """Journal d'usage. Une panne du journal ne doit jamais faire échouer la réponse à l'utilisateur."""
    try:
        from .models import LLMUsage
        LLMUsage.objects.create(
            user=user if user and getattr(user, 'is_authenticated', False) else None,
            provider=unit.provider, model=unit.model, feature=request.feature, ok=ok, error_kind=kind,
            latency_ms=latency_ms, prompt_chars=len(request.system) + len(request.prompt),
            completion_chars=len(completion.text) if completion else 0,
            prompt_tokens=completion.prompt_tokens if completion else None,
            completion_tokens=completion.completion_tokens if completion else None,
        )
    except Exception:
        logger.warning("[LLM] Journal d'usage indisponible (la réponse n'est pas affectée)", exc_info=True)


class LLMOrchestrator:
    def __init__(self, providers=None, clock=time.monotonic):
        self.providers = providers if providers is not None else {name: cls() for name, cls in PROVIDER_CLASSES.items()}
        self.clock = clock

    def _ordered(self, request):
        order = settings.AI_VISION_PROVIDER_ORDER if request.image_base64 else settings.AI_PROVIDER_ORDER
        providers = [self.providers[name] for name in _csv(order) if name in self.providers]
        if request.image_base64:
            providers = [p for p in providers if p.supports_vision]  # jamais de repli vers un modèle aveugle
        return providers

    def generate(self, request, user=None, budget=None):
        started = self.clock()
        result = self._generate(request, user, started, budget)
        result.latency_ms = int((self.clock() - started) * 1000)
        _local.last = result
        return result

    def _generate(self, request, user, started, budget):
        if _daily_limit_reached(user):
            return LLMResult(None, DAILY_LIMIT)
        providers = [p for p in self._ordered(request) if p.configured()]
        if not providers:
            logger.warning("[LLM] Aucun fournisseur configuré pour cette demande (clés API absentes ?)")
            return LLMResult(None, NOT_CONFIGURED)

        deadline = started + (budget if budget is not None else settings.AI_TOTAL_BUDGET_SECONDS)
        per_attempt = settings.AI_VISION_ATTEMPT_TIMEOUT_SECONDS if request.image_base64 else settings.AI_ATTEMPT_TIMEOUT_SECONDS
        attempts = []

        for provider in providers:
            for unit in provider.units(request):
                if in_cooldown(unit):
                    continue
                if len(attempts) >= settings.AI_MAX_ATTEMPTS:
                    return LLMResult(None, UNAVAILABLE, attempts=attempts)
                remaining = deadline - self.clock()
                if remaining < MIN_ATTEMPT_SECONDS:
                    return LLMResult(None, BUDGET_EXHAUSTED, attempts=attempts)

                attempt_started = self.clock()
                completion, error = None, None
                try:
                    completion = provider.complete(unit, request, min(per_attempt, remaining))
                    completion.text = clean_model_output(completion.text)
                    if not completion.text:
                        raise ProviderError(BAD_RESPONSE, 'réponse vide')
                except ProviderError as exc:
                    error = exc
                latency = int((self.clock() - attempt_started) * 1000)

                if error is None:
                    _note_success(unit)
                    attempts.append(Attempt(unit.label, True, '', latency))
                    _record(unit, request, user, True, '', latency, completion)
                    return LLMResult(completion.text, OK, unit.provider, unit.model, attempts)

                attempts.append(Attempt(unit.label, False, error.kind, latency))
                _record(unit, request, user, False, error.kind, latency, None)
                _note_failure(unit, error)
                logger.warning("[LLM] %s : échec (%s) en %d ms", unit.label, error.kind, latency)
        return LLMResult(None, UNAVAILABLE, attempts=attempts)


_orchestrator = None


def get_orchestrator():
    global _orchestrator
    if _orchestrator is None:
        _orchestrator = LLMOrchestrator()
    return _orchestrator


def set_orchestrator(orchestrator):
    """Remplace l'orchestrateur (tests, ou fournisseur maison) ; ``None`` rétablit celui par défaut."""
    global _orchestrator
    _orchestrator = orchestrator


def generate(request, user=None, budget=None):
    """Demande une réponse au modèle. Ne lève jamais d'exception : l'issue est dans ``LLMResult.reason``."""
    return get_orchestrator().generate(request, user=user, budget=budget)
