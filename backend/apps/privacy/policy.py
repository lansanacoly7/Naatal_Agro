from pathlib import Path

# À incrémenter à chaque modification de policy_fr.md : la version acceptée est enregistrée sur le compte.
POLICY_VERSION = '1.0'

_POLICY_FILE = Path(__file__).resolve().parent / 'policy_fr.md'


def load_policy_text():
    """Texte de la politique de confidentialité (français), lu depuis le dépôt."""
    return _POLICY_FILE.read_text(encoding='utf-8')
