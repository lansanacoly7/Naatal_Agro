import json
from pathlib import Path

GUIDES_FILE = Path(__file__).resolve().parent / 'data' / 'agronomic_guides.json'

# Champs de la fiche au moment de la migration 0005 (avant l'ajout des alias) : cette migration
# de données doit rester rejouable sur le schéma de l'époque.
INITIAL_GUIDE_FIELDS = (
    'name', 'scientific_name', 'category', 'summary', 'zones', 'cycle_days_min', 'cycle_days_max',
    'calendar', 'soil_and_sowing', 'water_needs', 'fertilization', 'pests_diseases', 'harvest',
    'yield_info', 'limitations', 'sources',
)
GUIDE_FIELDS = INITIAL_GUIDE_FIELDS + ('aliases',)


def read_guides():
    """Contenu des fiches agronomiques, tel qu'écrit dans le dépôt."""
    with GUIDES_FILE.open(encoding='utf-8') as handle:
        return json.load(handle)


def load_guides(guide_model, fields=GUIDE_FIELDS, force=False):
    """
    Crée ou met à jour les fiches du dépôt (clé : ``slug``). Idempotent.

    Une fiche modifiée depuis l'administration (``locally_edited``) n'est pas écrasée, sauf avec
    ``force=True`` : les informations validées par un relecteur ne doivent pas disparaître au rechargement.
    ``guide_model`` est passé en paramètre pour servir aussi dans une migration de données.
    Renvoie ``(traitées, ignorées)``.
    """
    processed = skipped = 0
    for data in read_guides():
        existing = guide_model.objects.filter(slug=data['slug']).first()
        if existing is not None and not force and getattr(existing, 'locally_edited', False):
            skipped += 1
            continue
        defaults = {field: data.get(field, [] if field in ('aliases', 'sources', 'pests_diseases') else '')
                    for field in fields}
        guide_model.objects.update_or_create(slug=data['slug'], defaults=defaults)
        processed += 1
    return processed, skipped
