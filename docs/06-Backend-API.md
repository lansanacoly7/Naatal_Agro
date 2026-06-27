# Nataal Agro — Backend API Specification

| Informations | Valeur |
|--------------|---------|
| Projet | Nataal Agro |
| Document | Backend API |
| Version | 1.0 |
| Statut | En cours |
| Dépend de | 05-Database-Design.md |
| Objectif | Définir les endpoints API et règles backend |

---

# 1. Objectif du backend

Le backend de Nataal Agro doit :

- centraliser la logique métier
- sécuriser les données utilisateurs
- fournir des APIs pour Flutter et React
- intégrer IA, météo et marchés
- garantir scalabilité et performance

---

# 2. Architecture API

- Framework : Django REST Framework
- Format : JSON
- Authentification : JWT
- Communication : HTTPS

---

# 3. Base URL

```text id="api_base"
https://api.nataalagro.com/api/
4. Authentification
4.1 Register
POST /auth/register/
Body :
{
  "name": "string",
  "phone": "string",
  "password": "string"
}
4.2 Login
POST /auth/login/
Response :
{
  "access_token": "jwt",
  "refresh_token": "jwt"
}
4.3 Refresh Token
POST /auth/refresh/
5. Users API
Get profile
GET /users/me/
Authorization: Bearer <token>
Update profile
PUT /users/me/
6. Agriculture API (Produits)
Create crop
POST /agriculture/crops/
Body :
{
  "name": "tomate",
  "type": "maraichage",
  "planting_date": "2026-01-01",
  "area_size": 2,
  "location": "Thiès"
}
Get all crops
GET /agriculture/crops/
Get crop details
GET /agriculture/crops/{id}/
Add activity
POST /agriculture/crops/{id}/activities/
Body :
{
  "type": "arrosage",
  "description": "Arrosage du matin"
}
7. Markets API
Get markets
GET /markets/
Get prices
GET /markets/prices?product=tomate
Compare markets
GET /markets/compare?product=tomate
8. Weather API
Get weather
GET /weather/?location=Thiès
Forecast
GET /weather/forecast/
9. AI Assistant API
Ask AI
POST /ai/ask/
Body :
{
  "query": "Quand dois-je arroser mes tomates ?",
  "context": "agriculture"
}
Response :
{
  "answer": "Il est recommandé d’arroser tôt le matin pour éviter l’évaporation."
}
10. Notifications API
Get notifications
GET /notifications/
Mark as read
POST /notifications/{id}/read/
11. Dashboard API
Get dashboard summary
GET /dashboard/
Response :
{
  "weather": {},
  "markets": [],
  "alerts": [],
  "recommendations": []
}
12. Règles backend
12.1 Sécurité
JWT obligatoire
validation des inputs
permissions par utilisateur
12.2 Performance
pagination obligatoire
cache futur (Redis)
requêtes optimisées ORM
12.3 Architecture
séparation par modules Django
services indépendants
logique métier isolée
13. Gestion des erreurs
{
  "error": "description",
  "code": 400
}
14. Scalabilité

Le backend est conçu pour évoluer vers :

marketplace agricole
coopératives
IA avancée multi-agents
analyse satellite
IoT agricole
15. Conclusion

Le backend de Nataal Agro est conçu comme :

un système central intelligent capable de gérer données agricoles, IA, marchés et utilisateurs de manière sécurisée et scalable.


---

# 🧠 Ce que tu viens de verrouiller

✔ Base de données  
✔ Architecture système  
✔ UX/UI  
✔ API complète  

👉 Là tu as un **backend de niveau produit réel**

---

# 🚀 Prochaine étape

👉 `07-Mobile-Flutter.md`

Et là on va entrer dans :

- architecture Flutter réelle
- state management
- structure des dossiers
- navigation
- connexion API
- offline mode
- gestion des features