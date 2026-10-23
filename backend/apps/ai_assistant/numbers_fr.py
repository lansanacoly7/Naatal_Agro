"""
Lecture des quantités et des montants dits ou écrits en français : « 15000 », « 15 000 FCFA », « 15 mille »,
« quinze mille », « vingt-cinq mille cinq cents », « deux millions ».

La transcription vocale écrit souvent les nombres en lettres : sans cette lecture, « j'ai dépensé quinze mille francs » ne
donnerait aucun montant. Fonctions pures, sans accès à la base.
"""
import re
import unicodedata

_UNITS = {'zero': 0, 'un': 1, 'une': 1, 'deux': 2, 'trois': 3, 'quatre': 4, 'cinq': 5, 'six': 6, 'sept': 7, 'huit': 8,
          'neuf': 9, 'dix': 10, 'onze': 11, 'douze': 12, 'treize': 13, 'quatorze': 14, 'quinze': 15, 'seize': 16}
_TENS = {'vingt': 20, 'vingts': 20, 'trente': 30, 'quarante': 40, 'cinquante': 50, 'soixante': 60}
_NUMBER_WORDS = set(_UNITS) | set(_TENS) | {'cent', 'cents', 'mille', 'milles', 'million', 'millions', 'et'}
_DIGITS = re.compile(r"\d[\d\s.,]*\d|\d")
_MULTIPLIED_DIGITS = re.compile(r"(\d[\d.,]*)\s*(mille|milles|k|million|millions)\b")


def _plain(text):
    decomposed = unicodedata.normalize('NFD', str(text or '').lower())
    return ''.join(ch for ch in decomposed if unicodedata.category(ch) != 'Mn')


def _digits_to_float(raw):
    """« 15 000 », « 15.000 », « 15,5 » -> 15000.0, 15000.0, 15.5 (même convention que les montants de l'application)."""
    clean = re.sub(r"[^\d,.]", '', raw)
    if not clean:
        return None
    if re.match(r"^\d{1,3}(?:\.\d{3})+$", clean):
        clean = clean.replace('.', '')
    elif re.match(r"^\d{1,3}(?:,\d{3})+$", clean):
        clean = clean.replace(',', '')
    else:
        clean = clean.replace(',', '.')
    try:
        return float(clean)
    except ValueError:
        return None


def _words_value(words):
    """Valeur d'une suite de mots-nombres (« vingt cinq mille cinq cents » -> 25500)."""
    total = current = 0
    index = 0
    while index < len(words):
        word = words[index]
        if word == 'et':
            pass
        elif word == 'quatre' and index + 1 < len(words) and words[index + 1] in ('vingt', 'vingts'):
            current += 80  # quatre-vingt(s)
            index += 1
        elif word in _UNITS:
            current += _UNITS[word]
        elif word in _TENS:
            current += _TENS[word]
        elif word in ('cent', 'cents'):
            current = (current or 1) * 100 if current < 100 else current + 100
        elif word in ('mille', 'milles'):
            total += (current or 1) * 1000
            current = 0
        elif word in ('million', 'millions'):
            total += (current or 1) * 1_000_000
            current = 0
        index += 1
    return total + current


def words_to_number(text):
    """
    Plus grand nombre écrit en lettres dans ``text``, ou ``None``. On retient la plus grande suite de mots-nombres : dans
    « un peu plus de dix mille », « un » n'est pas le montant, « dix mille » l'est.
    """
    tokens = re.findall(r"[a-z]+", _plain(text).replace('-', ' '))
    best, run = None, []

    def close(run):
        nonlocal best
        while run and run[0] == 'et':
            run = run[1:]
        while run and run[-1] == 'et':
            run = run[:-1]
        if run:
            value = _words_value(run)
            if value > 0 and (best is None or value > best):
                best = value

    for token in tokens:
        if token in _NUMBER_WORDS:
            run.append(token)
        else:
            close(run)
            run = []
    close(run)
    return float(best) if best is not None else None


def parse_amount(text):
    """
    Premier montant ou quantité lisible dans ``text`` : chiffres (« 15 000 »), chiffres + multiplicateur (« 15 mille »,
    « 2 millions ») ou mots (« quinze mille »). ``None`` si aucun nombre strictement positif n'est trouvé.
    """
    plain = _plain(text)
    multiplied = _MULTIPLIED_DIGITS.search(plain)
    if multiplied:
        base = _digits_to_float(multiplied.group(1))
        if base:
            factor = 1_000_000 if multiplied.group(2).startswith('million') else 1000
            return base * factor
    digits = _DIGITS.search(plain)
    if digits:
        value = _digits_to_float(digits.group(0))
        if value and value > 0:
            return value
    return words_to_number(plain)
