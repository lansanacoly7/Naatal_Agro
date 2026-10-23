"""
Voix : transcription de ce que dit le producteur (Groq Whisper).

La lecture à voix haute des réponses est faite SUR L'APPAREIL (moteur de synthèse vocale du téléphone, voir le service
mobile) : aucun texte n'est envoyé à un serveur pour être lu, et la lecture fonctionne hors connexion.

Limites connues, à ne pas masquer :
- Whisper ne prend pas officiellement en charge le wolof. Un énoncé en wolof peut être transcrit n'importe comment ;
  seuls le français (y compris avec des mots wolof courants) et les chiffres sont fiables ;
- la transcription n'est jamais exécutée comme une commande : le texte repart dans le circuit normal de l'assistant
  (propositions d'actions confirmées par l'utilisateur).
"""
import io
import logging

import requests
from django.conf import settings

logger = logging.getLogger(__name__)

MAX_AUDIO_BYTES = 15_000_000
MIN_AUDIO_BYTES = 1_500  # en dessous, aucun mot n'a pu être prononcé (déclenchement involontaire du micro)
TRANSCRIPTION_TIMEOUT = 15

# Vocabulaire du métier : oriente le modèle vers « mil », « niébé », « FCFA »… plutôt que des mots proches
VOCABULARY_HINT = "Naatal Agro : mil, arachide, niébé, oignon, tomate, piment, sacs, kilos, FCFA, engrais, récolte, stock."

# Phrases que Whisper invente sur un enregistrement silencieux ou presque
_SILENCE_HALLUCINATIONS = (
    "sous-titres", "sous titres", "merci d'avoir regardé", "merci d avoir regarde", "abonnez-vous", "amara.org",
    "thanks for watching", "subtitles by",
)


def is_silence_hallucination(text):
    lowered = (text or '').lower()
    return any(marker in lowered for marker in _SILENCE_HALLUCINATIONS)


def sniff_audio_format(audio_bytes):
    """Nom de fichier et type réels d'un enregistrement, d'après ses premiers octets (``None`` si inconnu).

    Le navigateur (PWA) enregistre en WebM/Ogg, le téléphone en M4A : étiqueter tout en « .m4a » ferait refuser les
    enregistrements du navigateur par le service de transcription.
    """
    head = bytes(audio_bytes[:12])
    if head[:4] == b'\x1a\x45\xdf\xa3':
        return 'audio.webm', 'audio/webm'
    if head[:4] == b'OggS':
        return 'audio.ogg', 'audio/ogg'
    if head[:4] == b'RIFF' and head[8:12] == b'WAVE':
        return 'audio.wav', 'audio/wav'
    if head[:4] == b'fLaC':
        return 'audio.flac', 'audio/flac'
    if head[4:8] == b'ftyp':
        return 'audio.m4a', 'audio/mp4'
    if head[:3] == b'ID3' or head[:2] in (b'\xff\xfb', b'\xff\xf3', b'\xff\xf2'):
        return 'audio.mp3', 'audio/mpeg'
    return None


def transcribe_audio_bytes(audio_bytes, filename="audio.m4a", content_type="audio/m4a"):
    """Texte transcrit, ``''`` si rien d'audible, ou ``None`` si le service est indisponible."""
    groq_key = getattr(settings, 'GROQ_API_KEY', None)
    if not groq_key:
        logger.warning("[Voice Transcribe] GROQ_API_KEY absente.")
        return None

    try:
        response = requests.post(
            "https://api.groq.com/openai/v1/audio/transcriptions",
            headers={"Authorization": f"Bearer {groq_key}"},
            files={'file': (filename, io.BytesIO(audio_bytes), content_type)},
            data={'model': 'whisper-large-v3-turbo', 'response_format': 'json', 'temperature': 0.0,
                  'prompt': VOCABULARY_HINT},
            timeout=TRANSCRIPTION_TIMEOUT,
        )
    except requests.RequestException as exc:
        logger.error("[Voice Transcribe] Exception réseau : %s", type(exc).__name__)
        return None

    if response.status_code != 200:
        logger.error("[Voice Transcribe] Statut %s", response.status_code)  # jamais le corps : il peut citer l'audio
        return None
    try:
        text = (response.json().get('text') or '').strip()
    except ValueError:
        return None
    return '' if is_silence_hallucination(text) else text
