"""
Ce que l'assistant sait faire, et ce qu'il dit quand on lui demande autre chose.

Règle : une demande d'action qu'il ne sait pas faire reçoit une réponse honnête (« je ne sais pas faire ça »), ce que
la personne peut faire elle-même, et ce que l'assistant sait faire. Jamais une fiche technique sans rapport avec la demande.
"""
import re

from .knowledge import normalize

_MESSAGING = r"(?:sms|message|whatsapp|mail|email|courriel)"
_OUTSIDE = r"(?:envoie|envoyer|appelle|appeler|telephone|telephoner|commande|commander|paie|payer|paye|reserve|reserver|achete moi|acheter pour moi)"

RE_OUTSIDE = re.compile(rf"\b{_OUTSIDE}\b")
RE_SEND = re.compile(rf"\b(?:envoie|envoyer)\b.*\b{_MESSAGING}\b|\b{_MESSAGING}\b.*\b(?:envoie|envoyer)\b")

CAN_DO = [
    'Enregistrer une vente, une dépense ou votre stock (et les annuler)',
    'Ajouter une culture, une activité (arrosage, engrais…) ou une récolte',
    'Programmer un rappel ou une alerte',
    'Vous dire la météo de votre zone et où en sont vos ventes et vos dépenses',
    'Répondre sur vos cultures : semis, engrais, eau, maladies',
]
SUGGESTIONS = ['Ajoute une activité', 'Créer une alerte', 'Quand semer ?', 'Mon solde']


def _can_do_text():
    return "Voici ce que je sais faire :\n" + "\n".join(f"• {line}" for line in CAN_DO)


def unsupported_request(query):
    """
    ``{'text', 'suggestions'}`` si la demande est une action que l'assistant ne sait pas faire, sinon ``None``.
    Les demandes qu'il sait faire (rappels, ventes, dépenses, stock) ont été traitées avant cet appel.
    """
    q = normalize(query)
    if RE_SEND.search(q) or RE_OUTSIDE.search(q):
        return {
            'text': ("Je ne sais pas faire cela : je ne peux ni envoyer de message, ni appeler, ni commander ou payer à votre place.\n\n"
                     + _can_do_text()),
            'suggestions': SUGGESTIONS,
        }
    return None
