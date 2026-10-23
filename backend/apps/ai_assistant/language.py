"""
Reconnaissance de la langue (français / wolof / mélange) par lexique pondéré.

Sans bibliothèque externe ni appel réseau : le résultat est reproductible et mesurable (voir ``evaluation/``). Le lexique
wolof est volontairement prudent : les mots qui existent aussi en français (« ma », « la », « si », « sa »…) ne comptent que
très peu, et seuls les mots propres au wolof déclenchent la détection. Il est à faire valider par un locuteur natif.
"""
import re
import unicodedata
from dataclasses import dataclass

FRENCH = 'fr'
WOLOF = 'wo'
MIXED = 'mixed'


def _plain(text):
    decomposed = unicodedata.normalize('NFKD', (text or '').replace('’', "'"))
    ascii_text = ''.join(c for c in decomposed if not unicodedata.combining(c)).lower()
    return re.sub(r"[^a-z0-9]+", ' ', ascii_text).strip()


# Mots propres au wolof (sans équivalent français) : poids 2. Orthographes courantes (accents retirés, doublements variables).
_WOLOF_STRONG = frozenset(_plain(w) for w in """
naka nakka lan lanu lanuy lii loolu ana kan kanam ndax ñaata ñata nata
bëgg begg mën dafa dama danu dina dinaa damay danuy
jaay jaayal jënd jend fey feyal xaalis xaliss
depaase depase dépaase sama samay sunu sunuy nga ngeen yaw yéen yeen ñoom nun
waaw wàll déedéet deedet deedeet jërëjëf jerejef baax rafet
tey tay ëllëg ellek ellëg ëllëk elleg démb demb suba ngoon guddi
tool toolu mbay baykat jiyee ji ñu ñuy mu muy maa ngi maangi fi fale foofu
fajee faj fajal fajoo soble sooble ceeb dugub dugup nebbe niebe tamaate tomaat
ndox suuxat suuxatal fattali fattaliku kompoos ngelaw taw tawat
xam xamul xamuma amul amuma amna am naa nanu nu dem dëkk ñëw wax waxal
yaakaar yaa topp toppal sax saxal yokk yokkal wàññi wanni
mbind lekk lekkal ndaw mag
""".split())

# Mots wolof dont la forme existe en français : poids faible, ils ne décident jamais seuls
_WOLOF_AMBIGUOUS = frozenset(['ci', 'ma', 'la', 'si', 'bi', 'bu', 'ba', 'na', 'ak', 'ko', 'te', 'ne', 'li', 'lu', 'yi', 'wi'])

# Mots grammaticaux français fréquents : preuve de français
_FRENCH = frozenset(_plain(w) for w in """
le la les un une des du de et est sont pour avec sans dans sur sous par que qui quoi quand comment pourquoi combien
mon ma mes ton ta tes son sa ses notre nos votre vos leur leurs ce cet cette ces je tu il elle nous vous ils elles
ai as avons avez ont suis es sommes etes fait faire vendu vendre achete acheter paye payer recu recoit
aujourd demain hier matin soir semaine mois annee besoin veux voudrais peux peut dois faut
rappelle moi mes stock vente ventes depense depenses recolte culture champ
merci bonjour salut oui non aide aider pas plus moins tres bien mal
""".split())
_FRENCH_AMBIGUOUS_WITH_WOLOF = frozenset(['ma', 'la', 'sa', 'moi', 'mon'])  # « ma », « la », « sa » : français ET wolof
# Mots-outils français (pas de noms : « stock », « vente », « sac » s'emploient aussi en wolof) : preuve d'un mélange
_FRENCH_FUNCTION = frozenset(_plain(w) for w in """
le les un une des du de et est sont pour avec sans dans sur sous par que qui quoi quand comment pourquoi combien
mes ton tes ses notre nos votre vos leur leurs ce cet cette ces je tu il elle vous ils elles ai as avons avez ont
suis fait aujourd demain hier maintenant ou mais donc car attendre dois peux veux voudrais
""".split())

_STRONG_WEIGHT = 2.0
_AMBIGUOUS_WEIGHT = 0.3
_MIN_STRONG = 2.0   # au moins un mot propre au wolof (poids 2) pour parler de wolof
_MIXED_FRENCH = 1.0  # au moins un mot-outil français dans un énoncé wolof pour dire « mélange »


@dataclass(frozen=True)
class Detection:
    language: str
    wolof_score: float
    french_score: float

    @property
    def is_wolof(self):
        return self.language == WOLOF


def detect(text, previous=None):
    """
    ``Detection`` : ``fr``, ``wo`` ou ``mixed`` (wolof et français dans le même message).

    ``previous`` : langue du message précédent ; elle départage les messages trop courts pour être reconnus (« oui »,
    « 15000 ») afin de conserver la langue d'une conversation qui change d'énoncé.
    """
    words = _plain(text).split()
    wolof = sum(_STRONG_WEIGHT for w in words if w in _WOLOF_STRONG and w not in _FRENCH)
    wolof += sum(_AMBIGUOUS_WEIGHT for w in words if w in _WOLOF_AMBIGUOUS and w not in _FRENCH)
    french = sum(1.0 for w in words if w in _FRENCH and w not in _FRENCH_AMBIGUOUS_WITH_WOLOF)
    function_words = sum(1.0 for w in words if w in _FRENCH_FUNCTION)

    if wolof >= _MIN_STRONG:
        language = MIXED if function_words >= _MIXED_FRENCH else WOLOF
    elif function_words == 0 and wolof < 1.0 and previous in (FRENCH, WOLOF, MIXED) and len(words) <= 3:
        language = previous
    else:
        language = FRENCH
    return Detection(language, round(wolof, 2), round(french, 2))


def is_wolof(text, previous=None):
    """Vrai si l'énoncé est du wolof ou un mélange où le wolof domine (la réponse doit alors être en wolof)."""
    return detect(text, previous).language == WOLOF
