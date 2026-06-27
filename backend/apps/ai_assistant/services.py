import os
import requests
from django.conf import settings

def ask_llm(query, context):
    """
    Service to call Groq or Gemini API to get an agriculture-focused response.
    """
    groq_key = getattr(settings, 'GROQ_API_KEY', None)
    gemini_key = getattr(settings, 'GEMINI_API_KEY', None)

    prompt = f"Tu es Nataal Agro, un assistant IA pour les agriculteurs sénégalais. Sois clair, concis et focalisé sur l'agriculture.\nContexte: {context}\nQuestion: {query}"

    if groq_key:
        # Call Groq
        url = "https://api.groq.com/openai/v1/chat/completions"
        headers = {"Authorization": f"Bearer {groq_key}"}
        payload = {
            "model": "llama3-8b-8192",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.5
        }
        try:
            res = requests.post(url, json=payload, headers=headers)
            if res.status_code == 200:
                return res.json()['choices'][0]['message']['content']
        except Exception as e:
            print(e)

    elif gemini_key:
        # Call Gemini
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={gemini_key}"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}]
        }
        try:
            res = requests.post(url, json=payload)
            if res.status_code == 200:
                return res.json()['candidates'][0]['content']['parts'][0]['text']
        except Exception as e:
            print(e)

    return "L'assistant IA n'est pas configuré ou est temporairement indisponible."
