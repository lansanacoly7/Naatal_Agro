import json
import logging
import re
import time
import requests
from django.conf import settings
from django.utils import timezone
import datetime

from .knowledge import MARKER, retrieve

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """Tu es le copilote agronomique intelligent de Naatal Agro, la plateforme agricole de référence au Sénégal.
Ton rôle est d'apporter des conseils agronomiques précis, pratiques, contextualisés et immédiatement applicables par les producteurs sénégalais.

RÈGLES D'OR :
1. Réponds comme un conseiller de terrain qui discute : phrases courtes, ton chaleureux, en français simple (termes locaux si pertinents, ex: Louma, Niayes, Casamance). Jamais de cours ni de pavé.
2. Base-toi en priorité sur les données réelles fournies dans le profil et les exploitations de l'utilisateur.
3. Ne divulgue jamais de données techniques internes ou d'informations d'autres exploitants.
4. Si une maladie ou un ravageur est détecté, propose des solutions de lutte intégrée (biologiques et conventionnelles homologuées au Sénégal).
"""

def get_farmer_context(user):
    """
    Extrait de manière strictement cloisonnée (ORM Django) le contexte
    agricole de l'utilisateur authentifié. Aucune fuite multi-tenant possible.
    """
    if not user or not user.is_authenticated:
        return {"auth": False, "note": "Utilisateur non connecté (mode invité)"}

    context = {
        "auth": True,
        "name": user.first_name or user.username,
        "role": getattr(user, 'role', 'farmer'),
        "location": getattr(user, 'location', 'Sénégal'),
        "main_crops": getattr(user, 'main_crops', []),
        "crops": [],
        "recent_activities": [],
        "market_prices": [],
        "local_pest_alerts": []
    }

    try:
        from apps.agriculture.models import Crop, Activity, PestReport
        from apps.markets.models import Product, Price

        # 1. Cultures personnelles exclusives de l'utilisateur connecté
        user_crops = Crop.objects.filter(user=user)[:10]
        for c in user_crops:
            context["crops"].append({
                "nom": c.name,
                "type": c.crop_type,
                "surface_ha": c.area_size,
                "statut": c.status,
                "semis": str(c.planting_date),
                "recolte_prevue": str(c.expected_harvest_date),
            })

        # 2. Activités récentes sur ses propres cultures
        user_activities = Activity.objects.filter(crop__user=user).order_by('-date')[:5]
        for a in user_activities:
            context["recent_activities"].append({
                "culture": a.crop.name,
                "type": a.activity_type,
                "description": a.description,
                "date": str(a.date)
            })

        # 3. Tendances des marchés (données publiques)
        trending_products = Product.objects.filter(is_trending=True)[:5]
        for p in trending_products:
            context["market_prices"].append({
                "produit": p.name,
                "categorie": p.category,
                "prix_kg": str(p.current_price),
                "tendance": f"{p.trend_percentage}%"
            })

        # 4. Alertes ravageurs dans la région de l'utilisateur (14 derniers jours)
        if user.location:
            region = user.location.split(',')[0].strip()
            recent_alerts = PestReport.objects.filter(
                location__icontains=region,
                date_reported__gte=timezone.now() - datetime.timedelta(days=14)
            )[:3]
            for alert in recent_alerts:
                context["local_pest_alerts"].append({
                    "ravageur": alert.pest_name,
                    "zone": alert.location,
                    "date": alert.date_reported.strftime("%Y-%m-%d")
                })
    except Exception as e:
        logger.error(f"[AI Context Extraction] Erreur d'extraction : {e}")

    return context

def call_groq(prompt):
    groq_key = getattr(settings, 'GROQ_API_KEY', None)
    if not groq_key:
        return None
    url = "https://api.groq.com/openai/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {groq_key}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": "llama-3.1-8b-instant",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.4,
        "max_tokens": 600
    }
    try:
        res = requests.post(url, json=payload, headers=headers, timeout=10)
        if res.status_code == 200:
            return res.json()['choices'][0]['message']['content']
        logger.warning(f"[Groq Service] Statut HTTP {res.status_code}: {res.text}")
    except Exception as e:
        logger.error(f"[Groq Service] Exception : {e}")
    return None

def _image_mime_type(image_base64):
    """Type réel de l'image d'après ses premiers octets (la galerie peut fournir du PNG ou du WebP)."""
    import base64
    try:
        head = base64.b64decode(image_base64[:64] + '=' * (-len(image_base64[:64]) % 4))
    except Exception:
        return 'image/jpeg'
    if head.startswith(b'\x89PNG'):
        return 'image/png'
    if head[:4] == b'RIFF' and head[8:12] == b'WEBP':
        return 'image/webp'
    return 'image/jpeg'


def call_gemini(prompt, image_base64=None):
    gemini_key = getattr(settings, 'GEMINI_API_KEY', None)
    if not gemini_key:
        return None
        
    model = getattr(settings, 'GEMINI_MODEL', 'gemini-3.8-flash')
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    headers = {
        "x-goog-api-key": gemini_key,
        "Content-Type": "application/json"
    }
    
    parts = [{"text": f"{SYSTEM_PROMPT}\n\n{prompt}"}]
    if image_base64:
        parts.append({
            "inline_data": {
                "mime_type": _image_mime_type(image_base64),
                "data": image_base64
            }
        })

    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {"temperature": 0.4, "maxOutputTokens": 700, "thinkingConfig": {"thinkingBudget": 0}},
    }
    try:
        res = requests.post(url, json=payload, headers=headers, timeout=15)
        if res.status_code in (429, 503):
            # pic de demande côté Google : un seul nouvel essai, rapide
            time.sleep(1.5)
            res = requests.post(url, json=payload, headers=headers, timeout=15)
        if res.status_code == 200:
            return res.json()['candidates'][0]['content']['parts'][0]['text']
        logger.warning(f"[Gemini Service] Statut HTTP {res.status_code}: {res.text}")
    except Exception as e:
        logger.error(f"[Gemini Service] Exception : {e}")
    return None

def call_llm(prompt, image_base64=None):
    if image_base64:
        return call_gemini(prompt, image_base64=image_base64)
    # Tente Groq en priorité, bascule sur Gemini si indisponible
    res = call_groq(prompt)
    if not res:
        res = call_gemini(prompt)
    return res

CONVERSATION_RULES = """
STYLE DE CONVERSATION (aussi important que l'exactitude) :
- Tu es dans une discussion : réponds court. 2 à 4 phrases, ou 3 puces au maximum, environ 60 mots. Va à l'essentiel et ne dis pas tout.
- Si la question est large ou vague (ex. « je veux cultiver des patates douces »), donne 1 ou 2 phrases utiles puis pose UNE question pour préciser (zone, saison, surface) ou propose de détailler.
- Aère : paragraphes courts, puces commençant par « - », un seul **mot clé** en gras au besoin. Aucun titre, aucun tableau.
- Tiens compte de la CONVERSATION EN COURS : ne répète pas ce qui a déjà été dit, comprends les suites (« et l'engrais ? »).
- Si l'utilisateur demande plus de détails, développe alors, de façon structurée.
- Termine TOUJOURS par une dernière ligne exactement de la forme :
SUGGESTIONS: question 1 | question 2 | question 3
(2 ou 3 questions courtes, de 3 à 7 mots, que le producteur pourrait poser ensuite, écrites à la première personne ou à l'impératif).
"""

GROUNDED_RULES = """Tu réponds à une question d'agriculture pour un producteur sénégalais.
RÈGLES ABSOLUES :
1. Utilise UNIQUEMENT les informations des FICHES ci-dessous. N'ajoute aucun fait, chiffre, dose, produit ou date qui n'y figure pas.
2. Cite la source de chaque information avec son numéro entre crochets, par exemple [1], comme dans les fiches.
3. Si la question porte sur une information absente des fiches, dis clairement qu'elle n'est pas disponible dans nos fiches vérifiées. Ne la devine pas.
4. Pour les produits phytosanitaires et les doses, rappelle de confirmer avec un conseiller agricole (ANCAR, SAED).
5. Cite au moins une source [n] dans ta réponse.
""" + CONVERSATION_RULES

GENERAL_NOTICE = "Réponse générale, non issue de nos fiches vérifiées : à confirmer auprès d'un conseiller agricole."
SOURCES_UNAVAILABLE_NOTICE = (
    "Naatal IA est temporairement indisponible (les clés API Gemini ou Groq ne sont pas configurées). "
    "Vos données agricoles personnelles restent parfaitement sécurisées et accessibles."
)


REGIONAL_SCOPE_LABEL = "référence hors Sénégal, à adapter"
REGIONAL_NOTICE = (
    "Certaines informations viennent de références hors Sénégal (Afrique de l'Ouest) : "
    "à confirmer auprès d'un conseiller agricole (ANCAR, SAED) avant de les appliquer."
)


def _source_line(source):
    year = f" ({source['year']})" if source.get('year') else ''
    publisher = f", {source['publisher']}" if source.get('publisher') else ''
    scope = f" [{REGIONAL_SCOPE_LABEL}]" if source.get('scope', 'senegal') != 'senegal' else ''
    return f"[{source['number']}] {source['title']}{publisher}{year}{scope}"


def _missing_sentence(retrieval):
    if not retrieval.missing:
        return ''
    items = '; '.join(f"{label.lower()} ({name})" for name, label in retrieval.missing)
    return (f"Information non disponible dans nos fiches vérifiées : {items}. "
            "Nous ne la devinons pas : demandez conseil à un technicien (ANCAR, SAED).")


def _cited_sources(answer, sources):
    cited = {int(n) for n in MARKER.findall(answer)}
    return [src for src in sources if src['number'] in cited]


def _with_sources_footer(answer, sources):
    cited = _cited_sources(answer, sources)
    if not cited:
        return answer
    footer = "\n".join(_source_line(src) for src in cited)
    return f"{answer}\n\nSources :\n{footer}"


MAX_SUGGESTIONS = 3
SUGGESTIONS_LINE = re.compile(r'^\s*SUGGESTIONS?\s*:\s*(.+?)\s*$', re.IGNORECASE | re.MULTILINE)
SENTENCE_END = re.compile(r'(?<=[.!?])\s+')
SHORT_ANSWER_CHARS = 380


def split_suggestions(raw):
    """Sépare la réponse du modèle de sa ligne « SUGGESTIONS: a | b | c » ; renvoie (texte, [suggestions])."""
    if not raw:
        return raw, []
    suggestions = []
    for match in SUGGESTIONS_LINE.finditer(raw):
        for item in match.group(1).split('|'):
            item = item.strip(' -*"«»')
            if item and item not in suggestions:
                suggestions.append(item)
    cleaned = SUGGESTIONS_LINE.sub('', raw).strip()
    return cleaned, suggestions[:MAX_SUGGESTIONS]


def _shorten(text, limit=SHORT_ANSWER_CHARS):
    """Garde les premières phrases du texte, sans dépasser la limite (coupe toujours en fin de phrase)."""
    flat = ' '.join(line.strip() for line in text.splitlines() if line.strip())
    kept = ''
    for sentence in SENTENCE_END.split(flat):
        if kept and len(kept) + len(sentence) + 1 > limit:
            break
        kept = f'{kept} {sentence}'.strip()
    if not MARKER.search(kept):
        # le résumé garde la source de la fiche, même si la phrase qui la porte a été coupée
        marker = MARKER.search(flat)
        if marker:
            kept = f'{kept} {marker.group(0)}'
    return kept


def default_suggestions(retrieval):
    """Questions de relance tirées des fiches, quand le modèle n'en propose pas."""
    if not retrieval.guides:
        return []
    name = retrieval.guides[0].name
    asked = {section.label for section in retrieval.sections}
    candidates = [
        ('Semis et calendrier', f'Quand semer : {name.lower()} ?'),
        ('Fertilisation', f'Quel engrais pour : {name.lower()} ?'),
        ('Maladies et ravageurs', 'Quelles maladies surveiller ?'),
        ('Eau et irrigation', "Combien d'eau faut-il ?"),
        ('Récolte et conservation', 'Quand récolter ?'),
        ('Rendement', 'Quel rendement espérer ?'),
    ]
    return [text.replace(' : ', ' ') for label, text in candidates if label not in asked][:MAX_SUGGESTIONS]


def build_fiche_answer(retrieval):
    """
    Réponse courte construite directement depuis les fiches, sans modèle de langage.
    Une question large (« je veux cultiver… ») reçoit une présentation brève et une invitation à préciser.
    """
    blocks = []
    broad = len(retrieval.sections) == 1 and retrieval.sections[0].label == 'Fiche complète'
    if broad:
        guide = retrieval.sections[0].guide
        first = next((section for section in retrieval.sections if section.guide == guide), None)
        intro = _shorten(first.text.removeprefix('Présentation : '), 300)
        blocks.append(f"{guide.name} : {intro}")
        blocks.append("Que voulez-vous savoir en premier : le semis, l'engrais, l'eau ou les maladies ?")
    else:
        for section in retrieval.sections[:3]:
            blocks.append(f"**{section.guide.name} — {section.label}**\n{_shorten(section.text)}")
    missing = _missing_sentence(retrieval)
    if missing:
        blocks.append(missing)
    return "\n\n".join(blocks)


def history_block(history):
    """Texte de la conversation en cours (les derniers échanges), pour le modèle."""
    lines = []
    for turn in (history or [])[-8:]:
        who = 'Producteur' if turn.get('role') == 'user' else 'Assistant'
        content = str(turn.get('content', '')).split('\n\nSources :')[0].strip()
        if content:
            lines.append(f"{who} : {content[:500]}")
    return "\n".join(lines)


def _retrieve_with_history(query, history):
    """Si la question seule ne désigne aucune culture (« et l'engrais ? »), s'appuie sur les messages précédents."""
    retrieval = retrieve(query)
    if retrieval.guides or not history:
        return retrieval
    previous = ' '.join(t['content'] for t in history if t.get('role') == 'user' and t.get('content'))
    if not previous:
        return retrieval
    return retrieve(f'{previous[-300:]} {query}') if retrieve(previous[-300:]).guides else retrieval


def _grounded_prompt(query, retrieval, farmer_context, history=None):
    sources = "\n".join(_source_line(src) for src in retrieval.sources)
    sheets = "\n\n".join(
        f"Culture : {section.guide.name} | Sujet : {section.label}\n{section.text}" for section in retrieval.sections)
    context_str = json.dumps(farmer_context, ensure_ascii=False, indent=2)
    return (
        f"{GROUNDED_RULES}\n\n"
        f"### SOURCES\n{sources}\n\n"
        f"### FICHES NAATAL AGRO (données vérifiées)\n{sheets}\n\n"
        f"### PROFIL DE L'EXPLOITANT (données privées, pour adapter la réponse)\n```json\n{context_str}\n```\n\n"
        f"### CONVERSATION EN COURS\n{history_block(history) or '(début de la conversation)'}\n\n"
        f"### QUESTION DU PRODUCTEUR\n{query}\n"
    )


def _validated_llm_answer(raw, sources):
    """
    Garde la réponse du modèle seulement si elle cite au moins une source existante.
    Les repères inventés (numéro hors liste) sont retirés. Renvoie None si la réponse n'est pas exploitable.
    """
    if not raw:
        return None
    valid = {src['number'] for src in sources}

    def keep_valid(match):
        return match.group(0) if int(match.group(1)) in valid else ''

    cleaned = MARKER.sub(keep_valid, raw).strip()
    return cleaned if MARKER.search(cleaned) else None


def answer_question(query, context='general', image_base64=None, user=None, history=None):
    """
    Point d'entrée du copilote IA de Naatal Agro.
    Renvoie ``{'answer', 'origin', 'sources', 'suggestions'}``.

    Ordre de priorité : 1) nos fiches agronomiques (base de données), avec leurs sources ;
    2) à défaut, un conseil général clairement signalé comme non sourcé.
    Le diagnostic par image reste un conseil général (pas de fiche pour une photo).
    ``history`` : derniers échanges de la conversation, ``[{'role': 'user'|'assistant', 'content': str}]``.
    """
    if image_base64:
        vision_prompt = (
            f"Analyse phytosanitaire de cette image agricole transmise par l'exploitant.\n"
            f"Question / Remarque : '{query}'.\n"
            f"1. Identifie la culture et la maladie ou le ravageur visible avec certitude.\n"
            f"2. Indique la sévérité et les symptômes caractéristiques.\n"
            f"3. Recommande un traitement curatif et préventif adapté au climat sénégalais.\n"
            f"Réponds en peu de mots, avec des puces courtes, puis termine par la ligne SUGGESTIONS: "
            f"question 1 | question 2 | question 3."
        )
        response = call_llm(vision_prompt, image_base64=image_base64)
        if not response:
            return {'answer': "Le service de vision IA est indisponible. Veuillez vérifier vos clés API.",
                    'origin': 'general', 'sources': [], 'suggestions': []}
        answer, suggestions = split_suggestions(response)
        return {'answer': answer, 'origin': 'general', 'sources': [], 'suggestions': suggestions}

    farmer_context = get_farmer_context(user)
    retrieval = _retrieve_with_history(query, history)

    if retrieval.sections:
        raw = call_llm(_grounded_prompt(query, retrieval, farmer_context, history))
        raw_answer, suggestions = split_suggestions(raw)
        answer = _validated_llm_answer(raw_answer, retrieval.sources)
        if answer is None:
            answer = build_fiche_answer(retrieval)
            suggestions = []
        else:
            missing = _missing_sentence(retrieval)
            if missing:
                answer = f"{answer}\n\n{missing}"
        sources = _cited_sources(answer, retrieval.sources)
        if any(source.get('scope', 'senegal') != 'senegal' for source in sources):
            answer = f"{answer}\n\n{REGIONAL_NOTICE}"
        return {
            'answer': _with_sources_footer(answer, retrieval.sources),
            'origin': 'database',
            'sources': sources,
            'suggestions': suggestions or default_suggestions(retrieval),
        }

    context_str = json.dumps(farmer_context, ensure_ascii=False, indent=2)
    prompt = (
        f"{CONVERSATION_RULES}\n"
        f"### DONNÉES CLOISONNÉES DE L'EXPLOITANT (Source certifiée Naatal Agro) :\n"
        f"```json\n{context_str}\n```\n\n"
        f"### CONTEXTE MÉTIER : {context}\n"
        f"### CONVERSATION EN COURS :\n{history_block(history) or '(début de la conversation)'}\n\n"
        f"### QUESTION DU PRODUCTEUR : {query}\n\n"
        f"Réponds de façon courte, concrète et utile pour l'exploitant :"
    )
    llm_response = call_llm(prompt)
    missing = _missing_sentence(retrieval)
    if not llm_response:
        parts = [part for part in (missing, SOURCES_UNAVAILABLE_NOTICE) if part]
        return {'answer': "\n\n".join(parts), 'origin': 'general', 'sources': [], 'suggestions': []}
    text, suggestions = split_suggestions(llm_response)
    parts = [text]
    if missing:
        parts.append(missing)
    if retrieval.is_agricultural:
        parts.append(GENERAL_NOTICE)
    return {'answer': "\n\n".join(parts), 'origin': 'general', 'sources': [], 'suggestions': suggestions}


def ask_llm(query, context='general', image_base64=None, user=None):
    """Version texte de answer_question (compatibilité : scripts de diagnostic, anciens appels)."""
    return answer_question(query, context, image_base64=image_base64, user=user)['answer']
