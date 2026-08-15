import os
import json
import urllib.request
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv('.env')

POSTMAN_API_KEY = os.getenv('POSTMAN_API_KEY')
if not POSTMAN_API_KEY:
    print("Erreur: POSTMAN_API_KEY introuvable dans le fichier .env")
    exit(1)

# Chemin vers la collection Postman
collection_path = '../Naatal_Agro_Postman_Collection.json'

try:
    with open(collection_path, 'r', encoding='utf-8') as f:
        collection_data = json.load(f)
except FileNotFoundError:
    print(f"Erreur: Fichier {collection_path} introuvable.")
    exit(1)

# Préparer le payload
payload = json.dumps({
    "collection": collection_data
}).encode('utf-8')

# Envoyer la requête à l'API Postman en spécifiant le Workspace (Goat Ussop's Workspace)
url = 'https://api.getpostman.com/collections?workspace=c2b7c4a2-6a9b-4151-88e2-ccee97c15406'
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
