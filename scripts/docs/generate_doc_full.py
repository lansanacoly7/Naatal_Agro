import os
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Pt

def add_heading(doc, text, level):
    h = doc.add_heading(text, level=level)
    return h

def generate_doc():
    doc = Document()

    # ==========================================
    # 1. PAGE DE GARDE
    # ==========================================
    inst_para = doc.add_paragraph()
    inst_run = inst_para.add_run("Institut Supérieur d'Enseignement Professionnel (ISEP)")
    inst_run.font.size = Pt(16)
    inst_run.bold = True
    inst_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    doc.add_paragraph("\n\n")

    proj_para = doc.add_paragraph()
    proj_run = proj_para.add_run("Rapport de Projet de Fin de Formation")
    proj_run.font.size = Pt(20)
    proj_run.bold = True
    proj_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    doc.add_paragraph("\n")

    title_para = doc.add_paragraph()
    title_run = title_para.add_run("NAATAL AGRO : Copilote Agricole Intelligent pour le Sénégal")
    title_run.font.size = Pt(24)
    title_run.bold = True
    title_para.alignment = WD_ALIGN_PARAGRAPH.CENTER
    doc.add_paragraph("\n\n\n\n\n\n")

    author_para = doc.add_paragraph()
    author_run = author_para.add_run("Réalisé par :\nLassana Coly")
    author_run.font.size = Pt(14)
    author_run.bold = True
    author_para.alignment = WD_ALIGN_PARAGRAPH.LEFT
    doc.add_page_break()

    # ==========================================
    # 2. TABLE DES MATIERES
    # ==========================================
    toc_title = doc.add_heading("Table des matières", level=1)
    toc_title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    
    toc_items = [
        "Introduction générale",
        "1. Contexte et justification du sujet",
        "2. Problématique",
        "3. Questions de recherche, générale et spécifiques",
        "4. Objectif général et objectifs subsidiaires",
        "5. Hypothèses de recherche",
        "6. Méthodologie retenue",
        "7. Annonce du plan",
        "",
        "CHAPITRE I : CADRE THÉORIQUE ET CONCEPTUEL",
        "Section 1 : Revue conceptuelle",
        "   Sous-section 1 : L'agriculture de précision et les solutions SaaS agricoles",
        "   Sous-section 2 : Le rôle de l'Intelligence Artificielle et des données météorologiques",
        "Section 2 : Revue de littérature et état de l'art (Solutions existantes au Sénégal)",
        "",
        "CHAPITRE II : CONTEXTE DE L'ÉTUDE",
        "Section 1 : Contexte général",
        "   Sous-section 1 : L'importance du secteur agricole dans l'économie sénégalaise",
        "   Sous-section 2 : Les défis majeurs : accès à l'information et aux marchés",
        "Section 2 : Contexte spécifique (Le projet Naatal Agro)",
        "   Sous-section 1 : Genèse et objectifs de la plateforme Naatal Agro",
        "   Sous-section 2 : Public cible (Agriculteurs, Coopératives) et leurs attentes",
        "",
        "CHAPITRE III : CADRE MÉTHODOLOGIQUE ET CONCEPTION",
        "Section 1 : Spécification et modélisation du système",
        "   Sous-section 1 : Spécification des besoins fonctionnels et non-fonctionnels",
        "   Sous-section 2 : Étude et choix des méthodes de modélisation",
        "   Sous-section 3 : Modélisation",
        "Section 2 : Implémentation et évaluation des modèles",
        "   Sous-section 1 : Choix technologiques et justification",
        "   Sous-section 2 : Description de l'expérimentation"
    ]
    
    for item in toc_items:

        if item == "":
            doc.add_paragraph()
        elif item.startswith("CHAPITRE"):
            p = doc.add_paragraph()
            p.add_run(item).bold = True
        else:
            doc.add_paragraph(item)

    doc.add_page_break()


    # ==========================================
    # 3. REDACTION DU CONTENU (EXHAUSTIF ET ACADÉMIQUE)
    # ==========================================

    # --- INTRODUCTION GENERALE ---
    doc.add_heading("Introduction générale", level=1)

    
    doc.add_heading("1. Contexte et justification du sujet", level=2)
    doc.add_paragraph("L'agriculture sénégalaise constitue le véritable poumon socio-économique de la nation. Elle emploie plus de 55% de la population active et contribue à hauteur d'environ 15% au Produit Intérieur Brut (PIB) national. Cependant, ce secteur vital se heurte à des vulnérabilités structurelles profondes et croissantes. D'un côté, le dérèglement climatique mondial se manifeste localement par une variabilité pluviométrique extrême, le retard ou l'arrêt précoce des hivernages, des épisodes de sécheresse prolongés et la salinisation progressive des terres arables. D'un autre côté, la chaîne de valeur agricole souffre d'un sous-équipement numérique critique.")
    doc.add_paragraph("À l'ère de la transformation digitale, alors que le taux de pénétration des smartphones au Sénégal dépasse 75% et que l'Internet mobile se généralise, la grande majorité des petits exploitants agricoles continuent d'utiliser des méthodes de gestion traditionnelles et empiriques. L'absence d'outils technologiques adaptés et accessibles crée une importante asymétrie d'information. Les agriculteurs manquent de données fiables sur les prévisions météorologiques hyper-locales, le diagnostic précoce des maladies des plantes, la gestion optimale des intrants et, par-dessus tout, la transparence des cours sur les marchés régionaux (Dakar, Thiès, Kaolack, Saint-Louis).")
    doc.add_paragraph("Ce projet de fin de formation se justifie ainsi par l'urgence d'apporter une réponse technologique souveraine, moderne et inclusive. Il s'agit de développer 'Naatal Agro', une plateforme SaaS (Software as a Service) et mobile d'aide à la décision qui démocratise l'agriculture de précision et remet la donnée au cœur des décisions quotidiennes des producteurs ruraux.")

    doc.add_heading("2. Problématique", level=2)
    doc.add_paragraph("Le fossé grandissant entre les avancées technologiques globales et les pratiques agricoles locales crée un déficit majeur de productivité et de rentabilité. Actuellement, un agriculteur sénégalais est contraint de naviguer entre des sources d'informations éparses, souvent informelles ou incomplètes. Il ignore fréquemment le prix réel d'une tonne d'oignon ou de tomate au marché Castors au moment de négocier avec les intermédiaires (communément appelés bana-banas). De plus, l'absence de carnets de champ numériques rend sa ferme 'invisible' aux yeux des institutions financières et des assurances, bloquant ainsi l'accès aux crédits de campagne.")
    doc.add_paragraph("Dès lors, la problématique centrale de ce travail de recherche s'énonce comme suit :")
    doc.add_paragraph("'Comment concevoir et déployer une plateforme numérique intelligente, modulaire et centralisée (Naatal Agro), combinant des données météorologiques en temps réel, le suivi des parcelles, la cotation des marchés et un moteur d'Intelligence Artificielle contextuel, afin de maximiser les rendements et les revenus des producteurs agricoles au Sénégal ?'")

    doc.add_heading("3. Questions de recherche, générale et spécifiques", level=2)
    doc.add_paragraph("Pour résoudre cette problématique, notre étude s'articule autour d'une question principale et de quatre questions spécifiques.")
    doc.add_paragraph("Question principale :")
    doc.add_paragraph("Dans quelle mesure l'intégration des technologies numériques modernes (SaaS, Mobile Flutter, Intelligence Artificielle générative) peut-elle transformer les pratiques agricoles traditionnelles et améliorer l'efficacité opérationnelle des exploitants sénégalais ?")
    doc.add_paragraph("Questions spécifiques :")
    doc.add_paragraph("1. Comment concevoir une interface mobile (UX/UI) inclusive, ergonomique et responsive qui garantit l'adoption rapide par des agriculteurs ayant des niveaux d'alphabétisation variés ?", style='List Bullet')
    doc.add_paragraph("2. De quelle manière un moteur d'IA (Groq / Gemini) peut-il être paramétré et conditionné pour fournir des conseils agronomiques précis, courts et directement actionnables en contexte sahélien ?", style='List Bullet')
    doc.add_paragraph("3. Quelle architecture logicielle (Django REST Framework + Clean Architecture Flutter) permet d'assurer une scalabilité élevée, la sécurité des données (JWT, HTTPS) et une haute disponibilité du système ?", style='List Bullet')
    doc.add_paragraph("4. Comment structurer le modèle de données relationnel pour assurer la traçabilité complète des cultures, des activités agricoles et l'évolution historique des prix sur les marchés ?", style='List Bullet')

    doc.add_heading("4. Objectif général et objectifs subsidiaires", level=2)
    doc.add_paragraph("L'objectif général de ce projet de fin de formation est de concevoir, implémenter et valider la plateforme intelligente 'Naatal Agro', agissant comme un copilote numérique complet pour l'agriculture sénégalaise.")
    doc.add_paragraph("Les objectifs subsidiaires sont formulés comme suit :")
    doc.add_paragraph("- Réaliser une analyse approfondie des besoins fonctionnels et non-fonctionnels des acteurs de la filière agricole au Sénégal.", style='List Bullet')
    doc.add_paragraph("- Développer une application mobile cross-platform (Android/iOS) en Flutter offrant un dashboard dynamique, la géolocalisation des marchés et un chat IA interactif.", style='List Bullet')
    doc.add_paragraph("- Construire une API backend RESTful robuste sous Django, dotée d'une authentification sécurisée par numéro de téléphone et de services de notifications push Firebase (FCM).", style='List Bullet')
    doc.add_paragraph("- Modéliser et alimenter une base de données PostgreSQL/SQLite normalisée avec des enregistrements réels couvrant plusieurs régions clés du Sénégal.", style='List Bullet')
    doc.add_paragraph("- Développer une interface Web React pour l'administration, le suivi analytique et la gestion macroscopique des marchés par les coopératives.", style='List Bullet')

    doc.add_heading("5. Hypothèses de recherche", level=2)
    doc.add_paragraph("Dans le cadre de ce travail, nous émettons les trois hypothèses suivantes :")
    doc.add_paragraph("Hypothèse H1 : La mise à disposition d'un tableau de bord centralisant la météo hyper-locale et les alertes de précipitations réduit de plus de 20% les pertes de récoltes liées aux aléas climatiques imprévus.")
    doc.add_paragraph("Hypothèse H2 : L'accès direct aux cotations en temps réel des grands marchés régionaux permet aux agriculteurs d'accroître leurs marges bénéficiaires en négociant d'égal à égal avec les commerçants.")
    doc.add_paragraph("Hypothèse H3 : L'utilisation d'une architecture Headless découplée (DRF + Flutter + React) garantit la pérennité, la maintenabilité et la capacité de montée en charge de la solution.")

    doc.add_heading("6. Méthodologie retenue", level=2)
    doc.add_paragraph("La conduite de ce projet repose sur la méthodologie Agile Scrum, favorisant des itérations courtes et des livraisons fréquentes. Les développements ont été découpés en plusieurs Sprints :")
    doc.add_paragraph("- Sprint 1 : Conception, architecture et modélisation de la base de données.", style='List Bullet')
    doc.add_paragraph("- Sprint 2 : Développement du backend Django REST Framework et de l'authentification JWT.", style='List Bullet')
    doc.add_paragraph("- Sprint 3 : Développement de l'application mobile Flutter et intégration des modules météo, marché et agriculture.", style='List Bullet')
    doc.add_paragraph("- Sprint 4 : Intégration de l'Intelligence Artificielle (Naatal IA), des notifications push Firebase et de l'interface Web React.", style='List Bullet')
    doc.add_paragraph("Sur le plan logiciel, l'application suit scrupuleusement les principes de la Clean Architecture (couches Data, Domain, Presentation) et de la modélisation DDD (Domain-Driven Design).")

    doc.add_heading("7. Annonce du plan", level=2)
    doc.add_paragraph("Ce rapport s'organise autour de quatre chapitres complémentaires :")
    doc.add_paragraph("- Le Chapitre I établit le cadre théorique et conceptuel de l'étude (Agriculture de précision, SaaS, IA, état de l'art).", style='List Bullet')
    doc.add_paragraph("- Le Chapitre II présente le contexte général et spécifique de l'étude au Sénégal et introduit la solution Naatal Agro.", style='List Bullet')
    doc.add_paragraph("- Le Chapitre III traite du cadre méthodologique, de la modélisation du système (spécifications, diagrammes ERD, Clean Architecture) et des choix technologiques.", style='List Bullet')
    doc.add_paragraph("- Le Chapitre IV expose les résultats d'implémentation (Backend, Mobile, Web, IA, Postman), l'évaluation et les conclusions.", style='List Bullet')

    # --- CHAPITRE I ---
    doc.add_page_break()
    doc.add_heading("CHAPITRE I : CADRE THÉORIQUE ET CONCEPTUEL", level=1)
    
    doc.add_heading("Section 1 : Revue conceptuelle", level=2)
    doc.add_heading("Sous-section 1 : L'agriculture de précision et les solutions SaaS agricoles", level=3)
    doc.add_paragraph("L'agriculture de précision est un concept de gestion agronomique fondé sur l'observation, la mesure et la réponse aux variabilités temporelles et spatiales des cultures. Son principe fondamental s'énonce ainsi : 'apporter le bon traitement, au bon endroit, au bon moment et à la bonne dose'. historiquement réservée aux grandes exploitations des pays développés équipées de tracteurs guidés par GPS, l'agriculture de précision se démocratise aujourd'hui grâce au numérique mobile.")
    doc.add_paragraph("Dans ce paradigme, le modèle SaaS (Software as a Service) offre une flexibilité inégalée. Hébergé dans le Cloud, le SaaS agricole supprime tout besoin d'infrastructure informatique sur le terrain. L'agriculteur accède à ses services via une simple connexion mobile. Le SaaS permet la dématérialisation complète du suivi parcellaire, la traçabilité des intrants, le calcul automatisé du chiffre d'affaires prévisionnel et l'analyse continue des coûts de production.")
    
    doc.add_heading("Sous-section 2 : Le rôle de l'Intelligence Artificielle et des données météorologiques", level=3)
    doc.add_paragraph("L'Intelligence Artificielle (IA) appliquée à l'agriculture représente un saut de productivité majeur. Grâce aux modèles de langage avancés (LLM) et à l'analyse de données massives (Big Data), l'IA peut aujourd'hui agir comme un agronome virtuel personnel. Elle synthétise des variables complexes (température, taux d'humidité, type de sol, stade phénologique de la plante) pour fournir des recommandations décisionnelles instantanées.")
    doc.add_paragraph("La donnée météorologique constitue le carburant de cette intelligence. Au Sahel, où la majorité des cultures dépend de l'hivernage, la précision des prévisions météo à court et moyen terme est un facteur déterminant de survie économique. Coupler l'IA à des API météorologiques en temps réel permet d'anticiper les risques de stress hydrique, d'optimiser les calendriers de fertilisation et de protéger les récoltes contre les pluies violentes.")

    doc.add_heading("Section 2 : Revue de littérature et état de l'art", level=2)
    doc.add_paragraph("L'écosystème AgTech en Afrique de l'Ouest a connu une émergence progressive au cours de la dernière décennie. Au Sénégal, des pionniers comme mLouma ou JIKKO ont ouvert la voie en proposant des services de diffusion de prix par SMS ou USSD. Ces initiatives ont démontré l'intérêt manifeste des producteurs pour l'information commerciale.")
    doc.add_paragraph("Cependant, l'analyse comparative de l'état de l'art révèle trois limites majeures dans les solutions existantes :")
    doc.add_paragraph("1. Fragmentation des services : Les solutions actuelles fonctionnent en silos (un outil pour la météo, un autre pour les marchés, un troisième pour les conseils agronomiques).", style='List Bullet')
    doc.add_paragraph("2. Expérience Utilisateur obsolète : La dépendance aux SMS et interfaces USSD austères limite fortement l'interactivité, la visualisation cartographique et la richesse des analyses.", style='List Bullet')
    doc.add_paragraph("3. Absence d'intelligence contextuelle : Les conseils diffusés sont trop souvent génériques et non personnalisés à la parcelle spécifique de l'utilisateur.", style='List Bullet')
    doc.add_paragraph("Naatal Agro se positionne précisément pour combler cette triple lacune en offrant une plateforme unifiée, une UX mobile ultra-moderne et un assistant IA souverain et contextuel.")

    # --- CHAPITRE II ---
    doc.add_page_break()
    doc.add_heading("CHAPITRE II : CONTEXTE DE L'ÉTUDE", level=1)
    
    doc.add_heading("Section 1 : Contexte général", level=2)
    doc.add_heading("Sous-section 1 : L'importance du secteur agricole dans l'économie sénégalaise", level=3)
    doc.add_paragraph("Le Sénégal dispose d'un potentiel agronomique considérable réparti sur plusieurs zones éco-géographiques distinctes :")
    doc.add_paragraph("- La Vallée du Fleuve Sénégal : Zone d'excellence pour la riziculture irriguée et la culture de la canne à sucre.", style='List Bullet')
    doc.add_paragraph("- La Zone des Niayes : Bande côtière spécialisée dans le maraîchage intensif (tomate, oignon, pomme de terre, chou) alimentant les grands centres urbains.", style='List Bullet')
    doc.add_paragraph("- Le Bassin Arachidier : Cœur historique de la production d'arachide, de mil et de sorgho.", style='List Bullet')
    doc.add_paragraph("- La Casamance et le Sénégal Oriental : Zones à forte pluviométrie propices à l'arboriculture (mangue, anacarde), au maïs et à la sylviculture.", style='List Bullet')
    doc.add_paragraph("Malgré cette diversité, le secteur reste freiné par des contraintes matérielles, un accès limité aux intrants certifiés et une faible mécanisation.")
    
    doc.add_heading("Sous-section 2 : Les défis majeurs : accès à l'information et aux marchés", level=3)
    doc.add_paragraph("Le problème prépondérant auquel se heurtent les producteurs sénégalais réside dans la maîtrise de la chaîne commerciale. Lors des périodes de haute récolte (par exemple le pic de production de l'oignon ou de la tomate dans les Niayes), les marchés locaux se retrouvent fréquemment en sur-offre. Faute de connaître les prix pratiqués dans d'autres régions ou de pouvoir contacter directement des acheteurs grossistes, les producteurs sont contraints de vendre à perte aux intermédiaires pour éviter le pourrissement des denrées sur le champ.")
    doc.add_paragraph("Par ailleurs, la mémoire de l'exploitation agricole est rarement matérialisée. Sans registre numérique des dépenses (engrais, semences, main-d'œuvre) et des revenus, il est impossible pour un cultivateur de déterminer avec précision sa marge brute par hectare et d'optimiser ses futurs investissements.")

    doc.add_heading("Section 2 : Contexte spécifique (Le projet Naatal Agro)", level=2)
    doc.add_heading("Sous-section 1 : Genèse et objectifs de la plateforme Naatal Agro", level=3)
    doc.add_paragraph("Naatal Agro ('Naatal' signifiant 'rendre prospère / verdoyant' en Wolof) a été pensé comme une réponse globale à ces défis. L'ambition fondamentale du projet est de doter chaque agriculteur d'un véritable copilote numérique dans sa poche.")
    doc.add_paragraph("Les piliers fonctionnels de la plateforme comprennent :")
    doc.add_paragraph("- La Gestion des Exploitations & Cultures : Suivi en temps réel de chaque parcelle (surface, dates de semis, récolte estimée, état sanitaire).", style='List Bullet')
    doc.add_paragraph("- Le Hub Météo Agricole : Prévisions météorologiques précises et recommandations d'arrosage personnalisées.", style='List Bullet')
    doc.add_paragraph("- L'Observatoire des Prix des Marchés : Suivi dynamique et cartographique des cours des produits agricoles sur les marchés clés du pays.", style='List Bullet')
    doc.add_paragraph("- L'Assistant Virtuel 'Naatal IA' : Agent conversationnel spécialisé répondant 24/7 aux questions techniques des agriculteurs.", style='List Bullet')
    doc.add_paragraph("- Le Système d'Alertes et Notifications : Notifications en temps réel (Push Firebase) concernant les risques météo et les opportunités de marché.", style='List Bullet')
    
    doc.add_heading("Sous-section 2 : Public cible et attentes des utilisateurs", level=3)
    doc.add_paragraph("La plateforme Naatal Agro s'adresse à trois catégories d'acteurs :")
    doc.add_paragraph("1. Les petits et moyens producteurs individuels : Ils recherchent la simplicité d'utilisation, un gain direct de temps et d'argent, et un accès rapide aux prix des marchés.", style='List Bullet')
    doc.add_paragraph("2. Les coopératives et groupements d'intérêt économique (GIE) : Ils ont besoin d'une vue consolidée des volumes de production de leurs membres afin de négocier des contrats de vente groupés.", style='List Bullet')
    doc.add_paragraph("3. Les acheteurs et industriels de l'agroalimentaire : Ils recherchent la traçabilité des approvisionnements et la localisation géographique des gisements de récoltes.", style='List Bullet')

    # --- CHAPITRE III ---
    doc.add_page_break()
    doc.add_heading("CHAPITRE III : CADRE MÉTHODOLOGIQUE ET CONCEPTION", level=1)
    
    doc.add_heading("Section 1 : Spécification et modélisation du système", level=2)
    doc.add_heading("Sous-section 1 : Spécification des besoins fonctionnels et non-fonctionnels", level=3)
    doc.add_paragraph("L'analyse des besoins a permis de définir une matrice rigoureuse de spécifications :")
    doc.add_paragraph("Besoins fonctionnels :")
    doc.add_paragraph("- Auth : Connexion/Inscription sécurisée via le numéro de téléphone au format international (+221) et jeton JWT.", style='List Bullet')
    doc.add_paragraph("- Dashboard : Restitution visuelle et synthétique de la météo, des statistiques d'exploitation et des alertes.", style='List Bullet')
    doc.add_paragraph("- Agriculture : Gestion du cycle de vie des cultures (Tomate, Riz, Oignon, Arachide, Maïs) et journal des activités (irrigation, engrais).", style='List Bullet')
    doc.add_paragraph("- Marchés : Visualisation cartographique (OpenStreetMap) des marchés et comparaison des cours.", style='List Bullet')
    doc.add_paragraph("- Assistant IA : Interaction en langage naturel avec le modèle LLM spécialisé.", style='List Bullet')
    doc.add_paragraph("Besoins non-fonctionnels :")
    doc.add_paragraph("- Sécurité : Chiffrement SSL/TLS, hachage des mots de passe avec PBKDF2 et stockage sécurisé local sur mobile.", style='List Bullet')
    doc.add_paragraph("- Performance : Temps de réponse API inférieur à 200ms et réactivité de l'interface Flutter à 60 fps.", style='List Bullet')
    doc.add_paragraph("- Disponibilité : Taux de disponibilité cible du système supérieur à 99.5%.", style='List Bullet')

    doc.add_heading("Sous-section 2 : Modélisation et Architecture du système", level=3)
    doc.add_paragraph("Le système s'appuie sur une architecture Headless distribuée. Le backend Django REST Framework agit comme le serveur d'API centralisé, interconnecté à une base de données PostgreSQL relationnelle. Les clients (Application Mobile Flutter et Application Web React) consomment ces API de manière totalement autonome.")

    doc.add_heading("Sous-section 3 : Modèle Relationnel des Données (ERD)", level=3)
    doc.add_paragraph("La structure de la base de données comprend les entités clés suivantes : User, Crop, Activity, Market, Price, WeatherData, Notification, AIInteraction. Le modèle respecte la 3ème forme normale (3FN) pour garantir l'intégrité référentielle des données.")

    doc.add_heading("Section 2 : Choix technologiques et justification", level=2)
    doc.add_paragraph("La stack technique de Naatal Agro a été sélectionnée pour répondre aux critères de modernité, de robustesse et de maintenabilité :")
    doc.add_paragraph("- Backend : Python 3.13 + Django 5.1 + Django REST Framework + SimpleJWT.", style='List Bullet')
    doc.add_paragraph("- Mobile : Flutter 3.x + Dart + Riverpod + GoRouter + Dio + FlutterMap.", style='List Bullet')
    doc.add_paragraph("- Web Admin : React 18 + Vite + TypeScript + Axios.", style='List Bullet')
    doc.add_paragraph("- Base de données : PostgreSQL en production / SQLite en environnement de dev.", style='List Bullet')
    doc.add_paragraph("- IA & Cloud : Groq Llama-3.1 / Gemini API + Firebase Cloud Messaging.", style='List Bullet')

    # --- CHAPITRE IV ---
    doc.add_page_break()
    doc.add_heading("CHAPITRE IV : IMPLÉMENTATION, RÉSULTATS ET VALIDATION", level=1)

    doc.add_heading("Section 1 : Résultats d'implémentation", level=2)
    doc.add_paragraph("Le développement a abouti à un Produit Minimum Viable (MVP) totalement opérationnel comprenant :")
    doc.add_paragraph("1. Un backend Django déployé exposant des endpoints RESTful sécurisés pour tous les modules du système.", style='List Bullet')
    doc.add_paragraph("2. Une application mobile Flutter complète avec navigation fluide (GoRouter) et gestion d'état réactive (Riverpod).", style='List Bullet')
    doc.add_paragraph("3. Un assistant IA agronomique opérationnel fournissant des conseils personnalisés.", style='List Bullet')
    doc.add_paragraph("4. Une suite de tests automatisés Postman validant 100% des endpoints de l'API REST.", style='List Bullet')
    doc.add_paragraph("5. Une base de données alimentée avec des données de test réalistes couvrant la météo, les marchés et les cultures au Sénégal.", style='List Bullet')

    doc.add_heading("Section 2 : Conclusion générale et perspectives", level=2)
    doc.add_paragraph("Ce projet de fin de formation démontre avec succès la faisabilité et la grande valeur ajoutée de la digitalisation agricole au Sénégal. Naatal Agro prouve qu'en alliant une architecture logicielle moderne, une expérience utilisateur soignée et l'intelligence artificielle, il est possible d'autonomiser les agriculteurs et de transformer leurs pratiques quotidiennes.")
    doc.add_paragraph("Les perspectives d'évolution incluent le déploiement du mode hors-ligne avec synchronisation différée, l'intégration de capteurs IoT pour la mesure de l'humidité des sols et l'extension du service aux langues locales (assistant vocal en Wolof).")

    # Enregistrement du document final
    save_path = os.path.abspath('Rapport_Naatal_Agro_Final.docx')
    doc.save(save_path)
    print(f"[OK] Document Word academique genere avec succes : {save_path}")

if __name__ == '__main__':
    generate_doc()


