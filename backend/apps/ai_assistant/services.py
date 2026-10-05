import json
import logging
import requests
from django.conf import settings
from django.utils import timezone
import datetime

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """Tu es le copilote agronomique intelligent de Naatal Agro, la plateforme agricole de référence au Sénégal.
Ton rôle est d'apporter des conseils agronomiques précis, pratiques, contextualisés et immédiatement applicables par les producteurs sénégalais.

RÈGLES D'OR :
1. Réponds de façon concise, bienveillante et professionnelle en français (avec des termes locaux si pertinents, ex: Louma, Niayes, Casamance).
2. Base-toi en priorité sur les données réelles fournies dans le profil et les exploitations de l'utilisateur.
3. Ne divulgue jamais de données techniques internes ou d'informations d'autres exploitants.
4. Si une maladie ou un ravageur est détecté, propose des solutions de lutte intégrée (biologiques et conventionnelles homologuées au Sénégal).
"""

def get_farmer_context(user):
    """
    Extrait de manière strictement cloisonnée (ORM Django) le contexte
    agricole de l'utilisateur authentifié. Aucune fuite multi-tenant possible.
    """
    if not user or not user.is_authenticated:
        return {"auth": False, "note": "Utilisateur non connecté (mode invité)"}

    context = {
        "auth": True,
        "name": user.first_name or user.username,
        "role": getattr(user, 'role', 'farmer'),
        "location": getattr(user, 'location', 'Sénégal'),
        "main_crops": getattr(user, 'main_crops', []),
        "crops": [],
        "recent_activities": [],
        "market_prices": [],
        "local_pest_alerts": []
    }

    try:
        from apps.agriculture.models import Crop, Activity, PestReport
        from apps.markets.models import Product, Price

        # 1. Cultures personnelles exclusives de l'utilisateur connecté
        user_crops = Crop.objects.filter(user=user)[:10]
        for c in user_crops:
            context["crops"].append({
                "nom": c.name,
                "type": c.crop_type,
                "surface_ha": c.area_size,
                "statut": c.status,
                "semis": str(c.planting_date),
                "recolte_prevue": str(c.expected_harvest_date),
            })

        # 2. Activités récentes sur ses propres cultures
        user_activities = Activity.objects.filter(crop__user=user).order_by('-date')[:5]
        for a in user_activities:
            context["recent_activities"].append({
                "culture": a.crop.name,
                "type": a.activity_type,
                "description": a.description,
                "date": str(a.date)
            })

        # 3. Tendances des marchés (données publiques)
        trending_products = Product.objects.filter(is_trending=True)[:5]
        for p in trending_products:
            context["market_prices"].append({
                "produit": p.name,
                "categorie": p.category,
                "prix_kg": str(p.current_price),
                "tendance": f"{p.trend_percentage}%"
            })

        # 4. Alertes ravageurs dans la région de l'utilisateur (14 derniers jours)
        if user.location:
            region = user.location.split(',')[0].strip()
            recent_alerts = PestReport.objects.filter(
                location__icontains=region,
                date_reported__gte=timezone.now() - datetime.timedelta(days=14)
            )[:3]
            for alert in recent_alerts:
                context["local_pest_alerts"].append({
                    "ravageur": alert.pest_name,
                    "zone": alert.location,
                    "date": alert.date_reported.strftime("%Y-%m-%d")
                })
    except Exception as e:
        logger.error(f"[AI Context Extraction] Erreur d'extraction : {e}")

    return context

def call_groq(prompt):
    groq_key = getattr(settings, 'GROQ_API_KEY', None)
    if not groq_key:
        return None
    url = "https://api.groq.com/openai/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {groq_key}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": "llama-3.1-8b-instant",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.2,
        "max_tokens": 800
    }
    try:
        res = requests.post(url, json=payload, headers=headers, timeout=10)
        if res.status_code == 200:
            return res.json()['choices'][0]['message']['content']
        logger.warning(f"[Groq Service] Statut HTTP {res.status_code}: {res.text}")
    except Exception as e:
        logger.error(f"[Groq Service] Exception : {e}")
    return None

def call_gemini(prompt, image_base64=None):
    gemini_key = getattr(settings, 'GEMINI_API_KEY', None)
    if not gemini_key:
        return None
        
    url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    headers = {
        "x-goog-api-key": gemini_key,
        "Content-Type": "application/json"
    }
    
    parts = [{"text": f"{SYSTEM_PROMPT}\n\n{prompt}"}]
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
        res = requests.post(url, json=payload, headers=headers, timeout=12)
        if res.status_code == 200:
            return res.json()['candidates'][0]['content']['parts'][0]['text']
        logger.warning(f"[Gemini Service] Statut HTTP {res.status_code}: {res.text}")
    except Exception as e:
        logger.error(f"[Gemini Service] Exception : {e}")
    return None

def call_llm(prompt, image_base64=None):
    if image_base64:
        return call_gemini(prompt, image_base64=image_base64)
    # Tente Groq en priorité, bascule sur Gemini si indisponible
    res = call_groq(prompt)
    if not res:
        res = call_gemini(prompt)
    return res

def ask_llm(query, context='general', image_base64=None, user=None):
    """
    Point d'entrée du copilote IA décisionnel de Naatal Agro.
    - Diagnostic vision (analyse phytosanitaire d'une image)
    - Recommandation agronomique contextuelle sécurisée (zéro injection SQL, isolation stricte par ORM)
    """
    if image_base64:
        vision_prompt = (
            f"Analyse phytosanitaire de cette image agricole transmise par l'exploitant.\n"
            f"Question / Remarque : '{query}'.\n"
            f"1. Identifie la culture et la maladie ou le ravageur visible avec certitude.\n"
            f"2. Indique la sévérité et les symptômes caractéristiques.\n"
            f"3. Recommande un traitement curatif et préventif adapté au climat sénégalais."
        )
        response = call_llm(vision_prompt, image_base64=image_base64)
        return response or "Le service de vision IA est indisponible. Veuillez vérifier vos clés API."

    # Construction du contexte sécurisé avec requêtes ORM cloisonnées par utilisateur
    farmer_context = get_farmer_context(user)
    context_str = json.dumps(farmer_context, ensure_ascii=False, indent=2)

    prompt = (
        f"### DONNÉES CLOISONNÉES DE L'EXPLOITANT (Source certifiée Naatal Agro) :\n"
        f"```json\n{context_str}\n```\n\n"
        f"### CONTEXTE MÉTIER : {context}\n"
        f"### QUESTION DU PRODUCTEUR : {query}\n\n"
        f"Réponds de manière directe, concrète et utile pour l'exploitant :"
    )

    llm_response = call_llm(prompt)
    if not llm_response:
        return (
            "Naatal IA est temporairement indisponible (les clés API Gemini ou Groq ne sont pas configurées). "
            "Vos données agricoles personnelles restent parfaitement sécurisées et accessibles."
        )
    return llm_response
