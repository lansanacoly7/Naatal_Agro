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

/// Grille de l'année : une carte par culture avec ses 12 mois ; vert = on sème, doré = on récolte, le mois courant est marqué.
class YearGrid extends StatelessWidget {
  const YearGrid({super.key, required this.crops, required this.zone, required this.currentMonth, required this.onOpen});

  final List<CalendarCrop> crops;
  final String zone;
  final int currentMonth;
  final ValueChanged<CalendarCrop> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.s),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.l), border: Border.all(color: c.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Space.xl,
            runSpacing: Space.s,
            children: [
              _Legend(color: c.accent, icon: Icons.grass_rounded, label: 'On sème'),
              _Legend(color: c.gold, icon: Icons.agriculture_rounded, label: 'On récolte'),
            ],
          ),
          const SizedBox(height: Space.m),
          for (var i = 0; i < crops.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.line),
            _YearRow(crop: crops[i], zone: zone, currentMonth: currentMonth, onOpen: onOpen),
          ],
        ],
      ),
    );
  }
}

class _YearRow extends StatelessWidget {
  const _YearRow({required this.crop, required this.zone, required this.currentMonth, required this.onOpen});

  final CalendarCrop crop;
  final String zone;
  final int currentMonth;
  final ValueChanged<CalendarCrop> onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final now = activityInMonth(crop, zone, currentMonth);
    return PressScale(
      onTap: () => onOpen(crop),
      scale: 0.99,
      semanticLabel: crop.name,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.m),
        child: Column(
          children: [
            Row(
              children: [
                CropPhoto(cropKey: crop.key, width: 44, height: 44, radius: 22),
                const SizedBox(width: Space.m),
                Expanded(child: Text(crop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(color: c.ink, weight: 800).copyWith(fontSize: 17))),
                if (now.sowing) _NowDot(color: c.accent, icon: Icons.grass_rounded),
                if (now.harvesting) _NowDot(color: c.gold, icon: Icons.agriculture_rounded),
                Icon(Icons.chevron_right_rounded, color: c.ink2, size: 26),
              ],
            ),
            const SizedBox(height: Space.s),
            MonthBars(
              sowing: {for (var m = 1; m <= 12; m++) if (activityInMonth(crop, zone, m).sowing) m},
              harvesting: {for (var m = 1; m <= 12; m++) if (activityInMonth(crop, zone, m).harvesting) m},
              currentMonth: currentMonth,
              height: 24,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastille « c'est le cas maintenant » (on sème / on récolte aujourd'hui).
class _NowDot extends StatelessWidget {
  const _NowDot({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: Space.xs),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: context.c.onAccent),
    );
  }
}

/// Les 12 mois en barres : vert = on sème, doré = on récolte, le mois courant est encadré. Les lettres des mois sont dessous.
class MonthBars extends StatelessWidget {
  const MonthBars({super.key, required this.sowing, required this.harvesting, required this.currentMonth, this.height = 20});

  final Set<int> sowing;
  final Set<int> harvesting;
  final int currentMonth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const initials = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    return Column(
      children: [
        Row(
          children: [
            for (var m = 1; m <= 12; m++)
              Expanded(child: _Cell(sowing: sowing.contains(m), harvesting: harvesting.contains(m), current: m == currentMonth, height: height)),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            for (var m = 1; m <= 12; m++)
              Expanded(
                child: Center(
                  child: Text(
                    initials[m - 1],
                    style: T.caption(color: m == currentMonth ? c.ink : c.ink2, weight: m == currentMonth ? 900 : 600).copyWith(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.sowing, required this.harvesting, required this.current, required this.height});

  final bool sowing;
  final bool harvesting;
  final bool current;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final Decoration decoration;
    if (sowing && harvesting) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(colors: [c.accent, c.accent, c.gold, c.gold], stops: const [0, 0.5, 0.5, 1], begin: Alignment.topLeft, end: Alignment.bottomRight),
      );
    } else {
      decoration = BoxDecoration(color: sowing ? c.accent : (harvesting ? c.gold : c.surfaceAlt), borderRadius: BorderRadius.circular(6));
    }
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: decoration,
      foregroundDecoration: current ? BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: c.ink, width: 2)) : null,
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.icon, required this.label});

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: context.c.onAccent),
        ),
        const SizedBox(width: Space.s),
        Text(label, style: T.body(color: context.c.ink, weight: 700)),
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
          child: Text('Prix relevés sur les marchés.', style: T.caption(color: context.c.ink2, weight: 500)),
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

/// Détail d'une culture : le bouton pour la planter en haut, puis une carte par période (semis, récolte, cycle en images).
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
              CropPhoto(cropKey: crop.key, width: 64, height: 64, radius: 32),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(crop.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title(color: c.ink)),
                    Text(categoryLabel(crop.category), style: T.caption(color: c.ink2, weight: 600)),
                  ],
                ),
              ),
              if (slug != null) ...[
                const SizedBox(width: Space.s),
                PillButton(
                  label: 'Je plante',
                  icon: Icons.add_rounded,
                  compact: true,
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/agriculture/add', extra: slug);
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.l),
          _StatusLine(season: season, today: today),
          for (final w in windows) ...[
            const SizedBox(height: Space.m),
            _WindowCard(window: w, currentMonth: today.month),
          ],
          const SizedBox(height: Space.m),
          _MoreInfo(windows: windows, data: data, zoneName: zoneName),
        ],
      ),
    );
  }
}

/// Une période de culture : son nom en gros avec une phrase pour l'expliquer, puis semis / récolte / cycle en icônes et les 12 mois.
class _WindowCard extends StatelessWidget {
  const _WindowCard({required this.window, required this.currentMonth});

  final CalendarWindow window;
  final int currentMonth;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = window;
    final info = w.label.isEmpty ? null : variantInfo(w.label);
    final cycle = cycleText(w);
    final sowMonths = w.allYear ? {for (var m = 1; m <= 12; m++) m} : (w.sow?.months ?? const <int>{});
    final harvestMonths = w.harvest?.months ?? const <int>{};
    return Container(
      padding: const EdgeInsets.all(Space.l),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.l), border: Border.all(color: c.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (w.label.isNotEmpty) ...[
            Row(
              children: [
                if (info != null) ...[Icon(info.icon, color: c.accent, size: 24), const SizedBox(width: Space.s)],
                Expanded(child: Text(w.label, style: T.title(color: c.ink).copyWith(fontSize: 19))),
              ],
            ),
            if (info != null) ...[
              const SizedBox(height: Space.xs),
              Text(info.text, style: T.body(color: c.ink2, weight: 500)),
            ],
            const SizedBox(height: Space.m),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (w.sow != null || w.allYear) Expanded(child: _FactTile(icon: Icons.grass_rounded, color: c.accent, label: 'Semis', value: sowingText(w))),
              if (w.harvest != null) Expanded(child: _FactTile(icon: Icons.agriculture_rounded, color: c.gold, label: 'Récolte', value: harvestText(w))),
              if (cycle != null) Expanded(child: _FactTile(icon: Icons.schedule_rounded, color: c.slate, label: 'Cycle', value: cycle)),
            ],
          ),
          if (sowMonths.isNotEmpty || harvestMonths.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            MonthBars(sowing: sowMonths, harvesting: harvestMonths, currentMonth: currentMonth, height: 18),
          ],
        ],
      ),
    );
  }
}

/// Une information en gros pictogramme : la pastille de couleur, le mot, puis la période.
class _FactTile extends StatelessWidget {
  const _FactTile({required this.icon, required this.color, required this.label, required this.value});

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(right: Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: c.onAccent),
          ),
          const SizedBox(height: Space.xs),
          Text(label, style: T.caption(color: c.ink2, weight: 700)),
          Text(value, maxLines: 3, overflow: TextOverflow.ellipsis, style: T.body(color: c.ink, weight: 800).copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}

/// Remarques et source, repliées : utiles mais pas nécessaires pour décider.
class _MoreInfo extends StatefulWidget {
  const _MoreInfo({required this.windows, required this.data, required this.zoneName});

  final List<CalendarWindow> windows;
  final CalendarData data;
  final String zoneName;

  @override
  State<_MoreInfo> createState() => _MoreInfoState();
}

class _MoreInfoState extends State<_MoreInfo> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final notes = [for (final w in widget.windows) if (w.notes.isNotEmpty) w.notes];
    final source = _sourceLine();
    if (notes.isEmpty && source.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PressScale(
          onTap: () => setState(() => _open = !_open),
          semanticLabel: _open ? 'Cacher les détails' : 'Voir plus de détails',
          child: Container(
            height: Hit.min,
            padding: const EdgeInsets.symmetric(horizontal: Space.l),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: c.line)),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: c.ink2, size: 22),
                const SizedBox(width: Space.s),
                Expanded(child: Text('Plus de détails', style: T.body(color: c.ink, weight: 700))),
                Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: c.ink2),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: Space.m),
          for (final n in notes) Padding(padding: const EdgeInsets.only(bottom: Space.s), child: Text(n, style: T.caption(color: c.ink2, weight: 500))),
          if (source.isNotEmpty) Text(source, style: T.caption(color: c.ink2, weight: 500)),
          Padding(padding: const EdgeInsets.only(top: Space.s), child: Text('Zone : ${widget.zoneName}', style: T.caption(color: c.ink2, weight: 500))),
        ],
      ],
    );
  }

  String _sourceLine() {
    final keys = widget.windows.map((w) => w.sourceKey).toSet();
    final sources = widget.data.sources;
    return {
      for (final key in keys)
        if (sources[key] != null) 'Source : ${sources[key]!.title} (${sources[key]!.publisher}${sources[key]!.year == null ? '' : ', ${sources[key]!.year}'}).',
      for (final w in widget.windows)
        if (w.sourceNote.isNotEmpty) w.sourceNote,
    }.join(' ');
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.season, required this.today});

  final CropSeason season;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final String text;
    final IconData icon;
    final Color color;
    if (season.sowingNow.isNotEmpty) {
      final left = season.sowingNow.map((w) => w.sow!.daysLeft(today)).reduce((a, b) => a < b ? a : b);
      text = 'On sème maintenant · ${_daysLeft(left)}';
      icon = Icons.grass_rounded;
      color = c.accent;
    } else if (season.harvestNow.isNotEmpty) {
      text = 'On récolte maintenant';
      icon = Icons.agriculture_rounded;
      color = c.gold;
    } else if (season.prepare != null) {
      text = 'Bientôt : semis ${season.prepare!.inWords}';
      icon = Icons.hourglass_top_rounded;
      color = c.gold;
    } else {
      text = 'Rien à faire en ce moment';
      icon = Icons.pause_circle_outline_rounded;
      color = c.ink2;
    }
    return Container(
      padding: const EdgeInsets.all(Space.m),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Radii.l)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: c.onAccent, size: 24),
          ),
          const SizedBox(width: Space.m),
          Expanded(child: Text(text, style: T.body(color: c.ink, weight: 800).copyWith(fontSize: 17))),
        ],
      ),
    );
  }
}

String _daysLeft(int days) => days <= 0 ? 'dernier jour' : days == 1 ? 'encore 1 jour' : 'encore $days jours';

/// « encore 12 jours » : pour les autres écrans.
String daysLeftWords(int days) => _daysLeft(days);

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
