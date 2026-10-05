import re

# Format international E.164 : « + », indicatif pays (1 à 3 chiffres, sans 0 initial) puis abonné.
E164_PATTERN = re.compile(r'^\+[1-9]\d{7,14}$')
_SEPARATORS = re.compile(r'[\s.\-()]')


def clean_phone(value):
    """Retire espaces, points, tirets et parenthèses sans juger de la validité."""
    return _SEPARATORS.sub('', str(value or ''))


def normalize_phone(value):
    """
    Renvoie le numéro au format E.164 (ex. ``+221771234567``) ou lève ``ValueError``.

    Le mobile envoie déjà « +221… » : le serveur ne devine pas l'indicatif, il refuse les
    numéros qui ne sont pas au format international pour éviter des comptes en double
    (« 771234567 » et « +221771234567 » désignant le même abonné).
    """
    cleaned = clean_phone(value)
    if not E164_PATTERN.match(cleaned):
        raise ValueError("Numéro invalide. Format attendu : +221771234567 (indicatif pays inclus).")
    return cleaned
