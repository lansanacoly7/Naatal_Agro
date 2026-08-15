import os
import django
import json

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings.base')
django.setup()

from rest_framework.test import APIClient
from django.contrib.auth import get_user_model

User = get_user_model()

def run_tests():
    print("=" * 60)
    print("[EXECUTION AUTOMATIQUE DE LA SUITE DE TESTS POSTMAN / API]")
    print("=" * 60)

    client = APIClient()

    # 1. Inscription (Register)
    print("\n[1/7] Test Auth Register...")
    User.objects.filter(username='+221779998877').delete()
    reg_response = client.post('/api/users/auth/register/', {
        'phone_number': '+221779998877',
        'password': 'password123',
        'full_name': 'Amadou Diallo'
    }, format='json')
    print(f"   -> Status Code: {reg_response.status_code}")
    assert reg_response.status_code == 201, f"Échec register: {reg_response.content}"
    print("   [OK] Register OK")


    # 2. Connexion (Login JWT)
    print("\n[2/7] Test Auth Login...")
    login_response = client.post('/api/users/auth/login/', {
        'phone_number': '+221770000000',
        'password': 'password123'
    }, format='json')
    print(f"   -> Status Code: {login_response.status_code}")
    assert login_response.status_code == 200, f"Échec login: {login_response.content}"
    tokens = login_response.json()
    access_token = tokens['access']
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {access_token}')
    print("   [OK] Login JWT OK - Jeton recupere")

    # 3. Dashboard API
    print("\n[3/7] Test Dashboard API...")
    dash_response = client.get('/api/dashboard/')
    print(f"   -> Status Code: {dash_response.status_code}")
    assert dash_response.status_code == 200, f"Échec Dashboard: {dash_response.content}"
    print("   [OK] Dashboard API OK")

    # 4. Agriculture Crops API
    print("\n[4/7] Test Agriculture Crops List & Add...")
    crops_res = client.get('/api/agriculture/crops/')
    print(f"   -> Status Code (Crops List): {crops_res.status_code}")
    assert crops_res.status_code == 200
    
    crop_add_res = client.post('/api/agriculture/crops/', {
        'name': 'Champ de Mais Kaolack',
        'crop_type': 'Mais',
        'area_size': 3.5,
        'location': 'Kaolack',
        'planting_date': '2026-06-15',
        'expected_harvest_date': '2026-10-15',
        'status': 'active'
    }, format='json')
    print(f"   -> Status Code (Crop Add): {crop_add_res.status_code}")
    assert crop_add_res.status_code == 201
    print("   [OK] Agriculture API OK")

    # 5. Markets & Prices API
    print("\n[5/7] Test Markets & Prices API...")
    markets_res = client.get('/api/markets/')
    prices_res = client.get('/api/markets/prices/')

    print(f"   -> Status Code (Markets): {markets_res.status_code}")
    print(f"   -> Status Code (Prices): {prices_res.status_code}")
    assert markets_res.status_code == 200
    assert prices_res.status_code == 200
    print("   [OK] Markets & Prices API OK")

    # 6. Weather API
    print("\n[6/7] Test Weather API...")
    weather_res = client.get('/api/weather/?location=thies')
    print(f"   -> Status Code: {weather_res.status_code}")
    assert weather_res.status_code == 200
    print("   [OK] Weather API OK")

    # 7. Notifications API
    print("\n[7/7] Test Notifications API...")
    notif_res = client.get('/api/notifications/')
    print(f"   -> Status Code: {notif_res.status_code}")
    assert notif_res.status_code == 200
    print("   [OK] Notifications API OK")

    print("\n" + "=" * 60)
    print("TOUS LES TESTS DES API POSTMAN / BACKEND ONT REUSSI (100% SUCCES) !")
    print("=" * 60)


if __name__ == '__main__':
    run_tests()
