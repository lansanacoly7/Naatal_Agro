"""
Reconstruit ``apps/agriculture/data/crop_calendar_sn.json`` à partir de l'API publique du calendrier cultural de la FAO
(https://cropcalendar.apps.fao.org) et des compléments sourcés de ``crop_calendar_sources.py``.

Le fichier produit est versionné dans le dépôt : l'application ne dépend jamais de la FAO au moment d'être utilisée.
Cette commande ne sert qu'à le mettre à jour quand la FAO republie ses données.
"""
import calendar
import json
import re
from pathlib import Path

import requests
from django.core.management.base import BaseCommand, CommandError

from apps.agriculture import crop_calendar_sources as src

API = 'https://api-cropcalendar.apps.fao.org/api/v1'
OUTPUT = Path(__file__).resolve().parents[2] / 'data' / 'crop_calendar_sn.json'

# Fautes de frappe repérées dans les libellés FAO
LABEL_FIXES = {'culture trdive': 'Culture tardive'}


def clean_label(text):
    text = (text or '').strip()
    text = LABEL_FIXES.get(text.lower(), text)
    return text[:1].upper() + text[1:] if text else ''


def month_day(node, last_day_of_month=False):
    """(mois, jour) d'un repère FAO ; le jour est ramené à la fin du mois s'il n'existe pas (ex. 31 novembre)."""
    if not node or not node.get('month'):
        return None
    month, day = int(node['month']), int(node['day'])
    return month, min(day, calendar.monthrange(2024, month)[1])


def cycle_days(growing):
    values = re.findall(r'\d+', (growing or {}).get('value', '') or '')
    if not values:
        return None, None
    return int(values[0]), int(values[-1])


class Command(BaseCommand):
    help = 'Télécharge le calendrier cultural FAO du Sénégal et écrit le fichier de données de l\'application.'

    def handle(self, *args, **options):
        zones = {z['fao_id']: z for z in src.ZONES}
        params = {'language': 'fr', 'crop': ','.join(src.FAO_CROPS), 'aez': ','.join(zones)}
        try:
            response = requests.get(f'{API}/countries/SN/cropCalendar', params=params, timeout=60, headers={'User-Agent': 'NaatalAgro/1.0'})
            response.raise_for_status()
            rows = response.json()
        except (requests.RequestException, ValueError) as exc:
            raise CommandError(f'La FAO ne répond pas : {exc}')

        windows, seen = [], set()
        for row in rows:
            crop_id = row['crop']['id']
            if crop_id not in src.FAO_CROPS or row['aez']['id'] not in zones:
                continue
            key, name, category = src.FAO_CROPS[crop_id]
            zone = zones[row['aez']['id']]['code']
            updated = row.get('lastUpdated', '')
            for session in row.get('sessions', []):
                sow_start, sow_end = month_day(session.get('early_sowing')), month_day(session.get('later_sowing'))
                harvest_start, harvest_end = month_day(session.get('early_harvest')), month_day(session.get('late_harvest'))
                cycle_min, cycle_max = cycle_days(session.get('growing_period'))
                label = clean_label(session.get('additional_information'))
                all_year = session.get('all_year') == 'yes'
                identity = (key, zone, label, sow_start, sow_end, harvest_start, harvest_end, all_year)
                if identity in seen:
                    continue  # la FAO répète certaines lignes à l'identique
                seen.add(identity)
                windows.append({
                    'crop_key': key, 'crop_name': name, 'category': category, 'zone': zone, 'label': label,
                    'all_year': all_year,
                    'sow': list(sow_start + sow_end) if sow_start and sow_end and not all_year else None,
                    'harvest': list(harvest_start + harvest_end) if harvest_start and harvest_end and not all_year else None,
                    'cycle_days_min': cycle_min, 'cycle_days_max': cycle_max,
                    'period_text': 'Toute l\'année' if all_year else '',
                    'notes': (session.get('comments') or '').strip(),
                    'source_key': 'fao',
                    'source_note': f"FAO : {row['crop']['name']}" if row['crop']['name'].lower() != name.lower() else '',
                    'source_updated': '-'.join(reversed(updated.split('/'))) if updated else '',
                })

        for extra in src.SUPPLEMENT:
            windows.append({
                'crop_key': extra['crop_key'], 'crop_name': extra['crop_name'], 'category': extra['category'],
                'zone': extra['zone'], 'label': extra['label'], 'all_year': extra.get('all_year', False),
                'sow': None, 'harvest': list(extra['harvest']) if extra.get('harvest') else None,
                'cycle_days_min': None, 'cycle_days_max': None, 'period_text': extra.get('period_text', ''),
                'notes': extra.get('notes', ''), 'source_key': extra['source_key'], 'source_note': '', 'source_updated': '',
            })

        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(json.dumps({'windows': windows}, ensure_ascii=False, indent=1), encoding='utf-8')
        crops = {w['crop_key'] for w in windows}
        self.stdout.write(self.style.SUCCESS(f'{len(windows)} périodes écrites pour {len(crops)} cultures dans {OUTPUT}.'))
