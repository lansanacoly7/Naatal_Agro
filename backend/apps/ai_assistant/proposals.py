"""
Cycle de vie des propositions d'opérations métier de Naatal IA (cahier des charges §4.C).

Une proposition est une interaction dont ``action_data`` décrit l'opération à faire. Elle évolue ainsi :

    pending_confirmation ──confirmer──> executed | failed
                         ──annuler────> cancelled
                         ──30 min─────> expired
                         ──nouvelle proposition dans la conversation──> superseded

Garanties :
- Une proposition ne s'exécute qu'une seule fois : le passage ``pending_confirmation -> processing`` est un
  compare-and-set (``UPDATE … WHERE status = 'pending_confirmation'``). Deux confirmations simultanées
  (double appui, relance réseau) ne peuvent pas toutes les deux le gagner.
- Le verrouillage, l'écriture métier, le statut final et le message de résultat sont dans UNE transaction :
  en cas d'incident tout est annulé, la proposition reste confirmable.
- Un second envoi renvoie le résultat déjà obtenu, sans nouvelle écriture (idempotence).
- Seuls les paramètres stockés côté serveur sont exécutés, jamais ceux envoyés par le client.
"""
import datetime
import logging
from dataclasses import dataclass

from django.db import transaction
from django.utils import timezone

from .actions import check_action, execute_action
from .models import AIConversation, AIInteraction

logger = logging.getLogger(__name__)

PENDING = 'pending_confirmation'
PROCESSING = 'processing'
EXECUTED = 'executed'
FAILED = 'failed'
CANCELLED = 'cancelled'
EXPIRED = 'expired'
SUPERSEDED = 'superseded'

FINAL_STATUSES = frozenset({EXECUTED, FAILED, CANCELLED, EXPIRED, SUPERSEDED})
PROPOSAL_TTL = datetime.timedelta(minutes=30)
# Au-delà, un « oui » isolé n'est plus interprété comme un doublon de la dernière opération
RECENT_OUTCOME_WINDOW = datetime.timedelta(minutes=10)

CLARIFICATION_KIND = 'clarification'
DECISIONS = ('confirm', 'cancel')
# Réponse reconnue par ``actions.classify_reply`` -> décision appliquée à la proposition en attente
DECISIONS_BY_REPLY = {'confirm': 'confirm', 'cancel': 'cancel'}

CLARIFICATION_TEXT = (
    "Je n'ai rien enregistré, car votre message ne se limite pas à une confirmation.\n\n"
    "• Pour valider l'opération proposée, répondez simplement « oui ».\n"
    "• Pour l'annuler, répondez « non ».\n"
    "• Pour la modifier, redonnez-la en entier (exemple : « J'ai dépensé 20 000 FCFA pour l'engrais »)."
)
ALREADY_HANDLED_TEXT = "Cette opération a déjà été traitée : aucune nouvelle écriture n'a été faite dans vos données."


class ProposalNotFound(Exception):
    """La proposition n'existe pas ou n'appartient pas à l'utilisateur."""


class ProposalUnavailable(Exception):
    """La proposition ne peut plus être traitée (remplacée par une autre, ou en cours de traitement)."""

    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


@dataclass
class Resolution:
    interaction: AIInteraction
    replayed: bool = False


def _status(interaction):
    return (interaction.action_data or {}).get('status')


def is_proposal(interaction):
    return bool(interaction and (interaction.action_data or {}).get('action_type'))


def is_pending(interaction):
    return is_proposal(interaction) and _status(interaction) == PENDING


def latest_pending(conversation):
    """
    Dernière proposition en attente de la conversation, à condition qu'aucun échange « de fond » ne se soit
    intercalé (les messages de clarification n'interrompent pas la proposition).
    """
    for interaction in conversation.interactions.order_by('-created_at')[:6]:
        if (interaction.action_data or {}).get('kind') == CLARIFICATION_KIND:
            continue
        return interaction if is_pending(interaction) else None
    return None


def is_recent_outcome(interaction):
    """Vrai si ``interaction`` est le résultat (exécuté, échoué, annulé…) d'une proposition toute récente."""
    data = interaction.action_data or {}
    return bool(data.get('proposal_id')) and data.get('status') in FINAL_STATUSES \
        and timezone.now() - interaction.created_at <= RECENT_OUTCOME_WINDOW


def _expires_at(proposal):
    raw = (proposal.action_data or {}).get('expires_at')
    try:
        parsed = datetime.datetime.fromisoformat(raw) if raw else None
    except ValueError:
        parsed = None
    return parsed or proposal.created_at + PROPOSAL_TTL


def _claim(proposal, new_status, **extra):
    """Compare-and-set : ``True`` seulement si la proposition était encore en attente au moment de l'écriture."""
    data = {**(proposal.action_data or {}), 'status': new_status, **extra}
    claimed = AIInteraction.objects.filter(pk=proposal.pk, action_data__status=PENDING).update(action_data=data) == 1
    if claimed:
        proposal.action_data = data
    return claimed


def _touch(conversation_id):
    if conversation_id:
        AIConversation.objects.filter(pk=conversation_id).update(updated_at=timezone.now())


def create_proposal(*, user, conversation, query, context, intent):
    """
    Enregistre une proposition d'opération (aucune écriture métier) et remplace les propositions en attente.

    Si l'opération est refusée par les règles de l'application (stock insuffisant, échéance passée…), aucune
    proposition n'est créée : l'utilisateur reçoit l'explication, et il n'y a donc rien à confirmer.
    """
    action_type, params = intent['action_type'], intent['params']
    blockers, warnings = check_action(user, action_type, params)
    if blockers:
        refusal = ["🚫 **Je ne peux pas proposer cette opération** :", ""]
        refusal += [f"• {blocker}" for blocker in blockers]
        refusal += ["", "Aucune donnée n'a été modifiée."]
        return create_note(
            user=user, conversation=conversation, query=query, context=context,
            text="\n".join(refusal),
            suggestions=['Vérifier mon stock', 'Mes rappels', 'Consulter mon solde'],
        )

    lines = ["📋 **Proposition d'opération** :", "", f"• {intent['summary']}", ""]
    lines += [f"⚠️ {warning}" for warning in warnings]
    if warnings:
        lines.append("")
    lines.append(intent['confirm_prompt'])
    text = "\n".join(lines)

    with transaction.atomic():
        for stale in conversation.interactions.filter(action_data__status=PENDING):
            if is_proposal(stale):
                _claim(stale, SUPERSEDED)
        interaction = AIInteraction.objects.create(
            user=user,
            conversation=conversation,
            query=query,
            response=text,
            context_type=context,
            origin='database',
            sources=[],
            suggestions=['Oui, valider', 'Non, annuler'],
            action_data={
                'status': PENDING,
                'action_type': action_type,
                'parameters': params,
                'summary': intent['summary'],
                'warnings': warnings,
                'expires_at': (timezone.now() + PROPOSAL_TTL).isoformat(),
            },
        )
        _touch(conversation.pk)
    return interaction


def create_note(*, user, conversation, query, context, text, suggestions, kind=None, extra=None):
    """Message de service lié à une proposition (clarification, doublon) : n'écrit rien dans les données métier."""
    interaction = AIInteraction.objects.create(
        user=user,
        conversation=conversation,
        query=query,
        response=text,
        context_type=context,
        origin='database',
        sources=[],
        suggestions=suggestions,
        action_data={**({'kind': kind} if kind else {}), **(extra or {})},
    )
    _touch(conversation.pk)
    return interaction


def _stored_outcome(proposal):
    data = proposal.action_data or {}
    outcome_id = data.get('outcome_interaction_id')
    outcome = AIInteraction.objects.filter(pk=outcome_id, user=proposal.user).first() if outcome_id else None
    if outcome is None:
        outcome = AIInteraction.objects.filter(
            user=proposal.user, action_data__proposal_id=str(proposal.pk)
        ).order_by('-created_at').first()
    return outcome


def _record_outcome(proposal, status, text, suggestions, query, context, result=None):
    outcome = AIInteraction.objects.create(
        user=proposal.user,
        conversation=proposal.conversation,
        query=query,
        response=text,
        context_type=context,
        origin='database',
        sources=[],
        suggestions=suggestions,
        action_data={'status': status, 'result': result or {}, 'proposal_id': str(proposal.pk)},
    )
    final = {
        **(proposal.action_data or {}),
        'status': status,
        'result': result or {},
        'outcome_interaction_id': str(outcome.pk),
    }
    AIInteraction.objects.filter(pk=proposal.pk).update(action_data=final)
    proposal.action_data = final
    _touch(proposal.conversation_id)
    return outcome


def _replay(proposal):
    status = _status(proposal)
    outcome = _stored_outcome(proposal)
    if outcome is not None:
        return Resolution(outcome, replayed=True)
    if status == SUPERSEDED:
        raise ProposalUnavailable('superseded', "Cette proposition a été remplacée par une demande plus récente.")
    raise ProposalUnavailable('busy', "Cette opération est en cours de traitement. Réessayez dans un instant.")


def resolve_proposal(user, proposal_id, decision, *, query=None, context='general'):
    """
    Confirme ou annule une proposition. Renvoie une ``Resolution`` :
    ``replayed=False`` quand cet appel a produit le résultat, ``True`` quand il ne fait que relire un résultat existant.
    """
    if decision not in DECISIONS:
        raise ValueError(f"Décision inconnue : {decision!r}")

    with transaction.atomic():
        proposal = AIInteraction.objects.filter(pk=proposal_id, user=user).first()
        if not is_proposal(proposal):
            raise ProposalNotFound()
        if _status(proposal) != PENDING:
            return _replay(proposal)

        if timezone.now() > _expires_at(proposal):
            if not _claim(proposal, PROCESSING):
                return _replay(AIInteraction.objects.get(pk=proposal.pk))
            outcome = _record_outcome(
                proposal, EXPIRED,
                "⏱️ Cette proposition a expiré. Rien n'a été enregistré : reformulez votre demande pour la refaire.",
                ['Consulter mon solde', 'Vérifier mon stock'], query or "Oui, confirme", context,
            )
            return Resolution(outcome)

        if not _claim(proposal, PROCESSING):
            # Une autre requête a pris la main entre la lecture et l'écriture : on relit son résultat
            return _replay(AIInteraction.objects.get(pk=proposal.pk))

        if decision == 'cancel':
            outcome = _record_outcome(
                proposal, CANCELLED,
                "L'opération a été annulée. Aucune modification n'a été apportée à vos données.",
                ['Consulter mon solde', 'Aide pour mes cultures', 'Retour'], query or "Non, annule", context,
            )
            return Resolution(outcome)

        result = execute_action(user, proposal.action_data['action_type'], proposal.action_data.get('parameters') or {})
        if result['success']:
            outcome = _record_outcome(
                proposal, EXECUTED,
                f"✅ **Opération confirmée et enregistrée !**\n\n{result['message']}",
                ['Consulter mon solde', 'Vérifier mon stock', 'Poser une question'],
                query or "Oui, confirme", context, result,
            )
        else:
            logger.info("[Proposals] Proposition %s non exécutée (%s)", proposal.pk, result.get('error_code'))
            outcome = _record_outcome(
                proposal, FAILED,
                f"❌ **Échec de l'enregistrement** : {result['message']}",
                ['Consulter mon solde', 'Vérifier mon stock', 'Poser une question'],
                query or "Oui, confirme", context, result,
            )
        return Resolution(outcome)
