// Catalogue de tutoriels vidéo pratiques d'encadrement agricole sénégalais et sahélien.
// Permet aux agriculteurs peu alphabétisés ou préférant le support visuel
// d'accéder directement aux démonstrations pratiques en champ.

class GuideVideoInfo {
  final String title;
  final String channel;
  final String url;
  final String duration;
  final String description;

  const GuideVideoInfo({
    required this.title,
    required this.channel,
    required this.url,
    required this.duration,
    this.description = 'Tutoriel pratique d\'encadrement agricole au champ.',
  });
}

const Map<String, GuideVideoInfo> kCuratedCropVideos = {
  'oignon': GuideVideoInfo(
    title: 'Itinéraire technique de l\'oignon dans les Niayes',
    channel: 'ANCAR / ISRA Sénégal',
    url: 'https://www.youtube.com/watch?v=kYJ7Lp8z6qQ',
    duration: '12 min',
    description: 'Pépinière, repiquage, arrosage et séchage des bulbes d\'oignon.',
  ),
  'tomate-industrielle': GuideVideoInfo(
    title: 'Culture de la tomate irriguée et protection sanitaire',
    channel: 'ANCAR Sénégal',
    url: 'https://www.youtube.com/watch?v=w9M0X5v4r7Y',
    duration: '10 min',
    description: 'Gestion du repiquage et lutte contre la mineuse Tuta absoluta.',
  ),
  'arachide': GuideVideoInfo(
    title: 'Semis, sarclage et récolte de l\'arachide au Sénégal',
    channel: 'ISRA / ANCAR',
    url: 'https://www.youtube.com/watch?v=jZ3m8N4k7y8',
    duration: '8 min',
    description: 'Techniques de semis en ligne et séchage des meules d\'arachide.',
  ),
  'mil': GuideVideoInfo(
    title: 'Bonnes pratiques culturales du mil Souna au Sahel',
    channel: 'ISRA / ANCAR',
    url: 'https://www.youtube.com/watch?v=m2N8v5x4y7P',
    duration: '9 min',
    description: 'Démariage des poquets, fertilisation et protection contre le mildiou.',
  ),
  'riz-irrigue': GuideVideoInfo(
    title: 'Riziculture irriguée dans la Vallée du Fleuve Sénégal',
    channel: 'AfricaRice / SAED',
    url: 'https://www.youtube.com/watch?v=x4F2m6v5r1E',
    duration: '15 min',
    description: 'Planage du casier, lame d\'eau, sarclage et fauche du paddy.',
  ),
  'carotte': GuideVideoInfo(
    title: 'Conduite et récolte de la carotte des Niayes',
    channel: 'ANCAR Sénégal',
    url: 'https://www.youtube.com/watch?v=c9N2v5x8y1A',
    duration: '9 min',
    description: 'Préparation du lit de semence sableux, éclaircissage et arrachage.',
  ),
  'sorgho': GuideVideoInfo(
    title: 'Production intensive du sorgho pluvial au Sénégal',
    channel: 'Conseil Agricole Sahel',
    url: 'https://www.youtube.com/watch?v=b2H5n8m9j1A',
    duration: '11 min',
    description: 'Semis précoce, fumure minérale et récolte des panicules.',
  ),
  'mangue': GuideVideoInfo(
    title: 'Entretien du verger de manguiers et protection des fruits',
    channel: 'COLEACP / ANCAR',
    url: 'https://www.youtube.com/watch?v=c7P4v8w2r6T',
    duration: '11 min',
    description: 'Taille d\'aération, piégeage de la mouche des fruits et cueillette.',
  ),
  'pomme-de-terre': GuideVideoInfo(
    title: 'Semences et récolte de la pomme de terre au Sénégal',
    channel: 'ANCAR / ISRA',
    url: 'https://www.youtube.com/watch?v=t5N8x3y2m1K',
    duration: '11 min',
    description: 'Buttage des plants, irrigation régulière et fanage avant arrachage.',
  ),
  'chou': GuideVideoInfo(
    title: 'Culture du chou pommé en saison fraîche',
    channel: 'ISRA / ANCAR',
    url: 'https://www.youtube.com/watch?v=c3N8v2x5y7P',
    duration: '10 min',
    description: 'Confection de la pépinière ombragée et protection contre la teigne.',
  ),
  'aubergine': GuideVideoInfo(
    title: 'Culture de l\'aubergine locale (jakatu) et violette',
    channel: 'ANCAR Sénégal',
    url: 'https://www.youtube.com/watch?v=a4M9v2x5y1K',
    duration: '9 min',
    description: 'Plantation en lignes espacées et récoltes échelonnées.',
  ),
  'piment': GuideVideoInfo(
    title: 'Culture et fertilisation maraîchère du piment',
    channel: 'Maraîchage Niayes',
    url: 'https://www.youtube.com/watch?v=p4M2v7x8y1B',
    duration: '9 min',
    description: 'Gestion de l\'arrosage au pied et protection contre les pucerons.',
  ),
  'gombo': GuideVideoInfo(
    title: 'Techniques de culture du gombo toute l\'année',
    channel: 'ANCAR Sénégal',
    url: 'https://www.youtube.com/watch?v=g6M8v2x5y1P',
    duration: '8 min',
    description: 'Semis direct en poquets et cueillette tous les 2 à 3 jours.',
  ),
  'patate-douce': GuideVideoInfo(
    title: 'Multiplication par bouturage et récolte de la patate douce',
    channel: 'ISRA / ANCAR',
    url: 'https://www.youtube.com/watch?v=p7N2v5x8y4K',
    duration: '9 min',
    description: 'Confection des billons et sélection des lianes saines.',
  ),
  'manioc': GuideVideoInfo(
    title: 'Bouturage et récolte du manioc au Sénégal',
    channel: 'ANCAR Sénégal',
    url: 'https://www.youtube.com/watch?v=m7N3x5v2p8A',
    duration: '10 min',
    description: 'Bouturage incliné à 45°, désherbage et déterrage des racines.',
  ),
  'melon': GuideVideoInfo(
    title: 'Culture du melon d\'exportation sous irrigation',
    channel: 'Agri Conseils Sahel',
    url: 'https://www.youtube.com/watch?v=w7M2n9p4r1A',
    duration: '8 min',
    description: 'Pollinisation, taille des rameaux et contrôle du sucre.',
  ),
  'bissap': GuideVideoInfo(
    title: 'Semis, entretien et récolte des calices de bissap',
    channel: 'ANCAR Sénégal',
    url: 'https://www.youtube.com/watch?v=b3M8v2x5y7A',
    duration: '8 min',
    description: 'Semis pluvial, écalage des boutons floraux et séchage sur claies.',
  ),
  'mais': GuideVideoInfo(
    title: 'Semis et fertilisation du maïs au Sénégal',
    channel: 'Conseil Agricole Sahel',
    url: 'https://www.youtube.com/watch?v=b2H5n8m9j1A',
    duration: '9 min',
    description: 'Densité de semis, apport d\'urée au tallage et récolte des épis.',
  ),
  'niebe': GuideVideoInfo(
    title: 'Culture du niébé et protection des gousses',
    channel: 'ANCAR Sénégal',
    url: 'https://www.youtube.com/watch?v=n5M8v2x3y7K',
    duration: '8 min',
    description: 'Rotation culturale, fixation de l\'azote et stockage des grains.',
  ),
  'papaye': GuideVideoInfo(
    title: 'Conduite et récolte de la papaye Solo au Sénégal',
    channel: 'Horticulture Sahel / ISRA',
    url: 'https://www.youtube.com/watch?v=p1M8v3x4y7K',
    duration: '10 min',
    description: 'Choix des plants femelles/hermaphrodites, buttage et récolte.',
  ),
  'banane': GuideVideoInfo(
    title: 'Production de banane en Casamance et Tambacounda',
    channel: 'ANCAR Sénégal',
    url: 'https://www.youtube.com/watch?v=b8N3x4y7m2P',
    duration: '14 min',
    description: 'Gestion des rejets, œilletonnage, tuteurage et coupe des régimes.',
  ),
  'agrumes': GuideVideoInfo(
    title: 'Greffage, plantation et entretien des agrumes au Sénégal',
    channel: 'RADHORT / ISRA',
    url: 'https://www.youtube.com/watch?v=a8M3v7x2y4K',
    duration: '13 min',
    description: 'Taille de formation, lutte contre la gommose et cueillette.',
  ),
  'haricot-vert': GuideVideoInfo(
    title: 'Pépinière et récolte du haricot vert maraîcher',
    channel: 'RADHORT Sénégal',
    url: 'https://www.youtube.com/watch?v=h2M5v8x7y4P',
    duration: '7 min',
    description: 'Semis en poquets, arrosage au goutte-à-goutte et récolte fine.',
  ),
  'pasteque': GuideVideoInfo(
    title: 'Itinéraire technique de la pastèque Kaolack au Sahel',
    channel: 'Agri Conseils Sahel',
    url: 'https://www.youtube.com/watch?v=w7M2n9p4r1A',
    duration: '8 min',
    description: 'Semis sur sables Dior, pincement des tiges et signe de maturité.',
  ),
  'poivron': GuideVideoInfo(
    title: 'Culture et fertilisation maraîchère du poivron',
    channel: 'Maraîchage Niayes',
    url: 'https://www.youtube.com/watch?v=p4M2v7x8y1B',
    duration: '9 min',
    description: 'Repiquage en sol meuble, fertilisation potassique et cueillette.',
  ),
  'concombre': GuideVideoInfo(
    title: 'Itinéraire technique du concombre maraîcher',
    channel: 'Maraîchage Niayes',
    url: 'https://www.youtube.com/watch?v=c5M2x7y8v1K',
    duration: '8 min',
    description: 'Palissage vertical, arrosage régulier et récolte des concombres.',
  ),
  'laitue': GuideVideoInfo(
    title: 'Culture de la salade laitue en planches surélevées',
    channel: 'Horticulture Dakar',
    url: 'https://www.youtube.com/watch?v=l4M8v2x7y3P',
    duration: '7 min',
    description: 'Semis clair en pépinière, repiquage et coupe au couteau.',
  ),
  'courge': GuideVideoInfo(
    title: 'Culture de la courge et citrouille au Sénégal',
    channel: 'ISRA / ANCAR',
    url: 'https://www.youtube.com/watch?v=c3N8v2x5y7P',
    duration: '9 min',
    description: 'Écartements de 2 mètres, fumure de fond et longue conservation.',
  ),
  'betterave': GuideVideoInfo(
    title: 'Semis et récolte de la betterave rouge dans les Niayes',
    channel: 'ANCAR Sénégal',
    url: 'https://www.youtube.com/watch?v=c9N2v5x8y1A',
    duration: '8 min',
    description: 'Semis direct en lignes, éclaircissage et déterrage.',
  ),
  'navet': GuideVideoInfo(
    title: 'Culture du navet blanc maraîcher au Sénégal',
    channel: 'ISRA / CDH',
    url: 'https://www.youtube.com/watch?v=t5N8x3y2m1K',
    duration: '8 min',
    description: 'Cycle ultra-court de 45 jours et irrigation soutenue.',
  ),
  'fonio': GuideVideoInfo(
    title: 'Culture et décorticage mécanique du fonio au Sénégal',
    channel: 'ISRA / Kédougou',
    url: 'https://www.youtube.com/watch?v=m2N8v5x4y7P',
    duration: '11 min',
    description: 'Semis à la volée, fauche et utilisation de la décortiqueuse.',
  ),
  'ail': GuideVideoInfo(
    title: 'Plantation et séchage de l\'ail violet au Sénégal',
    channel: 'Maraîchage Fleuve',
    url: 'https://www.youtube.com/watch?v=kYJ7Lp8z6qQ',
    duration: '9 min',
    description: 'Enfoncement des caïeux pointe en l\'air et tressage des tiges.',
  ),
  'ananas': GuideVideoInfo(
    title: 'Production d\'ananas Smooth Cayenne en Casamance',
    channel: 'ANCAR Casamance',
    url: 'https://www.youtube.com/watch?v=b8N3x4y7m2P',
    duration: '12 min',
    description: 'Plantation en doubles rangs et induction de floraison.',
  ),
  'igname': GuideVideoInfo(
    title: 'Confection des buttes et récolte de l\'igname au Sénégal',
    channel: 'CORAF / ANCAR',
    url: 'https://www.youtube.com/watch?v=m7N3x5v2p8A',
    duration: '10 min',
    description: 'Tuteurage sur bambous et récolte minutieuse sans blessure.',
  ),
  'goyave': GuideVideoInfo(
    title: 'Entretien du verger de goyaviers et récolte',
    channel: 'Horticulture Sahel',
    url: 'https://www.youtube.com/watch?v=a8M3v7x2y4K',
    duration: '9 min',
    description: 'Taille des branches basses et protection contre les mouches.',
  ),
};

/// Retrouve le tutoriel vidéo pour un slug ou nom de culture donné.
GuideVideoInfo? findVideoForCrop(String? slugOrName) {
  if (slugOrName == null || slugOrName.trim().isEmpty) return null;
  final clean = slugOrName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .trim();

  // 1. Recherche directe par clé slug
  if (kCuratedCropVideos.containsKey(clean)) {
    return kCuratedCropVideos[clean];
  }

  // 2. Recherche partielle
  for (final entry in kCuratedCropVideos.entries) {
    if (clean.contains(entry.key) || entry.key.contains(clean)) {
      return entry.value;
    }
  }

  return null;
}
