import os
import json
import urllib.request
from dotenv import load_dotenv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / 'backend'

# Charger les variables d'environnement
load_dotenv(BACKEND / '.env')

POSTMAN_API_KEY = os.getenv('POSTMAN_API_KEY')
if not POSTMAN_API_KEY:
    print("Erreur: POSTMAN_API_KEY introuvable dans le fichier .env")
    exit(1)

# Chemin vers la collection Postman
collection_path = ROOT / 'docs' / 'postman' / 'Naatal_Agro_Postman_Collection.json'

try:
    with open(collection_path, 'r', encoding='utf-8') as f:
        collection_data = json.load(f)
except FileNotFoundError:
    print(f"Erreur: Fichier {collection_path} introuvable.")
    exit(1)

POSTMAN_WORKSPACE_ID = os.getenv('POSTMAN_WORKSPACE_ID')
if not POSTMAN_WORKSPACE_ID:
    print("Erreur: POSTMAN_WORKSPACE_ID introuvable dans backend/.env (voir list_postman_workspaces.py)")
    exit(1)

# Préparer le payload
payload = json.dumps({
    "collection": collection_data
}).encode('utf-8')

# Envoyer la requête à l'API Postman dans le workspace choisi
url = 'https://api.getpostman.com/collections?workspace=' + POSTMAN_WORKSPACE_ID
req = urllib.request.Request(url, data=payload, method='POST')
req.add_header('X-Api-Key', POSTMAN_API_KEY)
req.add_header('Content-Type', 'application/json')

try:
    with urllib.request.urlopen(req) as response:
        result = json.loads(response.read().decode('utf-8'))
        print("✅ Collection envoyée avec succès sur Postman !")
        print("ID de la collection:", result.get('collection', {}).get('uid'))
except urllib.error.HTTPError as e:
    error_msg = e.read().decode('utf-8')
    print(f"❌ Erreur HTTP {e.code}: {error_msg}")
except Exception as e:
    print(f"❌ Erreur: {e}")
