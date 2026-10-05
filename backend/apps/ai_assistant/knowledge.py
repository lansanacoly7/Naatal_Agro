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

# Mots du nom d'une fiche qui ne désignent pas la culture (pour ne pas confondre « vallée » avec une culture)
NAME_STOPWORDS = {
    'industrielle', 'irrigue', 'irriguee', 'vallee', 'fleuve', 'senegal', 'niayes', 'bassin', 'arachidier',
    'dans', 'des', 'les', 'sur', 'pour',
}

# (clé, libellé, mots déclencheurs, champs de la fiche à renvoyer)
TOPICS = [
    ('sowing', 'Semis et calendrier',
     ['semer', 'semis', 'semez', 'semons', 'seme', 'planter', 'plantation', 'repiquage', 'repiquer', 'pepiniere',
      'quand', 'periode', 'calendrier', 'date', 'preparation', 'densite', 'ecartement', 'germination'],
     ['calendar', 'soil_and_sowing']),
    ('fertilization', 'Fertilisation',
     ['engrais', 'fertilisation', 'fertiliser', 'fumure', 'fumier', 'npk', 'uree', 'dose', 'compost', 'amendement'],
     ['fertilization']),
    ('pests', 'Maladies et ravageurs',
     ['maladie', 'maladies', 'ravageur', 'ravageurs', 'parasite', 'insecte', 'traitement', 'traiter', 'pesticide',
      'mildiou', 'rosette', 'chenille', 'mineuse', 'lutte', 'proteger', 'prevention', 'prevenir', 'aflatoxine'],
     ['pests_diseases']),
    ('water', 'Eau et irrigation',
     ['eau', 'irrigation', 'irriguer', 'arroser', 'arrosage', 'pluie', 'pluviometrie', 'secheresse'],
     ['water_needs']),
    ('harvest', 'Récolte et conservation',
     ['recolte', 'recolter', 'maturite', 'stockage', 'stocker', 'conservation', 'conserver', 'sechage'],
     ['harvest']),
    ('yield', 'Rendement',
     ['rendement', 'rendements', 'production', 'tonnes', 'productivite'],
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

# Mots agricoles généraux : permettent de savoir qu'une question relève de l'agriculture même sans fiche.
# (« maïs » est volontairement absent : une fois sans accent il se confond avec la conjonction « mais ».)
AGRI_TERMS = {
    'culture', 'cultiver', 'agriculture', 'agriculteur', 'champ', 'parcelle', 'sol', 'recolte', 'semis', 'semer',
    'engrais', 'irrigation', 'maladie', 'ravageur', 'variete', 'rendement', 'plant', 'graine', 'graines',
    'fumure', 'verger', 'maraichage', 'cereale', 'cereales', 'legume', 'legumes', 'fruit', 'fruits', 'betail',
    'niebe', 'sorgho', 'manioc', 'patate', 'pomme de terre', 'carotte', 'chou', 'piment', 'aubergine',
    'pasteque', 'gombo', 'mangue', 'banane', 'papaye', 'sesame', 'coton', 'bissap', 'concombre', 'laitue',
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
    """Termes qui désignent la culture d'une fiche : alias, mots significatifs du nom, nom scientifique."""
    terms = set(guide.aliases or [])
    terms.update(w for w in normalize(guide.name).split() if len(w) >= 3 and w not in NAME_STOPWORDS)
    if guide.scientific_name:
        terms.add(guide.scientific_name)
    return {normalize(t) for t in terms if normalize(t)}


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
        return '\n'.join(f"{item['name']} : {item['advice']}" for item in value)
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
    guides = [g for g in AgronomicGuide.objects.all()
              if any(_contains_term(normalized, t) for t in guide_terms(g))]
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
