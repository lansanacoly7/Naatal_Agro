import json
from pathlib import Path

GUIDES_FILE = Path(__file__).resolve().parent / 'data' / 'agronomic_guides.json'

GUIDE_FIELDS = (
    'name', 'scientific_name', 'category', 'summary', 'zones', 'cycle_days_min', 'cycle_days_max',
    'calendar', 'soil_and_sowing', 'water_needs', 'fertilization', 'pests_diseases', 'harvest',
    'yield_info', 'limitations', 'sources',
)


def read_guides():
    """Contenu des fiches agronomiques, tel qu'écrit dans le dépôt."""
    with GUIDES_FILE.open(encoding='utf-8') as handle:
        return json.load(handle)


def load_guides(guide_model):
    """
    Crée ou met à jour les fiches (clé : ``slug``). Idempotent : peut être relancé sans doublon.
    ``guide_model`` est passé en paramètre pour servir aussi dans une migration de données.
    Renvoie le nombre de fiches traitées.
    """
    guides = read_guides()
    for data in guides:
        defaults = {field: data[field] for field in GUIDE_FIELDS}
        guide_model.objects.update_or_create(slug=data['slug'], defaults=defaults)
    return len(guides)
