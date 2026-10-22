"""
Recherche dans les fiches agronomiques (base de données Naatal Agro) pour répondre aux questions.

Déterministe et sans appel externe : on repère la culture et le sujet demandés (semis, engrais,
maladies…), puis on renvoie les sections correspondantes avec leurs sources. Ce qui n'est pas
documenté est signalé comme manquant, jamais deviné.
"""
import re
import unicodedata
from dataclasses import dataclass, field

from apps.agriculture.models import AgronomicGuide

# (clé, libellé, mots déclencheurs, champs de la fiche à renvoyer)
# (clé, libellé, mots déclencheurs français et wolof, champs de la fiche à renvoyer)
TOPICS = [
    ('sowing', 'Semis et calendrier',
     ['semer', 'semis', 'semez', 'semons', 'seme', 'planter', 'plantation', 'repiquage', 'repiquer', 'pepiniere',
      'calendrier', 'preparation', 'densite', 'ecartement', 'germination',
      # Déclencheurs Wolof
      'ji', 'jiw', 'suuxat', 'gunge', 'samp'],
     ['calendar', 'soil_and_sowing']),
    ('fertilization', 'Fertilisation',
     ['engrais', 'fertilisation', 'fertiliser', 'fumure', 'fumier', 'npk', 'uree', 'dose', 'compost', 'amendement',
      # Déclencheurs Wolof
      'kompoos', 'doolil', 'wanteer'],
     ['fertilization']),
    ('pests', 'Maladies et ravageurs',
     ['maladie', 'maladies', 'ravageur', 'ravageurs', 'parasite', 'insecte', 'traitement', 'traiter', 'pesticide',
      'mildiou', 'rosette', 'chenille', 'mineuse', 'lutte', 'proteger', 'prevention', 'prevenir', 'aflatoxine',
      # Déclencheurs Wolof
      'faj', 'fajee', 'jangoro', 'max', 'doxandeem', 'garab'],
     ['pests_diseases']),
    ('water', 'Eau et irrigation',
     ['eau', 'irrigation', 'irriguer', 'arroser', 'arrosage', 'pluie', 'pluviometrie', 'secheresse',
      # Déclencheurs Wolof
      'ndox', 'taw', 'suux', 'suuxat', 'roose'],
     ['water_needs']),
    ('harvest', 'Récolte et conservation',
     ['recolte', 'recolter', 'maturite', 'stockage', 'stocker', 'conservation', 'conserver', 'sechage',
      # Déclencheurs Wolof
      'gancax', 'gattal', 'denc', 'watt', 'gobar'],
     ['harvest', 'calendar']),  # le calendrier donne souvent la période de récolte
    ('yield', 'Rendement',
     ['rendement', 'rendements', 'production', 'tonnes', 'productivite',
      # Déclencheurs Wolof
      'menneef', 'meññeef'],
     ['yield_info']),
    ('cycle', 'Cycle et variétés',
     ['cycle', 'duree', 'variete', 'varietes', 'jours', 'precoce', 'tardive'],
     ['calendar', 'zones']),
]
TOPIC_LABELS = {key: label for key, label, _, _ in TOPICS}
OVERVIEW_FIELDS = ['summary', 'zones', 'calendar', 'soil_and_sowing', 'fertilization', 'water_needs',
                   'pests_diseases', 'harvest', 'yield_info']

FIELD_LABELS = {
    'summary': 'Présentation', 'zones': 'Zones de culture', 'calendar': 'Calendrier et cycle',
    'soil_and_sowing': 'Sol, semis et densité', 'water_needs': 'Besoins en eau', 'fertilization': 'Fertilisation',
    'pests_diseases': 'Maladies et ravageurs', 'harvest': 'Récolte et conservation', 'yield_info': 'Rendement',
}

# Dictionnaire de correspondance officiel Wolof <-> Cultures sénégalaises
WOLOF_CROP_ALIASES = {
    'arachide': ['guerte', 'gerte', 'guerteh', 'gerteh'],
    'riz': ['ceeb', 'tieb'],
    'mais': ['mboq', 'mbokk', 'mbook'],
    'oignon': ['soble', 'sobleh'],
    'tomate': ['tomaat', 'tamate', 'tomato'],
    'manioc': ['nambi', 'gnambi', 'yambi', 'ñambi'],
    'niebe': ['nebbe', 'niebbe', 'ñebbe'],
    'mil': ['duggub', 'souna', 'sanio'],
    'sorgho': ['bassi'],
    'aubergine': ['batanse', 'jaxatu', 'diakhatou', 'batañse'],
    'piment': ['kaani', 'kani'],
    'gombo': ['kanja', 'kandja', 'kañja'],
    'pasteque': ['xal', 'khal'],
    'mangue': ['mango', 'màngo'],
    'patate douce': ['patat'],
    'chou': ['su'],
}

# Mots agricoles généraux en français et en wolof
AGRI_TERMS = {
    'culture', 'cultiver', 'agriculture', 'agriculteur', 'champ', 'parcelle', 'sol', 'recolte', 'semis', 'semer',
    'engrais', 'irrigation', 'maladie', 'ravageur', 'variete', 'rendement', 'plant', 'graine', 'graines',
    'fumure', 'verger', 'maraichage', 'cereale', 'cereales', 'legume', 'legumes', 'fruit', 'fruits', 'betail',
    'niebe', 'sorgho', 'manioc', 'patate', 'pomme de terre', 'carotte', 'chou', 'piment', 'aubergine',
    'pasteque', 'gombo', 'mangue', 'banane', 'papaye', 'sesame', 'coton', 'bissap', 'concombre', 'laitue',
    # Termes Wolof généraux
    'ji', 'jiw', 'ceeb', 'soble', 'mboq', 'guerte', 'gerte', 'duggub', 'faj', 'fajee', 'jangoro', 'ndox',
    'taw', 'suuxat', 'tol', 'tool', 'kompoos', 'jaay', 'jend', 'watt', 'denc', 'baykat', 'bay', 'garab'
}

MARKER = re.compile(r'\[(\d+)\]')


def normalize(text):
    """Minuscules, sans accents ni ponctuation : « Récolte ! » devient « recolte »."""
    decomposed = unicodedata.normalize('NFKD', text or '')
    ascii_text = ''.join(c for c in decomposed if not unicodedata.combining(c)).lower()
    return re.sub(r'[^a-z0-9]+', ' ', ascii_text).strip()


def _contains_term(normalized_text, term):
    """Vrai si le terme apparaît comme mot entier (« mil » ne correspond pas à « milieu »)."""
    term = normalize(term)
    return bool(term) and re.search(rf'(?<![a-z0-9]){re.escape(term)}(?![a-z0-9])', normalized_text) is not None


def guide_terms(guide):
    """
    Termes qui désignent la culture d'une fiche : ses alias, son nom (sans la précision entre parenthèses)
    et son nom scientifique complet, enrichis automatiquement par le dictionnaire des termes Wolof.
    """
    base_name = re.sub(r'\(.*?\)', ' ', guide.name)
    terms = set(guide.aliases or [])
    terms.add(base_name)
    if guide.scientific_name:
        terms.add(re.sub(r'\(.*?\)', ' ', guide.scientific_name))

    # Enrichissement automatique avec les alias Wolof correspondants
    norm_base = normalize(base_name)
    for crop_key, wolof_list in WOLOF_CROP_ALIASES.items():
        if crop_key in norm_base or any(crop_key in normalize(a) for a in terms):
            terms.update(wolof_list)

    return {normalize(t) for t in terms if normalize(t)}


WOLOF_MARKERS = {
    'naka', 'lanuy', 'fajee', 'faj', 'soble', 'ceeb', 'mboq', 'guerte', 'gerte', 'duggub',
    'bassi', 'kaani', 'kanja', 'batanse', 'jaxatu', 'tamate', 'tomaat', 'nebbe', 'nambi',
    'amuma', 'amna', 'baykat', 'tol', 'tool', 'suuxat', 'fattali', 'jend', 'jaay',
    'waaw', 'deedet', 'baax', 'naa', 'nanu', 'ci', 'sama', 'samay', 'sunu', 'sunuy',
    'ellek', 'ëllëk', 'suba', 'ngoon', 'doolil', 'wanteer', 'ndox', 'taw'
}

def is_wolof_text(text):
    """Détecte avec certitude si une requête est formulée en wolof."""
    if not text:
        return False
    norm = normalize(text)
    words = set(norm.split())
    strong_markers = {'naka', 'lanuy', 'fajee', 'baykat', 'fattali', 'suuxat', 'duggub', 'kompoos', 'soble', 'ceeb', 'mboq', 'guerte', 'gerte', 'ellek'}
    if words & strong_markers:
        return True
    return len(words & WOLOF_MARKERS) >= 2


# Motifs nominaux prouvant qu'il s'agit de la céréale (Zea mays) et non de la conjonction « mais »
MAIZE_NOUN_PATTERNS = [
    # Déterminants / articles devant « mais » : « le mais », « du mais », « au mais », etc.
    re.compile(r'\b(du|le|au|mon|ton|notre|votre|ce|cet|un)\s+mais\b'),
    # Compléments du nom : « culture de mais », « champ de mais », « semis de mais », etc.
    re.compile(r'\b(champ|culture|semis|semer|graine|graines|grain|grains|variete|varietes|recolte|recolter|plant|plants|tige|tiges|production|cours|prix|marche|sac|sacs|kilo|kilos|kg|tonne|tonnes)\s+(de\s+|du\s+)?mais\b'),
    # Qualificatifs après « mais » : « mais doux », « mais jaune », etc.
    re.compile(r'\bmais\s+(doux|jaune|blanc|hybride|hybrides|pluvial|grain|grains|fourrage|fourrager|ensilage|local)\b'),
]


def _is_maize_match(raw_query, normalized_query):
    """
    Vrai uniquement si la question désigne expressément la céréale (Zea mays).
    En français, 'mais' sans accent est très majoritairement une conjonction de coordination
    (ex: '...tout ça mais pourquoi cette fois-ci...'). Pour éviter les faux positifs aberrants :
    1. Si le tréma 'maïs' est présent dans le texte d'origine -> Match certain.
    2. Si le mot 'mais' sans tréma est inséré dans une locution nominale agricole explicite ('le mais', 'du mais', etc.) -> Match.
    3. Dans tout autre cas (notamment conjonctions 'mais pourquoi', 'mais je', etc.) -> Ignorer.
    """
    raw_lower = raw_query.lower()
    if 'maïs' in raw_lower or 'maïss' in raw_lower:
        return True

    return any(pattern.search(normalized_query) for pattern in MAIZE_NOUN_PATTERNS)


def _guide_matches(guide, raw_query, normalized_query):
    for term in guide_terms(guide):
        if not _contains_term(normalized_query, term):
            continue
        if term == 'mais':
            if _is_maize_match(raw_query, normalized_query):
                return True
            continue
        return True
    return False


def detect_topics(normalized_query):
    return [key for key, _, triggers, _ in TOPICS if any(_contains_term(normalized_query, t) for t in triggers)]


@dataclass
class Section:
    guide: AgronomicGuide
    label: str
    text: str  # repères [n] déjà renumérotés sur la liste globale des sources


@dataclass
class Retrieval:
    sections: list = field(default_factory=list)
    missing: list = field(default_factory=list)    # [(nom de la fiche, libellé du sujet)]
    sources: list = field(default_factory=list)    # [{number, title, publisher, year, url, type}]
    guides: list = field(default_factory=list)
    is_agricultural: bool = False


def _field_text(guide, field_name):
    value = getattr(guide, field_name)
    if field_name == 'pests_diseases':
        if isinstance(value, list):
            lines = []
            for item in value:
                if isinstance(item, dict):
                    name = item.get('name', '')
                    advice = item.get('advice', '')
                    lines.append(f"{name} : {advice}".strip(' :'))
                elif isinstance(item, str):
                    lines.append(item)
            return '\n'.join(lines)
        elif isinstance(value, str):
            return value.strip()
        return ''
    return (value or '').strip()


def _cycle_line(guide):
    if guide.cycle_days_min is None or guide.cycle_days_max is None:
        return ''
    if guide.cycle_days_min == guide.cycle_days_max:
        return f'Cycle : {guide.cycle_days_min} jours.'
    return f'Cycle : de {guide.cycle_days_min} à {guide.cycle_days_max} jours selon les variétés.'


def retrieve(query):
    """Cherche dans les fiches ce qui répond à la question ; renvoie sections, manques et sources."""
    normalized = normalize(query)
    result = Retrieval()
    guides = [g for g in AgronomicGuide.objects.all() if _guide_matches(g, query, normalized)]
    result.guides = guides
    result.is_agricultural = bool(guides) or any(_contains_term(normalized, t) for t in AGRI_TERMS)
    if not guides:
        return result

    topics = detect_topics(normalized)
    if topics:
        wanted = [(TOPIC_LABELS[k], next(fields for key, _, _, fields in TOPICS if key == k)) for k in topics]
    else:
        wanted = [('Fiche complète', OVERVIEW_FIELDS)]

    source_index = {}  # (url) -> numéro global

    def global_number(source):
        key = source.get('url') or source.get('title')
        if key not in source_index:
            source_index[key] = len(source_index) + 1
            result.sources.append({
                'number': source_index[key],
                'title': source.get('title', ''),
                'publisher': source.get('publisher', ''),
                'year': source.get('year', ''),
                'url': source.get('url', ''),
                'scope': source.get('scope', 'senegal'),
                'type': 'fiche',
            })
        return source_index[key]

    for guide in guides:
        def renumber(text, guide=guide):
            def replace(match):
                local = int(match.group(1))
                if local < 1 or local > len(guide.sources):
                    return ''
                return f'[{global_number(guide.sources[local - 1])}]'
            return MARKER.sub(replace, text)

        for topic_label, field_names in wanted:
            parts = []
            for field_name in field_names:
                text = _field_text(guide, field_name)
                if text:
                    if len(field_names) > 1:
                        parts.append(f'{FIELD_LABELS[field_name]} : {text}')
                    else:
                        parts.append(text)
            if topic_label.startswith('Cycle'):
                cycle = _cycle_line(guide)
                if cycle:
                    parts.insert(0, cycle)
            if parts:
                result.sections.append(Section(guide=guide, label=topic_label, text=renumber('\n'.join(parts))))
            else:
                result.missing.append((guide.name, topic_label))
    return result
