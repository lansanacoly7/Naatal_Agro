import os
import json
import urllib.request
from dotenv import load_dotenv

load_dotenv('.env')

POSTMAN_API_KEY = os.getenv('POSTMAN_API_KEY')

url = 'https://api.getpostman.com/workspaces'
req = urllib.request.Request(url)
req.add_header('X-Api-Key', POSTMAN_API_KEY)

try:
    with urllib.request.urlopen(req) as response:
        workspaces_data = json.loads(response.read().decode('utf-8'))
        for ws in workspaces_data.get('workspaces', []):
            print(f"Workspace Name: {ws.get('name')} | ID: {ws.get('id')}")
except Exception as e:
    print(f"Erreur: {e}")
