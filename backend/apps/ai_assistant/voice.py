import io
import logging
import requests
from django.conf import settings

logger = logging.getLogger(__name__)


def transcribe_audio_bytes(audio_bytes, filename="audio.m4a", content_type="audio/m4a"):
    """
    Transcrit un flux audio (voix du producteur) en texte via Groq Whisper (whisper-large-v3).
    Prend en charge le français, le wolof et les accents régionaux avec une latence < 1s.
    """
    groq_key = getattr(settings, 'GROQ_API_KEY', None)
    if not groq_key:
        logger.warning("[Voice Transcribe] GROQ_API_KEY absente.")
        return None

    url = "https://api.groq.com/openai/v1/audio/transcriptions"
    headers = {
        "Authorization": f"Bearer {groq_key}",
    }
    files = {
        'file': (filename, io.BytesIO(audio_bytes), content_type)
    }
    data = {
        'model': 'whisper-large-v3-turbo',
        'response_format': 'json',
        'temperature': 0.0,
    }

    try:
        response = requests.post(url, headers=headers, files=files, data=data, timeout=15)
        if response.status_code == 200:
            result = response.json()
            return result.get('text', '').strip()
        else:
            logger.error(f"[Voice Transcribe] Statut {response.status_code}: {response.text[:200]}")
            return None
    except Exception as e:
        logger.error(f"[Voice Transcribe] Exception: {e}")
        return None


def synthesize_speech_bytes(text, lang='fr'):
    """
    Génère un flux audio MP3 lisible (TTS) pour la restitution vocale aux agriculteurs.
    Prend en charge le français ('fr') et s'adapte aux textes agricoles.
    """
    if not text or not text.strip():
        return None
    try:
        from gtts import gTTS
        # Limiter à 2000 caractères et retirer les balises markdown pour un rendu vocal fluide
        import re
        clean_text = re.sub(r'[*_#`\[\]]', ' ', text)
        clean_text = re.sub(r'https?://\S+', '', clean_text)
        clean_text = re.sub(r'\s{2,}', ' ', clean_text).strip()[:2000]

        if not clean_text:
            return None

        effective_lang = 'fr' if lang not in ('fr', 'en') else lang
        tts = gTTS(text=clean_text, lang=effective_lang, slow=False)
        fp = io.BytesIO()
        tts.write_to_fp(fp)
        fp.seek(0)
        return fp.read()
    except Exception as e:
        logger.error(f"[Voice Synthesize] Exception: {e}")
        return None

