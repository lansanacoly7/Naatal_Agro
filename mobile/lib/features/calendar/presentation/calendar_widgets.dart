import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../screens/markets/markets_data.dart' show marketQuotesProvider;
import '../../../ui/ui.dart';
import '../../markets/data/markets_provider.dart';
import '../data/models/crop_calendar.dart';
import '../domain/season_logic.dart';
import 'calendar_labels.dart';

/// Photo d'une culture, ou une icône quand on n'a pas d'image.
class CropPhoto extends StatelessWidget {
  const CropPhoto({super.key, required this.cropKey, this.width = 56, this.height = 56, this.radius = 14});

  final String cropKey;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final asset = calendarCropImage(cropKey);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: asset == null
            ? ColoredBox(color: c.domainCultures.withValues(alpha: 0.14), child: Icon(Icons.grass_rounded, color: c.domainCultures, size: height * 0.5))
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(color: c.domainCultures.withValues(alpha: 0.14), child: Icon(Icons.grass_rounded, color: c.domainCultures, size: height * 0.5)),
              ),
      ),
    );
  }
}

/// Carte d'une culture dans les listes horizontales : photo, nom, une ligne de précision.
class CropCard extends StatelessWidget {
  const CropCard({super.key, required this.crop, required this.note, required this.color, required this.onTap});

  final CalendarCrop crop;
  final String note;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      semanticLabel: '${crop.name}. $note',
      child: Container(
        width: 156,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: c.line),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.3 : 0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CropPhoto(cropKey: crop.key, width: 156, height: 108, radius: Radii.l),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(height: 5, color: color),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.m, Space.s, Space.m, Space.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(crop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(color: c.ink, weight: 800)),
                  const SizedBox(height: 2),
                  Text(note, maxLines: 3, overflow: TextOverflow.ellipsis, style: T.caption(color: c.ink2, weight: 600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne « À préparer » : la culture, quand commence le semis, et dans combien de temps.
class PrepareTile extends StatelessWidget {
  const PrepareTile({super.key, required this.season, required this.onTap});

  final CropSeason season;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final up = season.prepare!;
    final variant = up.window.label.isEmpty ? '' : ' · ${up.window.label.toLowerCase()}';
    return PressScale(
      onTap: onTap,
      scale: 0.99,
      semanticLabel: 'Préparez ${season.crop.name}, semis ${up.inWords}',
      child: Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.l),
          border: Border.all(color: c.gold.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Row(
          children: [
            CropPhoto(cropKey: season.crop.key, width: 64, height: 64),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(season.crop.name, style: T.body(color: c.ink, weight: 800)),
                  const SizedBox(height: 2),
                  Text(
                    'Semis le ${monthDayLabel(up.window.sow!.start)}$variant',
                    style: T.caption(color: c.ink2, weight: 600),
                  ),
                  const SizedBox(height: Space.s),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.m, vertical: 5),
                    decoration: BoxDecoration(color: c.gold.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(Radii.pill)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_top_rounded, size: 14, color: c.ink),
                        const SizedBox(width: 5),
                        Flexible(child: Text('Préparez ${up.inWords}', maxLines: 2, style: T.caption(color: c.ink, weight: 800))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grille de l'année : une ligne par culture, 12 cases ; vert = semis, doré = récolte, le mois courant est encadré.
class YearGrid extends StatelessWidget {
  const YearGrid({super.key, required this.crops, required this.zone, required this.currentMonth, required this.onOpen});

  final List<CalendarCrop> crops;
  final String zone;
  final int currentMonth;
  final ValueChanged<CalendarCrop> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const initials = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.m, Space.m, Space.m, Space.s),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.l), border: Border.all(color: c.line)),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 104),
              for (var m = 1; m <= 12; m++)
                Expanded(
                  child: Center(
                    child: Text(
                      initials[m - 1],
                      style: T.caption(color: m == currentMonth ? c.accent : c.ink2, weight: m == currentMonth ? 900 : 600),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          for (final crop in crops)
            PressScale(
              onTap: () => onOpen(crop),
              scale: 0.99,
              semanticLabel: crop.name,
              child: SizedBox(
                height: 34,
                child: Row(
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(crop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption(color: c.ink, weight: 700)),
                    ),
                    for (var m = 1; m <= 12; m++) Expanded(child: _Cell(activity: activityInMonth(crop, zone, m), current: m == currentMonth)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.l,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Legend(color: c.accent, label: 'Semis'),
              _Legend(color: c.gold, label: 'Récolte'),
              Text('Touchez une culture pour le détail', style: T.caption(color: c.ink2, weight: 500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.activity, required this.current});

  final MonthActivity activity;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final Decoration decoration;
    if (activity.sowing && activity.harvesting) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: LinearGradient(colors: [c.accent, c.accent, c.gold, c.gold], stops: const [0, 0.5, 0.5, 1], begin: Alignment.topLeft, end: Alignment.bottomRight),
      );
    } else {
      decoration = BoxDecoration(
        color: activity.sowing ? c.accent : (activity.harvesting ? c.gold : c.surfaceAlt),
        borderRadius: BorderRadius.circular(5),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 6),
      decoration: decoration,
      foregroundDecoration: current ? BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: c.ink, width: 1.4)) : null,
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 5),
        Text(label, style: T.caption(color: context.c.ink, weight: 700)),
      ],
    );
  }
}

/// Produits de saison sur les marchés : le prix moyen relevé, jamais un prix inventé.
class SeasonMarkets extends ConsumerWidget {
  const SeasonMarkets({super.key, required this.crops});

  final List<CalendarCrop> crops;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(allProductsProvider).valueOrNull ?? const [];
    final rows = <Widget>[];
    for (final crop in crops) {
      final first = _normalize(crop.name.split(RegExp(r'[ (]')).first);
      final matches = [for (final p in products) if (_normalize(p.name).startsWith(first)) p.name];
      if (matches.isEmpty) continue;
      rows.add(_PriceLine(crop: crop, productName: matches.first));
      if (rows.length == 5) break;
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Sur les marchés'),
        GroupedList(children: rows),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter + 4, Space.s, Space.gutter, 0),
          child: Text(
            'Prix relevés sur les marchés. Le classement des produits les mieux vendus mois par mois viendra quand l\'application aura un an de relevés : on n\'invente rien avant.',
            style: T.caption(color: context.c.ink2, weight: 500),
          ),
        ),
      ],
    );
  }

  static String _normalize(String text) {
    const from = 'àâäéèêëîïôöùûüç';
    const to = 'aaaeeeeiioouuuc';
    final buffer = StringBuffer();
    for (final ch in text.toLowerCase().characters) {
      final i = from.indexOf(ch);
      buffer.write(i >= 0 ? to[i] : ch);
    }
    return buffer.toString().trim();
  }
}

class _PriceLine extends ConsumerWidget {
  const _PriceLine({required this.crop, required this.productName});

  final CalendarCrop crop;
  final String productName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(marketQuotesProvider(productName)).valueOrNull;
    if (quotes == null || quotes.isEmpty) return const SizedBox.shrink();
    final average = quotes.map((q) => q.price).reduce((a, b) => a + b) / quotes.length;
    final c = context.c;
    return GroupedRow(
      leading: CropPhoto(cropKey: crop.key, width: 44, height: 44, radius: 12),
      title: crop.name,
      subtitle: '${quotes.length} marché${quotes.length > 1 ? 's' : ''} · en pleine récolte',
      value: '${Fmt.grouped(average)} F/kg',
      valueColor: c.domainMarches,
      chevron: true,
      onTap: () => context.go('/markets'),
    );
  }
}

/// Détail d'une culture : chaque période de la zone, le cycle, les remarques et la source.
class CropSheet extends StatelessWidget {
  const CropSheet({super.key, required this.crop, required this.zone, required this.zoneName, required this.data, required this.today});

  final CalendarCrop crop;
  final String zone;
  final String zoneName;
  final CalendarData data;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final windows = crop.inZone(zone);
    final season = seasonOf(crop, zone, today);
    final slug = calendarGuideSlug(crop.key);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CropPhoto(cropKey: crop.key, width: 72, height: 72, radius: 18),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(crop.name, style: T.title(color: c.ink)),
                    Text('${categoryLabel(crop.category)} · $zoneName', style: T.caption(color: c.ink2, weight: 600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          _StatusLine(season: season),
          for (final w in windows) ...[
            const SizedBox(height: Space.m),
            Container(
              padding: const EdgeInsets.all(Space.l),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.m), border: Border.all(color: c.line)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (w.label.isNotEmpty) Text(w.label, style: T.body(color: c.ink, weight: 800)),
                  if (w.sow != null || w.allYear) _Fact(icon: Icons.grass_rounded, color: c.accent, label: 'Semis', value: sowingText(w)),
                  if (w.harvest != null) _Fact(icon: Icons.agriculture_rounded, color: c.gold, label: 'Récolte', value: harvestText(w)),
                  if (cycleText(w) != null) _Fact(icon: Icons.schedule_rounded, color: c.slate, label: 'Cycle', value: cycleText(w)!),
                  if (w.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Space.s), child: Text(w.notes, style: T.caption(color: c.ink2, weight: 500))),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.m),
          Text(_sourceLine(windows), style: T.caption(color: c.ink2, weight: 500)),
          if (slug != null) ...[
            const SizedBox(height: Space.l),
            PillButton(
              label: 'Je plante cette culture',
              icon: Icons.add_rounded,
              expand: true,
              onPressed: () {
                Navigator.pop(context);
                context.push('/agriculture/add', extra: slug);
              },
            ),
          ],
        ],
      ),
    );
  }

  String _sourceLine(List<CalendarWindow> windows) {
    final keys = windows.map((w) => w.sourceKey).toSet();
    return {
      for (final key in keys)
        if (data.sources[key] != null) 'Source : ${data.sources[key]!.title} (${data.sources[key]!.publisher}${data.sources[key]!.year == null ? '' : ', ${data.sources[key]!.year}'}).',
      for (final w in windows)
        if (w.sourceNote.isNotEmpty) w.sourceNote,
    }.join(' ');
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.season});

  final CropSeason season;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final String text;
    final Color color;
    if (season.sowingNow.isNotEmpty) {
      final left = season.sowingNow.map((w) => w.sow!.daysLeft(DateTime.now())).reduce((a, b) => a < b ? a : b);
      text = 'C\'est le moment de semer · ${_daysLeft(left)}';
      color = c.accent;
    } else if (season.harvestNow.isNotEmpty) {
      text = 'C\'est la période de récolte';
      color = c.gold;
    } else if (season.prepare != null) {
      text = 'À préparer : les semis commencent ${season.prepare!.inWords}';
      color = c.gold;
    } else {
      text = 'Pas de semis ni de récolte à signaler aujourd\'hui dans cette zone';
      color = c.ink2;
    }
    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(Radii.m)),
      child: Row(
        children: [
          Icon(Icons.event_available_rounded, color: color),
          const SizedBox(width: Space.m),
          Expanded(child: Text(text, style: T.body(color: c.ink, weight: 700))),
        ],
      ),
    );
  }
}

String _daysLeft(int days) => days <= 0 ? 'dernier jour' : days == 1 ? 'encore 1 jour' : 'encore $days jours';

/// « encore 12 jours » : pour les autres écrans.
String daysLeftWords(int days) => _daysLeft(days);

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.color, required this.label, required this.value});

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Space.s),
          SizedBox(width: 58, child: Text(label, style: T.body(color: c.ink2, weight: 600))),
          Expanded(child: Text(value, style: T.body(color: c.ink, weight: 700))),
        ],
      ),
    );
  }
}

/// Une source du calendrier : titre, éditeur, année ; toucher copie le lien.
class SourceTile extends StatelessWidget {
  const SourceTile({super.key, required this.source});

  final CalendarSource source;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: PressScale(
        onTap: source.url.isEmpty
            ? null
            : () {
                Clipboard.setData(ClipboardData(text: source.url));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié')));
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.title, style: T.body(color: c.ink, weight: 700)),
            Text('${source.publisher}${source.year == null ? '' : ' · ${source.year}'}', style: T.caption(color: c.ink2, weight: 600)),
            if (source.note.isNotEmpty) Text(source.note, style: T.caption(color: c.ink2, weight: 500)),
            if (source.url.isNotEmpty) Text('Toucher pour copier le lien', style: T.caption(color: c.accent, weight: 700)),
          ],
        ),
      ),
    );
  }
}
