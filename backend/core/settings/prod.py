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

# HTTPS (derrière un reverse proxy nginx qui transmet X-Forwarded-Proto)
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
SECURE_SSL_REDIRECT = os.getenv('SECURE_SSL_REDIRECT', 'True').lower() in ('true', '1', 't')
SECURE_HSTS_SECONDS = int(os.getenv('SECURE_HSTS_SECONDS', '3600'))
SECURE_HSTS_INCLUDE_SUBDOMAINS = True

# Fichiers statiques (collectstatic)
STATIC_ROOT = BASE_DIR / 'staticfiles'
