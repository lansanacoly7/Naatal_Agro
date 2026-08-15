import json
import re
import requests
from django.conf import settings
from django.db import connection

SCHEMA_CONTEXT = """
Schéma de la base de données (PostgreSQL) :
- Table agriculture_crop(id, user_id, name, crop_type, planting_date, expected_harvest_date, status, area_size, location)
- Table agriculture_activity(id, crop_id, activity_type, description, date, cost)
- Table markets_product(id, name, category, current_price, trend_percentage, is_trending)
- Table markets_market(id, name, region)
- Table markets_price(id, market_id, product_name, price, trend, date)
- Table weather_weatherdata(id, location, temperature, humidity, rainfall, forecast_date)

RÈGLES D'ANTI-HALLUCINATION :
Tu es le Moteur IA Décisionnel de Naatal Agro.
Tu ne dois JAMAIS inventer de données agricoles ou financières.
Si la question de l'utilisateur nécessite des données (prix, météo, cultures de l'utilisateur), réponds UNIQUEMENT avec un objet JSON contenant une requête SQL (SELECT uniquement) pour obtenir ces données.
Format exact attendu si du SQL est requis :
```json
{"sql": "SELECT ... FROM ... LIMIT 10"}
```

RÈGLE POUR LA RENTABILITÉ : 
Pour calculer une rentabilité, tu dois générer un SQL qui somme les coûts (cost) d'une culture dans la table agriculture_activity, et trouve le prix actuel (price) de cette même culture dans markets_price pour pouvoir faire la soustraction.

Si la question ne nécessite pas de base de données (ex: conseils généraux), réponds directement en texte.
"""

def execute_read_only_sql(sql_query):
    sql = sql_query.strip()
    if not sql.lower().startswith("select"):
        raise ValueError("Only SELECT queries are allowed for security reasons.")
    if ";" in sql:
        sql = sql.split(";")[0] # Prevent stacked queries

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
        "temperature": 0.1 # Low temp for deterministic SQL
    }
    try:
        res = requests.post(url, json=payload, headers=headers)
        if res.status_code == 200:
            return res.json()['choices'][0]['message']['content']
    except Exception as e:
        print("Groq Exception:", e)
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
        res = requests.post(url, json=payload)
        if res.status_code == 200:
            return res.json()['candidates'][0]['content']['parts'][0]['text']
    except Exception as e:
        print("Gemini Exception:", e)
    return None

def call_llm(prompt, image_base64=None):
    # If image is provided, we MUST use Gemini (Groq does not support multimodal here)
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
        except:
            pass
    
    try:
        start = text.find('{')
        end = text.rfind('}') + 1
        if start != -1 and end != 0:
            return json.loads(text[start:end]).get('sql')
    except:
        pass
    return None

def ask_llm(query, context, image_base64=None):
    """
    Orchestrateur IA. 
    Gère le Text-to-SQL (si besoin de BDD) et le Computer Vision (si image fournie).
    """
    if image_base64:
        vision_prompt = f"Tu es un agronome expert sénégalais. Analyse cette image agricole. L'utilisateur demande : '{query}'. Identifie la culture, la maladie ou le ravageur éventuel, et propose un traitement clair (naturel ou chimique) disponible au Sénégal."
        return call_llm(vision_prompt, image_base64=image_base64) or "Erreur lors de l'analyse visuelle de l'image."

    initial_prompt = f"{SCHEMA_CONTEXT}\n\nContexte de la requête: {context}\nQuestion de l'utilisateur : {query}"
    
    first_response = call_llm(initial_prompt)
    if not first_response:
        return "L'assistant IA n'est pas configuré ou est indisponible."

    sql_query = extract_json_sql(first_response)
    
    if sql_query:
        print(f"[IA Décisionnelle] SQL généré : {sql_query}")
        try:
            db_results = execute_read_only_sql(sql_query)
            
            analysis_prompt = f"Tu es Nataal Agro. L'utilisateur a demandé : '{query}'.\nVoici les données réelles issues de la base de données : {db_results}.\nFormule une réponse claire, experte et directe (parle de rentabilité financière si c'est le sujet) en te basant EXCLUSIVEMENT sur ces données. N'invente aucun chiffre."
            final_response = call_llm(analysis_prompt)
            return final_response or "Erreur lors de l'analyse des résultats de la base de données."
        except Exception as e:
            print(f"[IA Décisionnelle] Erreur SQL : {e}")
            return "Je n'ai pas pu récupérer les données nécessaires pour répondre de manière certaine."
    
    return first_response
