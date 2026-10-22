"""
Catégories de dépenses agricoles et classement automatique, déterministe, à partir du libellé.

Le classement s'appuie sur des racines de mots (français et quelques termes wolof courants), jamais sur un
modèle de langage : un même libellé donne toujours la même catégorie. Quand rien ne correspond, la dépense est
rangée dans « autre » et l'assistant le signale à l'utilisateur au lieu de deviner.
"""
import re
import unicodedata

CATEGORY_CHOICES = [
    ('semences', 'Semences et plants'),
    ('engrais', 'Engrais et amendements'),
    ('phytosanitaire', 'Produits phytosanitaires'),
    ('main_oeuvre', "Main-d'œuvre et travaux"),
    ('carburant_transport', 'Carburant et transport'),
    ('irrigation', 'Irrigation et eau'),
    ('materiel', 'Matériel et outillage'),
    ('stockage', 'Stockage et emballage'),
    ('autre', 'Autre'),
]
CATEGORY_LABELS = dict(CATEGORY_CHOICES)
CATEGORY_CODES = frozenset(CATEGORY_LABELS)
DEFAULT_CATEGORY = 'autre'

# Ordre significatif : la première catégorie dont une racine apparaît gagne. On classe ce qui est ACHETÉ :
# « carburant du tracteur » -> carburant, « carburant pour le labour » -> carburant (pas main-d'œuvre),
# « engrais pour le mil » -> engrais.
_KEYWORDS = (
    ('phytosanitaire', ('pesticide', 'insecticide', 'fongicide', 'herbicide', 'phytosanitaire', 'traitement',
                        'produit de traitement', 'neem', 'nematicide', 'raticide', 'antiparasit', 'antifong')),
    ('engrais', ('engrais', 'uree', 'npk', 'compost', 'fumier', 'fertilis', 'amendement', 'phosphate',
                 'kompoos', 'fiente', 'bokashi', 'chaux')),
    ('semences', ('semence', 'graine', 'plant ', 'plants', 'boutures', 'pepiniere', 'semis', 'noyaux')),
    ('carburant_transport', ('carburant', 'essence', 'gasoil', 'gazoil', 'diesel', 'transport', 'camion',
                             'charrette', 'livraison', 'taxi', 'pirogue', 'fret')),
    ('main_oeuvre', ('main d oeuvre', 'ouvrier', 'salaire', 'journalier', 'manoeuvre',
                     'recrut', 'gardien', 'saisonnier', 'travailleur',
                     # travaux agricoles, payés à la tâche ou à la prestation
                     'labour', 'preparation du sol', 'planches', 'sarclage', 'binage', 'desherbage',
                     'plantation', 'tuteurage', 'repiquage', 'buttage', 'paillage')),
    ('irrigation', ('irrigation', 'arrosage', 'forage', 'puits', 'goutte a goutte', 'tuyau', 'motopompe',
                    'pompe', 'eau ', 'sonede', 'arroser')),
    ('stockage', ('emballage', 'stockage', 'conservation', 'entrepot', 'magasin', 'sacherie', 'cageot',
                  'caisse vide', 'bache')),
    ('materiel', ('tracteur', 'outil', 'houe', 'hilaire', 'materiel', 'reparation', 'machine', 'semoir',
                  'charrue', 'brouette', 'pelle', 'arrosoir', 'moissonn', 'decortiqueuse', 'batteuse')),
)


def normalize_text(text):
    """Minuscules, sans accent ni ponctuation, entouré d'espaces (pour des recherches par mot entier)."""
    decomposed = unicodedata.normalize('NFD', str(text or '').lower().replace('œ', 'oe'))
    plain = ''.join(ch for ch in decomposed if unicodedata.category(ch) != 'Mn')
    return ' ' + ' '.join(re.sub(r'[^a-z0-9]+', ' ', plain).split()) + ' '


def infer_expense_category(text):
    """Code de catégorie pour un libellé de dépense (``'autre'`` si aucune racine ne correspond)."""
    normalized = normalize_text(text)
    for category, stems in _KEYWORDS:
        for stem in stems:
            # Une racine doit commencer un mot : « uree » ne doit pas correspondre à « figuree »
            if re.search(r'(?<=\s)' + re.escape(stem), normalized):
                return category
    return DEFAULT_CATEGORY


def infer_activity_category(activity_type, description=''):
    """
    Catégorie du coût d'une activité de culture : son TYPE (« Plantation et tuteurage ») prime sur sa description,
    qui peut citer des intrants sans que le coût en soit un (« mise en terre des plants »).
    """
    category = infer_expense_category(activity_type)
    return category if category != DEFAULT_CATEGORY else infer_expense_category(description)


def category_label(code):
    return CATEGORY_LABELS.get(code, CATEGORY_LABELS[DEFAULT_CATEGORY])
