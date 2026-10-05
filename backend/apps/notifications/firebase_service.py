import logging
import os
import firebase_admin
from firebase_admin import credentials, messaging
from django.conf import settings

logger = logging.getLogger(__name__)

# Initialiser l'application Firebase une seule fois
def get_firebase_app():
    if not firebase_admin._apps:
        cred_path = getattr(settings, 'FIREBASE_CREDENTIALS_PATH', None)
        if cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            return firebase_admin.initialize_app(cred)
        else:
            logger.warning("Identifiants Firebase introuvables : notifications push désactivées.")
            return None
    return firebase_admin.get_app()

def send_push_notification(fcm_token, title, body, data=None):
    app = get_firebase_app()
    if not app or not fcm_token:
        return False

    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=data if data else {},
        token=fcm_token,
    )
    
    try:
        response = messaging.send(message)
        logger.info("Notification push envoyée : %s", response)
        return True
    except Exception as e:
        logger.error("Échec de l'envoi de la notification push : %s", e)
        return False
