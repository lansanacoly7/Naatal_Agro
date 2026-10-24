"""
Garde-fou des scripts qui EFFACENT des données (peuplement de démonstration, remise à zéro du catalogue…).

Règles : jamais en production (``DEBUG`` faux), jamais sans une confirmation explicite. La confirmation est un
argument ``--yes`` (scripts non interactifs) ou une réponse tapée au clavier ; sans terminal et sans ``--yes``, le script
refuse plutôt que de supposer.
"""
import sys


class UnsafeOperation(SystemExit):
    """Arrêt propre d'un script dangereux : le message est affiché et le code de sortie vaut 1."""

    def __init__(self, message):
        super().__init__(f"ERREUR : {message}")


def database_label():
    from django.conf import settings
    db = settings.DATABASES['default']
    return f"{db['ENGINE'].rsplit('.', 1)[-1]} : {db.get('NAME')}"


def require_safe_to_erase(action, *, assume_yes=False, stream=None, ask=input):
    """Lève ``UnsafeOperation`` sauf si on est hors production ET que la personne a confirmé."""
    from django.conf import settings

    if not settings.DEBUG:
        raise UnsafeOperation(
            f"Refusé : « {action} » efface des données et l'environnement n'est pas un environnement de développement "
            f"(DEBUG est faux, réglages {settings.SETTINGS_MODULE}).")
    if assume_yes:
        return
    stream = stream or sys.stdin
    if not getattr(stream, 'isatty', lambda: False)():
        raise UnsafeOperation(f"Refusé : « {action} » demande une confirmation et aucun terminal n'est disponible. "
                              "Relancez avec --yes si c'est bien voulu.")
    print(f"ATTENTION : {action}\n   Base concernée : {database_label()}")
    if ask("Tapez « oui » pour continuer : ").strip().lower() != 'oui':
        raise UnsafeOperation("Annulé : rien n'a été modifié.")
