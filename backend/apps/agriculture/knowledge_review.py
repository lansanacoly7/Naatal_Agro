"""
Validation humaine des informations proposées pour les fiches agronomiques.

Une proposition n'est jamais appliquée automatiquement : un relecteur l'approuve (ou la rejette)
depuis l'administration, après avoir comparé le texte à l'extrait de la source.
"""
from urllib.parse import urlparse

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .models import KnowledgeProposal


class ProposalError(ValueError):
    """La proposition ne peut pas être traitée (état, source non fiable, champ manquant)."""


def trusted_domains():
    return [d.lower() for d in settings.TRUSTED_WEB_DOMAINS]


def is_trusted_url(url):
    """Vrai si l'URL est en https et son site appartient à la liste des domaines de confiance."""
    try:
        parsed = urlparse(url)
    except ValueError:
        return False
    host = (parsed.hostname or '').lower()
    if parsed.scheme != 'https' or not host:
        return False
    return any(host == domain or host.endswith('.' + domain) for domain in trusted_domains())


def _source_number(guide, proposal):
    """Numéro [n] de la source de la proposition dans la fiche ; l'ajoute si elle n'y figure pas."""
    for index, source in enumerate(guide.sources, start=1):
        if source.get('url') == proposal.source_url:
            return index
    guide.sources = list(guide.sources) + [{
        'title': proposal.source_title,
        'publisher': proposal.source_publisher,
        'year': proposal.source_year,
        'url': proposal.source_url,
    }]
    return len(guide.sources)


@transaction.atomic
def approve_proposal(proposal, reviewer, note=''):
    """Ajoute le texte proposé à la fiche, avec son repère de source, puis clôture la proposition."""
    if proposal.status != 'pending':
        raise ProposalError("Cette proposition a déjà été traitée.")
    if not is_trusted_url(proposal.source_url):
        raise ProposalError("La source n'est pas dans la liste des domaines de confiance (https obligatoire).")
    if not proposal.quote.strip():
        raise ProposalError("L'extrait exact de la source est obligatoire.")
    if proposal.field == 'pests_diseases' and not proposal.pest_name.strip():
        raise ProposalError("Le nom du ravageur ou de la maladie est obligatoire.")

    guide = proposal.guide
    number = _source_number(guide, proposal)
    text = proposal.proposed_text.strip()
    if f'[{number}]' not in text:
        text = f'{text} [{number}]'

    if proposal.field == 'pests_diseases':
        guide.pests_diseases = list(guide.pests_diseases) + [{'name': proposal.pest_name.strip(), 'advice': text}]
    else:
        current = getattr(guide, proposal.field)
        setattr(guide, proposal.field, f'{current}\n{text}' if current else text)

    guide.locally_edited = True
    guide.save()

    proposal.status = 'approved'
    proposal.reviewed_by = reviewer
    proposal.reviewed_at = timezone.now()
    proposal.review_note = note
    proposal.save(update_fields=['status', 'reviewed_by', 'reviewed_at', 'review_note'])
    return guide


@transaction.atomic
def reject_proposal(proposal, reviewer, note=''):
    if proposal.status != 'pending':
        raise ProposalError("Cette proposition a déjà été traitée.")
    proposal.status = 'rejected'
    proposal.reviewed_by = reviewer
    proposal.reviewed_at = timezone.now()
    proposal.review_note = note
    proposal.save(update_fields=['status', 'reviewed_by', 'reviewed_at', 'review_note'])
    return proposal


def pending_proposals():
    return KnowledgeProposal.objects.filter(status='pending')
