import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings.base')
django.setup()

from apps.ai_assistant.services import ask_llm

print("=== DEBUT TEST IA ===")
try:
    reponse = ask_llm("Quand faut-il planter les arachides au Sénégal ?", "agriculture_generale")
    print("\n[RÉPONSE DE L'IA] :")
    print(reponse)
except Exception as e:
    print("\n[ERREUR] :", e)
print("\n=== FIN TEST IA ===")
