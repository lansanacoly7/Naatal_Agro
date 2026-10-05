"""
Configuration de développement local pour Naatal Agro.
"""
from .base import *

DEBUG = True
ALLOWED_HOSTS = ['*']

# CORS permissif en environnement de développement
CORS_ALLOW_ALL_ORIGINS = True
