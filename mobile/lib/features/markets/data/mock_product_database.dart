import 'models/product_detail_model.dart';

class MockProductDatabase {
  static final List<ProductDetail> _products = [
    ProductDetail(
      id: 'oignon_local',
      name: 'Oignon Local',
      category: 'Légumes',
      currentPrice: 450.0,
      trendPercentage: 8.4,
      imageAsset: 'assets/images/products/oignon.png',
      rating: 4.5,
      description: "L'oignon local de la région des Niayes est réputé pour sa saveur robuste et sa conservation exceptionnelle. Il est très demandé sur les marchés locaux, surtout en période de fête.",
      recommendation: NaatalRecommendation(
        title: 'Fenêtre favorable à la vente',
        message: "Le prix de l'oignon est actuellement en hausse sur les marchés de Dakar. Si la tendance se maintient, le prix pourrait rester favorable dans les prochains jours. Il est conseillé de commencer l'écoulement des stocks matures.",
        isPositive: true,
      ),
    ),
    ProductDetail(
      id: 'mil',
      name: 'Mil',
      category: 'Céréales',
      currentPrice: 350.0,
      trendPercentage: -2.1,
      imageAsset: 'assets/images/products/mil.png',
      rating: 4.2,
      description: "Le mil est une céréale fondamentale dans l'alimentation sénégalaise. Cultivé principalement dans le bassin arachidier, il résiste très bien aux climats semi-arides.",
      recommendation: NaatalRecommendation(
        title: 'Baisse temporaire des prix',
        message: "Les prix du mil connaissent une légère baisse suite aux récentes récoltes massives dans le bassin arachidier. Il est recommandé de stocker votre récolte si vous disposez d'un silo sécurisé pour attendre une remontée des cours.",
        isPositive: false,
      ),
    ),
    ProductDetail(
      id: 'tomates',
      name: 'Tomates',
      category: 'Légumes',
      currentPrice: 600.0,
      trendPercentage: 12.5,
      imageAsset: 'assets/images/products/tomate.png',
      rating: 4.8,
      description: "La tomate de la vallée du fleuve Sénégal est prisée pour sa chair ferme et son utilisation dans de nombreux plats locaux comme le thiéboudienne.",
      recommendation: NaatalRecommendation(
        title: 'Forte demande du marché',
        message: "La demande en tomates fraîches explose dans les zones urbaines. Pensez à sécuriser rapidement le transport réfrigéré pour éviter les pertes post-récoltes et profiter de ces marges élevées.",
        isPositive: true,
      ),
    ),
    ProductDetail(
      id: 'arachide',
      name: 'Arachide',
      category: 'Légumineuses',
      currentPrice: 280.0,
      trendPercentage: 1.5,
      imageAsset: 'assets/images/products/arachide.png',
      rating: 4.7,
      description: "L'arachide reste la principale culture de rente du Sénégal. Idéale pour la transformation en huile ou la vente en coque sur les marchés locaux et internationaux.",
      recommendation: NaatalRecommendation(
        title: 'Campagne de commercialisation',
        message: "La campagne officielle de commercialisation approche. Assurez-vous que vos arachides sont bien séchées (taux d'humidité < 8%) pour répondre aux normes des huiliers et obtenir le meilleur prix.",
        isPositive: true,
      ),
    ),
  ];

  static ProductDetail getProduct(String identifier, {String? fallbackImage, double? fallbackPrice}) {
    // We try to find by ID first, then by substring match
    final lowerId = identifier.toLowerCase().trim();
    return _products.firstWhere(
      (p) => p.id == lowerId || p.name.toLowerCase().contains(lowerId) || lowerId.contains(p.name.toLowerCase()),
      orElse: () => _generateGenericProduct(identifier, fallbackImage, fallbackPrice),
    );
  }

  static ProductDetail _generateGenericProduct(String name, String? fallbackImage, double? fallbackPrice) {
    return ProductDetail(
      id: name.toLowerCase().replaceAll(' ', '_'),
      name: name,
      category: 'Culture',
      currentPrice: fallbackPrice ?? 0.0,
      trendPercentage: 0.0,
      imageAsset: (fallbackImage != null && fallbackImage.isNotEmpty) ? fallbackImage : 'assets/images/placeholder.png', // Fallback to provided image
      rating: 4.0,
      description: "Cette culture est essentielle à la production agricole locale. Ses rendements dépendent fortement de la qualité des semences et du suivi des itinéraires techniques recommandés.",
      recommendation: NaatalRecommendation(
        title: 'Suivi régulier conseillé',
        message: "Surveillez les variations de prix sur les marchés environnants et assurez-vous d'avoir une stratégie de vente bien définie pour maximiser vos revenus.",
        isPositive: true,
      ),
    );
  }
}
