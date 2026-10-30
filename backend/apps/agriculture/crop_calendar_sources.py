"""
Sources du calendrier agricole et zones agro-écologiques du Sénégal.

Règle du projet : chaque date du calendrier vient d'une source citée ici. Une culture sans source n'apparaît pas
avec des dates inventées : elle est signalée « non documentée ».
"""

SOURCES = {
    'fao': {
        'title': 'FAO Crop Calendar — Sénégal',
        'publisher': 'FAO (Organisation des Nations Unies pour l\'alimentation et l\'agriculture)',
        'year': 2021,
        'updated': '2021-02-26',
        'url': 'https://cropcalendar.apps.fao.org/#/home?id=SN',
        'note': 'Dates de semis et de récolte par zone agro-écologique. Données FAO, usage non commercial, source à citer.',
    },
    'cirad_mangue': {
        'title': 'Le système sociotechnique associé à la mangue au Sénégal : pré-diagnostic',
        'publisher': 'CIRAD',
        'year': 2017,
        'url': 'https://agritrop.cirad.fr/592209/1/Pre%CC%81diagnostic%20Mangue%20Se%CC%81ne%CC%81gal%20V4.pdf',
        'note': 'Récolte dans les Niayes : de mi-juin à début août, avec un pic en juillet.',
    },
    'isra_agrumes': {
        'title': 'La culture des agrumes au Sénégal (RADHORT)',
        'publisher': 'ISRA / FAO / Centre pour le développement de l\'horticulture (Bruno Telemans)',
        'year': 2012,
        'url': 'https://www.fao.org/3/az822f/az822f.pdf',
        'note': 'Lime de Tahiti : première production hâtive (septembre à novembre), deuxième tardive (mi-janvier à février).',
    },
    'isra_bilan_2005': {
        'title': 'Bilan de la recherche agricole et agroalimentaire au Sénégal',
        'publisher': 'ISRA',
        'year': 2005,
        'url': '',
        'note': 'Semis possible toute l\'année (gombo, piment), d\'après la fiche technique correspondante de l\'application.',
    },
}

# Zones agro-écologiques (découpage de la FAO) et régions administratives qui s'y trouvent
ZONES = [
    {
        'code': 'niayes', 'fao_id': '001', 'name': 'Niayes',
        'description': 'Région de Dakar et côte atlantique de Thiès, Louga et Saint-Louis : maraîchage.',
    },
    {
        'code': 'vallee', 'fao_id': '002', 'name': 'Vallée du fleuve',
        'description': 'Extrême nord de Dagana, Podor, Matam et Bakel : riz et cultures irriguées.',
    },
    {
        'code': 'sylvopastorale', 'fao_id': '003', 'name': 'Zone sylvo-pastorale',
        'description': 'Sud de Dagana et Podor, moitié sud de Matam et Bakel, est de Louga, Linguère et Ranérou.',
    },
    {
        'code': 'bassin', 'fao_id': '004', 'name': 'Bassin arachidier',
        'description': 'Fatick, Kaolack, Diourbel, Mbour et une grande partie de Thiès, Tivaouane, Kébémer et Louga.',
    },
    {
        'code': 'centre-est', 'fao_id': '005', 'name': 'Centre-Est et Sud-Est',
        'description': 'Région de Tambacounda et département de Bakel.',
    },
    {
        'code': 'casamance', 'fao_id': '006', 'name': 'Casamance',
        'description': 'Régions de Kolda et de Ziguinchor.',
    },
]

# Quelle(s) zone(s) pour chaque région : la première est proposée d'office, la personne peut changer
REGION_ZONES = {
    'Dakar': ['niayes'],
    'Thiès': ['bassin', 'niayes'],
    'Louga': ['sylvopastorale', 'niayes', 'bassin'],
    'Saint-Louis': ['vallee', 'niayes', 'sylvopastorale'],
    'Matam': ['vallee', 'sylvopastorale'],
    'Diourbel': ['bassin'],
    'Fatick': ['bassin'],
    'Kaolack': ['bassin'],
    'Kaffrine': ['bassin'],
    'Tambacounda': ['centre-est'],
    'Kédougou': ['centre-est'],
    'Kolda': ['casamance'],
    'Sédhiou': ['casamance'],
    'Ziguinchor': ['casamance'],
}

# Cultures de la liste FAO : clé interne, nom affiché, catégorie. L'orge et le poivre noir de la liste FAO ne sont pas
# repris : ils ne figurent pas dans notre catalogue de produits (et leurs dates « toute l'année » ne sont pas crédibles
# pour ces cultures au Sénégal).
FAO_CROPS = {
    '0265': ('mil', 'Mil', 'cereale'),
    '0325': ('sorgho', 'Sorgho', 'cereale'),
    '0113': ('mais', 'Maïs sucré', 'cereale'),
    '0303': ('riz', 'Riz', 'cereale'),
    '0145': ('fonio', 'Fonio', 'cereale'),
    '0076': ('manioc', 'Manioc', 'tubercule'),
    '0283': ('pomme-de-terre', 'Pomme de terre', 'tubercule'),
    '0341': ('patate-douce', 'Patate douce', 'tubercule'),
    '0117': ('niebe', 'Niébé', 'legumineuse'),
    '0262': ('arachide', 'Arachide', 'legumineuse'),
    '0027': ('feve', 'Fève verte', 'legumineuse'),
    '0334': ('canne-a-sucre', 'Canne à sucre', 'industrielle'),
    '0318': ('sesame', 'Sésame', 'industrielle'),
    '0114': ('coton', 'Coton', 'industrielle'),
    '0062': ('chou', 'Chou', 'legume'),
    '0073': ('carotte', 'Carotte', 'legume'),
    '0119': ('concombre', 'Concombre', 'legume'),
    '0132': ('aubergine', 'Aubergine', 'legume'),
    '0202': ('salade', 'Laitue (salade)', 'legume'),
    '0219': ('melon', 'Melon', 'legume'),
    '0247': ('oignon', 'Oignon', 'legume'),
    '0285': ('citrouille', 'Citrouille', 'legume'),
    '0356': ('tomate', 'Tomate', 'legume'),
    '0361': ('navet', 'Navet', 'legume'),
    '0306': ('bissap', 'Bissap (oseille de Guinée)', 'legume'),
    '0370': ('pasteque', 'Pastèque', 'fruit'),
    '0023': ('banane', 'Banane', 'fruit'),
}

# Cultures absentes de la FAO mais documentées par une source citée ci-dessus
SUPPLEMENT = [
    {
        'crop_key': 'mangue', 'crop_name': 'Mangue', 'category': 'fruit', 'zone': 'niayes', 'label': '',
        'harvest': (6, 15, 8, 10), 'period_text': 'De mi-juin à début août, avec un pic en juillet',
        'notes': 'Arbre fruitier : pas de semis. La récolte se fait en 3 ou 4 passages, à mesure que les fruits mûrissent.',
        'source_key': 'cirad_mangue',
    },
    {
        'crop_key': 'lime', 'crop_name': 'Lime de Tahiti', 'category': 'fruit', 'zone': 'all', 'label': 'Première production (hâtive)',
        'harvest': (9, 1, 11, 30), 'period_text': 'De septembre à novembre',
        'notes': 'Arbre fruitier : pas de semis.', 'source_key': 'isra_agrumes',
    },
    {
        'crop_key': 'lime', 'crop_name': 'Lime de Tahiti', 'category': 'fruit', 'zone': 'all', 'label': 'Deuxième production (tardive)',
        'harvest': (1, 15, 2, 28), 'period_text': 'De mi-janvier à février',
        'notes': 'Arbre fruitier : pas de semis.', 'source_key': 'isra_agrumes',
    },
    {
        'crop_key': 'gombo', 'crop_name': 'Gombo', 'category': 'legume', 'zone': 'all', 'label': '', 'all_year': True,
        'period_text': 'Semis toute l\'année',
        'notes': 'La culture est sensible au froid : sous 20 °C, son développement ralentit.', 'source_key': 'isra_bilan_2005',
    },
    {
        'crop_key': 'piment', 'crop_name': 'Piment', 'category': 'legume', 'zone': 'all', 'label': '', 'all_year': True,
        'period_text': 'Semis toute l\'année',
        'notes': 'Les meilleurs rendements sont obtenus en hivernage, car le froid ralentit la plante.', 'source_key': 'isra_bilan_2005',
    },
]

# Cultures du catalogue pour lesquelles on n'a pas (encore) de source : montrées comme « non documentées »
UNDOCUMENTED = ['Orange', 'Pamplemousse', 'Citron', 'Mandarine', 'Papaye', 'Ananas', 'Goyave', 'Poivron', 'Haricot vert']
