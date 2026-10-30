import json
from pathlib import Path

CALENDAR_FILE = Path(__file__).resolve().parent / 'data' / 'crop_calendar_sn.json'

_COPIED = (
    'crop_name', 'category', 'all_year', 'cycle_days_min', 'cycle_days_max', 'period_text', 'notes',
    'source_key', 'source_note', 'source_updated',
)


def read_calendar():
    """Périodes du calendrier agricole, telles qu'écrites dans le dépôt (voir ``build_crop_calendar_data``)."""
    with CALENDAR_FILE.open(encoding='utf-8') as handle:
        return json.load(handle)['windows']


def _span(window, name):
    values = window.get(name)
    if not values:
        return {f'{name}_start_month': None, f'{name}_start_day': None, f'{name}_end_month': None, f'{name}_end_day': None}
    start_month, start_day, end_month, end_day = values
    return {
        f'{name}_start_month': start_month, f'{name}_start_day': start_day,
        f'{name}_end_month': end_month, f'{name}_end_day': end_day,
    }


def load_crop_calendar(entry_model, force=False):
    """
    Crée ou met à jour les périodes du dépôt. Idempotent. Une période corrigée à la main (``locally_edited``)
    n'est jamais écrasée, sauf avec ``force``. Renvoie (créées, mises à jour, ignorées).
    """
    created = updated = skipped = 0
    for window in read_calendar():
        sow, harvest = _span(window, 'sow'), _span(window, 'harvest')
        identity = {
            'crop_key': window['crop_key'], 'zone': window['zone'], 'label': window['label'],
            'sow_start_month': sow['sow_start_month'], 'sow_start_day': sow['sow_start_day'],
            'harvest_start_month': harvest['harvest_start_month'], 'harvest_start_day': harvest['harvest_start_day'],
        }
        values = {name: window[name] for name in _COPIED}
        values.update(sow)
        values.update(harvest)
        existing = entry_model.objects.filter(**identity).first()
        if existing is None:
            entry_model.objects.create(**identity, **{k: v for k, v in values.items() if k not in identity})
            created += 1
        elif existing.locally_edited and not force:
            skipped += 1
        else:
            for name, value in values.items():
                setattr(existing, name, value)
            existing.locally_edited = False
            existing.save()
            updated += 1
    return created, updated, skipped
