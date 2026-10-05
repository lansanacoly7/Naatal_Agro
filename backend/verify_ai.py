#!/usr/bin/env python
"""
Script de diagnostic manuel pour tester l'assistant IA Naatal Agro.
Usage : python verify_ai.py
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings.local')
django.setup()

from apps.ai_assistant.services import ask_llm

def main():
    print("=== TEST MANUEL IA NAATAL AGRO ===")
    try:
        reponse = ask_llm("Quand faut-il planter les arachides au Sénégal ?", "agriculture_generale")
        print("\n[RÉPONSE DE L'IA] :")
        print(reponse)
    except Exception as e:
        print("\n[ERREUR] :", e)
    print("\n=== FIN TEST MANUEL ===")

if __name__ == '__main__':
    main()
