import json
import re
import requests
from django.conf import settings
from django.db import connection

SCHEMA_CONTEXT = """
Schéma autorisé de la base de données Naatal Agro :
- Table agriculture_crop(id, user_id, name, crop_type, planting_date, expected_harvest_date, status, area_size, location)
- Table agriculture_activity(id, crop_id, activity_type, description, date, cost)
- Table markets_product(id, name, category, current_price, trend_percentage, is_trending)
- Table markets_market(id, name, region)
- Table markets_price(id, market_id, product_name, price, trend, date)
- Table weather_weatherdata(id, location, temperature, humidity, rainfall, forecast_date)
- Table inventory_stockitem(id, user_id, name, quantity, unit, alert_status)

RÈGLES STRICTES D'ANTI-HALLUCINATION & DE SÉCURITÉ :
1. Tu es le Moteur IA Décisionnel de Naatal Agro.
2. Tu ne dois JAMAIS inventer de chiffres, prix ou données agricoles.
3. Si la question nécessite des données factuelles de la base, génère UNIQUEMENT un bloc JSON contenant une requête SQL SELECT restreinte :
```json
{"sql": "SELECT ... FROM ... LIMIT 10"}
```
4. SÉCURITÉ : N'accède JAMAIS aux tables d'utilisateurs ou de mots de passe. N'utilise que les tables autorisées listées ci-dessus.
5. Si la question est d'ordre général (conseil cultural, diagnostic), réponds directement en texte clair et bienveillant sans SQL.
"""

ALLOWED_TABLES = {
    'agriculture_crop',
    'agriculture_activity',
    'markets_product',
    'markets_market',
    'markets_price',
    'weather_weatherdata',
    'inventory_stockitem',
}

FORBIDDEN_KEYWORDS = [
    'insert', 'update', 'delete', 'drop', 'truncate', 'alter',
    'create', 'grant', 'revoke', 'copy', 'into', 'users_user',
    'django_session', 'django_admin', 'auth_group', 'auth_permission'
]

def execute_read_only_sql(sql_query, user=None):
    """
    Exécute de manière sécurisée une requête SELECT en lecture seule.
    Vérifie les tables autorisées et prévient l'injection SQL.
    """
    sql = sql_query.strip()
    sql_lower = sql.lower()

    if not sql_lower.startswith("select"):
        raise ValueError("Seules les requêtes SELECT en lecture seule sont permises.")

    if ";" in sql:
        sql = sql.split(";")[0].strip()

    # Vérification des mots-clés interdits
    for forbidden in FORBIDDEN_KEYWORDS:
        pattern = rf'\b{re.escape(forbidden)}\b'
        if re.search(pattern, sql_lower):
            raise PermissionError(f"Opération ou table interdite détectée : {forbidden}")

    # Vérification des tables interrogées (FROM et JOIN)
    tables_found = re.findall(r'\b(?:from|join)\s+([a-zA-Z0-9_]+)', sql_lower)
    for table in tables_found:
        if table not in ALLOWED_TABLES:
            raise PermissionError(f"Accès refusé à la table non autorisée : {table}")

    # Ajout d'une limite par défaut si non spécifiée pour éviter tout DoS
    if 'limit' not in sql_lower:
        sql += " LIMIT 25"

    with connection.cursor() as cursor:
        cursor.execute(sql)
        columns = [col[0] for col in cursor.description]
        rows = cursor.fetchall()
        
    results = []
    for row in rows:
        results.append(dict(zip(columns, row)))
    return results

def call_groq(prompt):
    groq_key = getattr(settings, 'GROQ_API_KEY', None)
    if not groq_key:
        return None
    url = "https://api.groq.com/openai/v1/chat/completions"
    headers = {"Authorization": f"Bearer {groq_key}"}
    payload = {
        "model": "llama-3.1-8b-instant",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1
    }
    try:
        res = requests.post(url, json=payload, headers=headers, timeout=10)
        if res.status_code == 200:
            return res.json()['choices'][0]['message']['content']
    except Exception as e:
        print(f"[Groq Service] Erreur d'appel API : {e}")
    return None

def call_gemini(prompt, image_base64=None):
    gemini_key = getattr(settings, 'GEMINI_API_KEY', None)
    if not gemini_key:
        return None
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={gemini_key}"
    
    parts = [{"text": prompt}]
    if image_base64:
        parts.append({
            "inline_data": {
                "mime_type": "image/jpeg",
                "data": image_base64
            }
        })

    payload = {
        "contents": [{"parts": parts}]
    }
    try:
        res = requests.post(url, json=payload, timeout=12)
        if res.status_code == 200:
            return res.json()['candidates'][0]['content']['parts'][0]['text']
    except Exception as e:
        print(f"[Gemini Service] Erreur d'appel API : {e}")
    return None

def call_llm(prompt, image_base64=None):
    if image_base64:
        return call_gemini(prompt, image_base64=image_base64)

    res = call_groq(prompt)
    if res is None:
        res = call_gemini(prompt)
    return res

def extract_json_sql(text):
    match = re.search(r'```json\s*(\{.*?\})\s*```', text, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1)).get('sql')
        except Exception:
            pass
    
    try:
        start = text.find('{')
        end = text.rfind('}') + 1
        if start != -1 and end != 0:
            return json.loads(text[start:end]).get('sql')
    except Exception:
        pass
    return None

def ask_llm(query, context='general', image_base64=None, user=None):
    """
    Orchestrateur IA sécurisé de Naatal Agro.
    Gère le Text-to-SQL borné et le diagnostic phytosanitaire par vision.
    """
    if image_base64:
        vision_prompt = (
            f"Tu es l'agronome expert sénégalais de Naatal Agro. "
            f"Analyse cette image agricole. L'utilisateur demande : '{query}'. "
            f"Identifie avec précision la culture, le ravageur ou la maladie éventuelle, "
            f"et prescris un traitement clair et immédiatement disponible au Sénégal."
        )
        return call_llm(vision_prompt, image_base64=image_base64) or "Erreur lors de l'analyse visuelle de l'image."

    user_info = ""
    if user and user.is_authenticated:
        user_info = f"Utilisateur ID: '{user.id}', Région: '{user.location or 'Sénégal'}', Rôle: '{user.role}'."

    initial_prompt = (
        f"{SCHEMA_CONTEXT}\n\n"
        f"Profil exploitant : {user_info}\n"
        f"Contexte : {context}\n"
        f"Question : {query}"
    )
    
    first_response = call_llm(initial_prompt)
    if not first_response:
        return "L'assistant IA est temporairement indisponible ou non configuré avec les clés d'API nécessaires."

    sql_query = extract_json_sql(first_response)
    
    if sql_query:
        try:
            db_results = execute_read_only_sql(sql_query, user=user)
            analysis_prompt = (
                f"Tu es Naatal Agro. L'utilisateur a demandé : '{query}'.\n"
                f"Données réelles de la base : {db_results}.\n"
                f"Formule une recommandation concise, experte et directement actionnable "
                f"en te basant strictement sur ces données réelles."
            )
            final_response = call_llm(analysis_prompt)
            return final_response or "Erreur lors de l'analyse des résultats de la base de données."
        except Exception as e:
            print(f"[IA Décisionnelle] Erreur SQL contrôlée : {e}")
            return "Je n'ai pas pu récupérer de façon sécurisée les données nécessaires pour répondre."
    
    return first_response
