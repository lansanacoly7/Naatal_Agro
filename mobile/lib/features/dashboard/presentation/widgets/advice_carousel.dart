import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../agriculture/data/models/crop.dart';
import '../../../finances/data/models/financial_summary.dart';
import '../../../inventory/data/models/stock_item.dart';
import '../../data/models/dashboard_data.dart';

const _imgField = 'assets/images/onboarding_agriculture_1784459495811.png';
const _imgMarket = 'assets/images/onboarding_market_1784459514097.png';
const _imgTech = 'assets/images/onboarding_tech_1784459505530.png';
const _imgPeanut = 'assets/images/arachide_recolte.jpg';
const _imgTomato = 'assets/images/tomates_recolte.jpg';
const _imgMil = 'assets/images/mil.jpg';
const _imgCrowd = 'assets/images/onboarding_2.png';
const _imgTablet = 'assets/images/onboarding_3.png';

String _dedicated(String key) => 'assets/images/conseils/$key.jpg';

/// Un conseil : s'ouvre sur la page concernée quand on appuie sur la carte.
class AdviceTip {
  const AdviceTip({
    required this.tag,
    required this.title,
    required this.text,
    required this.image,
    required this.fallback,
    required this.route,
    this.isTab = false,
  });

  final String tag;
  final String title;
  final String text;
  final String image;

  /// Photo existante affichée si l'image dédiée n'est pas encore dans l'application.
  final String fallback;
  final String route;

  /// Vrai si la page est un onglet (navigation `go`), faux si c'est un écran empilé (`push`).
  final bool isTab;
}

String _image(String cropName) {
  final n = cropName.toLowerCase();
  if (n.contains('arachide')) return _imgPeanut;
  if (n.contains('tomate')) return _imgTomato;
  if (n.contains('mil') || n.contains('maïs') || n.contains('mais')) return _imgMil;
  return _imgField;
}

String _fcfa(double v) => v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ' ');

/// Conseils construits à partir de l'activité de l'utilisateur (cultures, stock, ventes, prix, météo).
/// Chaque conseil ne paraît que si les données le justifient : deux utilisateurs n'ont pas les mêmes.
List<AdviceTip> buildAdvice({
  required List<Crop> crops,
  required List<StockItem> stock,
  required FinancialSummary? finances,
  required List<MarketPrice> prices,
  required WeatherSummary weather,
  required List<String> alerts,
}) {
  final tips = <AdviceTip>[];
  final now = DateTime.now();
  final active = crops.where((c) => c.status != 'harvested').toList();

  if (alerts.isNotEmpty) {
    tips.add(AdviceTip(tag: 'ALERTE', title: 'Avis agronomique', text: alerts.first, image: _dedicated('conseil_alerte'), fallback: _imgField, route: '/notifications'));
  }

  if (weather.isAvailable && weather.rainfall > 5) {
    tips.add(AdviceTip(
      tag: 'MÉTÉO',
      title: 'Pluie relevée : ${weather.rainfall.toStringAsFixed(1)} mm',
      text: 'Évitez les engrais solubles pour limiter le lessivage et surveillez le drainage.',
      image: _dedicated('conseil_pluie'),
      fallback: _imgField,
      route: '/weather',
    ));
  } else if (weather.isAvailable && weather.temp >= 33) {
    tips.add(AdviceTip(
      tag: 'IRRIGATION',
      title: 'Forte chaleur : ${weather.temp.toInt()}°C',
      text: 'Arrosez tôt le matin ou après 18 h pour préserver l\'eau du sol.',
      image: _dedicated('conseil_irrigation'),
      fallback: _imgField,
      route: '/weather',
    ));
  }

  // Récolte proche
  for (final c in active) {
    final d = c.daysToHarvest;
    if (d != null && d >= 0 && d <= 14) {
      tips.add(AdviceTip(
        tag: 'RÉCOLTE',
        title: d == 0 ? '${c.name} : récolte attendue aujourd\'hui' : '${c.name} : récolte dans $d jour${d > 1 ? 's' : ''}',
        text: 'Préparez sacs, matériel et un lieu de stockage sec et aéré.',
        image: _dedicated('conseil_recolte'),
        fallback: _image(c.cropType.isEmpty ? c.name : c.cropType),
        route: '/agriculture/${c.id}',
      ));
      break;
    }
  }

  // Semis : aucune culture suivie
  if (crops.isEmpty) {
    tips.add(AdviceTip(
      tag: 'SEMIS',
      title: 'Ajoutez votre première culture',
      text: 'Enregistrez ce que vous plantez : le calendrier et les conseils s\'adapteront à vous.',
      image: _dedicated('conseil_semis'),
      fallback: _imgField,
      route: '/agriculture/add',
    ));
  } else {
    // Bonnes pratiques : culture sans activité récente
    for (final c in active) {
      final planted = DateTime.tryParse(c.plantingDate);
      if (planted == null || now.difference(planted).inDays < 7) continue;
      final dates = c.activities.map((a) => DateTime.tryParse(a.date)).whereType<DateTime>().toList()..sort();
      final lastActivity = dates.isEmpty ? null : dates.last;
      final quiet = lastActivity == null || now.difference(lastActivity).inDays > 14;
      if (quiet) {
        tips.add(AdviceTip(
          tag: 'BONNES PRATIQUES',
          title: '${c.name} : aucune activité notée',
          text: 'Notez arrosage, engrais et traitements : c\'est la base pour mesurer vos coûts.',
          image: _dedicated('conseil_pratiques'),
          fallback: _image(c.cropType.isEmpty ? c.name : c.cropType),
          route: '/agriculture/${c.id}',
        ));
        break;
      }
    }
  }

  // Stock
  final low = stock.where((s) => s.alertStatus).toList();
  if (low.isNotEmpty) {
    final s = low.first;
    tips.add(AdviceTip(
      tag: 'STOCK',
      title: '${s.name} : stock bas',
      text: '${s.quantity.toStringAsFixed(s.quantity.truncateToDouble() == s.quantity ? 0 : 1)} ${s.unit} restants. Prévoyez la prochaine récolte ou un réapprovisionnement.',
      image: _dedicated('conseil_stock'),
      fallback: _image(s.name) == _imgField ? _imgTablet : _image(s.name),
      route: '/stock',
    ));
  } else if (stock.isNotEmpty) {
    MarketPrice? priced;
    for (final s in stock) {
      for (final p in prices) {
        if (p.productName.toLowerCase().contains(s.name.toLowerCase()) || s.name.toLowerCase().contains(p.productName.toLowerCase())) {
          priced = p;
          break;
        }
      }
      if (priced != null) break;
    }
    if (priced != null && priced.minPrice != null && priced.maxPrice != null && priced.maxPrice! > priced.minPrice!) {
      tips.add(AdviceTip(
        tag: 'STOCK',
        title: '${priced.productName} : ${_fcfa(priced.price)} F/kg en moyenne',
        text: 'Selon les marchés, l\'écart atteint ${_fcfa(priced.maxPrice! - priced.minPrice!)} F/kg. Comparez avant de vendre.',
        image: _dedicated('conseil_marche'),
        fallback: _imgMarket,
        route: '/markets',
        isTab: true,
      ));
    } else {
      tips.add(AdviceTip(
        tag: 'STOCK',
        title: '${stock.length} produit${stock.length > 1 ? 's' : ''} en stock',
        text: 'Gardez-les au sec et à l\'ombre, et contrôlez-les chaque semaine.',
        image: _dedicated('conseil_stock'),
        fallback: _image(stock.first.name) == _imgField ? _imgTablet : _image(stock.first.name),
        route: '/stock',
      ));
    }
  }

  // Marché : forte variation d'un prix de ses cultures
  for (final p in prices) {
    final ch = p.changePercent;
    if (ch != null && ch.abs() >= 3) {
      final up = ch > 0;
      tips.add(AdviceTip(
        tag: 'MARCHÉ',
        title: '${p.productName} : ${up ? '+' : '−'}${ch.abs().toStringAsFixed(1)} %',
        text: up ? 'Le prix monte : c\'est le moment de regarder où vendre.' : 'Le prix baisse : comparez les marchés avant de vendre.',
        image: _dedicated('conseil_marche'),
        fallback: _imgMarket,
        route: '/markets',
        isTab: true,
      ));
      break;
    }
  }

  // Finances et investissement
  if (finances != null) {
    if (finances.totalExpenses > 0 && finances.totalRevenue == 0) {
      tips.add(AdviceTip(
        tag: 'FINANCES',
        title: '${_fcfa(finances.totalExpenses)} F dépensés, aucune vente',
        text: 'Notez vos ventes pour suivre votre marge au fil de la campagne.',
        image: _dedicated('conseil_finances'),
        fallback: _imgCrowd,
        route: '/finances',
      ));
    } else if (finances.balance < 0) {
      tips.add(AdviceTip(
        tag: 'FINANCES',
        title: 'Dépenses supérieures aux recettes',
        text: 'Il manque ${_fcfa(-finances.balance)} F. Regardez vos postes de dépense.',
        image: _dedicated('conseil_finances'),
        fallback: _imgCrowd,
        route: '/finances',
      ));
    } else if (finances.totalRevenue > 0 && finances.balance > 0) {
      tips.add(AdviceTip(
        tag: 'INVESTISSEMENT',
        title: 'Solde positif : ${_fcfa(finances.balance)} F',
        text: 'Gardez une réserve pour la prochaine campagne (semences, engrais) avant d\'investir.',
        image: _dedicated('conseil_investissement'),
        fallback: _imgCrowd,
        route: '/finances',
      ));
    }
  }

  tips.add(AdviceTip(
    tag: 'NAATAL IA',
    title: 'Une question sur vos cultures ?',
    text: 'Les réponses s\'appuient sur des fiches techniques sourcées.',
    image: _dedicated('conseil_ia'),
    fallback: _imgTech,
    route: '/ai',
    isTab: true,
  ));

  // On garde l'IA en dernier et on limite le nombre de cartes.
  final ia = tips.removeLast();
  return [...tips.take(5), ia];
}

/// Carrousel de conseils : change de carte toutes les 6 secondes, un geste relance le compte à rebours.
class AdviceCarousel extends StatefulWidget {
  const AdviceCarousel({super.key, required this.tips});

  final List<AdviceTip> tips;

  @override
  State<AdviceCarousel> createState() => _AdviceCarouselState();
}

class _AdviceCarouselState extends State<AdviceCarousel> {
  static const _interval = Duration(seconds: 6);
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted || widget.tips.length < 2 || !_controller.hasClients) return;
      _controller.animateToPage((_index + 1) % widget.tips.length, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.tips.length;
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: NotificationListener<UserScrollNotification>(
            onNotification: (n) {
              if (n.direction != ScrollDirection.idle) _restart();
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: count,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _AdviceCard(tip: widget.tips[i]),
            ),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: i == _index ? 20 : 6,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.primary : AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.tip});

  final AdviceTip tip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => tip.isTab ? context.go(tip.route) : context.push(tip.route),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                tip.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  tip.fallback,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: AppColors.primaryDark),
                ),
              ),
              // Dégradé : l'image reste visible en haut, le texte est lisible en bas.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.10),
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.88),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                          child: Text(tip.tag, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 18),
                      ],
                    ),
                    const Spacer(),
                    Text(tip.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(tip.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
