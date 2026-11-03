"""
Configuration de développement local pour Naatal Agro.
"""
import os

from .base import *

DEBUG = True
ALLOWED_HOSTS = ['*']

# Code d'inscription de démonstration (aucune passerelle SMS en développement). Peut être vidé dans backend/.env.
OTP_REGISTER_FIXED_CODE = os.getenv('OTP_REGISTER_FIXED_CODE', '1234').strip()

# CORS permissif en environnement de développement
CORS_ALLOW_ALL_ORIGINS = True

# Via le lien de démonstration (tunnel), tous les testeurs partagent la même adresse : la limite de production (10/min)
# bloquerait l'inscription dès que quelques personnes essaient en même temps.
REST_FRAMEWORK['DEFAULT_THROTTLE_RATES'].update({'auth': '120/minute'})
