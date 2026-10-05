"""
Configuration de production sécurisée pour Naatal Agro.
"""
import os
from .base import *

DEBUG = False

# Hôtes autorisés définis par variable d'environnement
ALLOWED_HOSTS = os.getenv('ALLOWED_HOSTS', 'naatal-agro.sn,api.naatal-agro.sn').split(',')

# Clé secrète obligatoire en production
SECRET_KEY = os.getenv('SECRET_KEY')
if not SECRET_KEY:
    raise ValueError("La variable d'environnement SECRET_KEY est obligatoire en production.")

# Sécurité HTTP & Cookies
SECURE_BROWSER_XSS_FILTER = True
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = 'DENY'
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

# CORS restreint aux domaines officiels
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = os.getenv(
    'CORS_ALLOWED_ORIGINS',
    'https://naatal-agro.sn,https://admin.naatal-agro.sn'
).split(',')
