import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/ui.dart';
import '../data/calendar_provider.dart';
import '../data/models/crop_calendar.dart';
import '../domain/season_logic.dart';
import 'calendar_labels.dart';
import 'calendar_widgets.dart';

/// Calendrier agricole du Sénégal : ce qu'on sème, ce qu'on récolte et ce qu'il faut préparer, dans la zone de la
/// personne, mois par mois. Toutes les dates viennent de sources citées en bas de page ; sans source, on le dit.
class AgriculturalCalendarScreen extends ConsumerStatefulWidget {
  const AgriculturalCalendarScreen({super.key, this.today});

  /// Date du jour (fixée dans les tests).
  final DateTime? today;

  @override
  ConsumerState<AgriculturalCalendarScreen> createState() => _AgriculturalCalendarScreenState();
}

class _Entry {
  const _Entry(this.crop, this.note);

  final CalendarCrop crop;
  final String note;
}

class _AgriculturalCalendarScreenState extends ConsumerState<AgriculturalCalendarScreen> {
  late int _month = _today.month;
  String? _category;

  /// La bande des mois s'ouvre sur le mois courant (une pastille fait environ 86 px, espace compris).
  late final ScrollController _monthScroll = ScrollController(initialScrollOffset: ((_today.month - 2) * 86.0).clamp(0.0, 600.0));

  @override
  void dispose() {
    _monthScroll.dispose();
    super.dispose();
  }

  DateTime get _today => widget.today ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(cropCalendarProvider);
    final zoneCode = ref.watch(calendarZoneProvider);
    final calendar = data.valueOrNull;
    final zoneName = calendar == null || zoneCode == null ? null : calendar.zone(zoneCode)?.name;

    return LargeTitleScaffold(
      title: 'Calendrier',
      eyebrow: zoneName == null ? 'Agricole · Sénégal' : 'Agricole · $zoneName',
      reserveNav: false,
      onRefresh: () async => ref.invalidate(cropCalendarProvider),
      slivers: [
        SliverToBoxAdapter(
          child: data.when(
            loading: () => const Padding(padding: EdgeInsets.all(Space.gutter), child: Skeleton(height: 320, radius: 24)),
            error: (error, _) => ErrorState(
              message: 'Le calendrier n\'a pas pu être chargé. Vérifiez votre réseau.',
              onRetry: () => ref.invalidate(cropCalendarProvider),
            ),
            data: (d) => zoneCode == null ? _ZoneChooser(data: d) : _content(context, d, zoneCode),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, CalendarData data, String zone) {
    final c = context.c;
    final today = _today;
    final current = _month == today.month;
    final summary = summarize(data.crops, zone, today);
    final zoneName = data.zone(zone)?.name ?? zone;
    final region = ref.watch(profileRegionNameProvider);

    // Cultures à semer et à récolter : celles du jour (avec le compte à rebours) ou celles du mois choisi
    final sowing = <_Entry>[];
    final harvesting = <_Entry>[];
    final allYear = <CalendarCrop>[];
    if (current) {
      for (final s in summary.sowing) {
        final w = (List.of(s.sowingNow)..sort((a, b) => a.sow!.daysLeft(today).compareTo(b.sow!.daysLeft(today)))).first;
        final left = daysLeftWords(w.sow!.daysLeft(today));
        sowing.add(_Entry(s.crop, w.label.isEmpty ? left : '${w.label}\n$left'));
      }
      for (final s in summary.harvesting) {
        final w = s.harvestNow.first;
        final end = w.harvest!.end;
        final until = 'jusqu\'au ${monthDayLabel(end)}';
        harvesting.add(_Entry(s.crop, w.label.isEmpty ? until : '${w.label}\n$until'));
      }
      allYear.addAll([for (final s in summary.allYear) s.crop]);
    } else {
      for (final crop in data.crops) {
        final windows = crop.inZone(zone);
        if (windows.isEmpty) continue;
        final activity = activityInMonth(crop, zone, _month);
        final sow = windows.where((w) => !w.allYear && (w.sow?.months.contains(_month) ?? false)).toList();
        final harvest = windows.where((w) => w.harvest?.months.contains(_month) ?? false).toList();
        if (sow.isNotEmpty) sowing.add(_Entry(crop, _windowNote(sow.first, sow.first.sow)));
        if (harvest.isNotEmpty) harvesting.add(_Entry(crop, _windowNote(harvest.first, harvest.first.harvest)));
        if (activity.sowing && windows.any((w) => w.allYear)) allYear.add(crop);
      }
    }

    final gridCrops = [
      for (final crop in data.crops)
        if (crop.inZone(zone).isNotEmpty && (_category == null || crop.category == _category)) crop,
    ]..sort((a, b) => a.category == b.category ? a.name.compareTo(b.name) : a.category.compareTo(b.category));
    final categories = {for (final crop in data.crops) if (crop.inZone(zone).isNotEmpty) crop.category}.toList()..sort();
    final usedSources = {
      for (final crop in data.crops) for (final w in crop.inZone(zone)) w.sourceKey,
    };

    final spoken = _spokenSummary(zoneName, current, sowing, harvesting, current ? summary.prepare : const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Zone et lecture à voix haute
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Row(
            children: [
              Expanded(
                child: PressScale(
                  onTap: () => _pickZone(context, data, zone, region),
                  semanticLabel: 'Changer de zone. Zone actuelle : $zoneName',
                  child: Container(
                    height: Hit.min,
                    padding: const EdgeInsets.symmetric(horizontal: Space.l),
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: c.line)),
                    child: Row(
                      children: [
                        Icon(Icons.place_rounded, size: 20, color: c.domainMeteo),
                        const SizedBox(width: Space.s),
                        Expanded(child: Text(zoneName, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body(color: c.ink, weight: 700))),
                        Icon(Icons.expand_more_rounded, color: c.ink2),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.s),
              ReadAloudButton(key: ValueKey('listen-$_month-$zone'), text: spoken),
            ],
          ),
        ),
        const SizedBox(height: Space.m),

        // Les 12 mois
        SizedBox(
          height: 48,
          child: ListView.separated(
            controller: _monthScroll,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            scrollDirection: Axis.horizontal,
            itemCount: 12,
            separatorBuilder: (_, __) => const SizedBox(width: Space.s),
            itemBuilder: (context, i) {
              final m = i + 1;
              final selected = m == _month;
              return PressScale(
                onTap: () => setState(() => _month = m),
                semanticLabel: monthNames[i],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.l),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? c.accent : c.surface,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(color: selected ? c.accent : c.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(monthShort[i], style: T.body(color: selected ? c.onAccent : c.ink, weight: 700)),
                      if (m == today.month) ...[
                        const SizedBox(width: 6),
                        Container(width: 7, height: 7, decoration: BoxDecoration(color: selected ? c.onAccent : c.accent, shape: BoxShape.circle)),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Space.l),

        // Ce mois-ci
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: _Hero(
            current: current,
            today: today,
            month: _month,
            sowing: sowing,
            harvesting: harvesting,
            hasPrepare: current && summary.prepare.isNotEmpty,
          ),
        ),

        // À préparer : annoncé 4 à 6 semaines avant le début des semis
        if (current && summary.prepare.isNotEmpty) ...[
          const SectionHeader('Bientôt'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Column(
              children: [
                for (final season in summary.prepare.take(6)) ...[
                  PrepareTile(season: season, onTap: () => _openCrop(context, data, season.crop, zone)),
                  const SizedBox(height: Space.s),
                ],
              ],
            ),
          ),
        ],

        if (sowing.isNotEmpty) ...[
          SectionHeader(current ? 'Semez maintenant' : 'Semez en ${monthNames[_month - 1]}'),
          _CropRow(entries: sowing, color: c.accent, onOpen: (crop) => _openCrop(context, data, crop, zone)),
        ],
        if (harvesting.isNotEmpty) ...[
          SectionHeader(current ? 'Récoltez maintenant' : 'Récoltez en ${monthNames[_month - 1]}'),
          _CropRow(entries: harvesting, color: c.gold, onOpen: (crop) => _openCrop(context, data, crop, zone)),
        ],
        if (allYear.isNotEmpty) ...[
          const SectionHeader('Semez quand vous voulez'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final crop in allYear)
                  PressScale(
                    onTap: () => _openCrop(context, data, crop, zone),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 6, Space.m, 6),
                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: c.line)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CropPhoto(cropKey: crop.key, width: 30, height: 30, radius: 15),
                          const SizedBox(width: Space.s),
                          Flexible(child: Text(crop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.caption(color: c.ink, weight: 700))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],

        if (current && harvesting.isNotEmpty) SeasonMarkets(crops: [for (final e in harvesting) e.crop]),

        // L'année entière
        const SectionHeader('Toutes les cultures'),
        SizedBox(
          height: 52,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(label: 'Tout', selected: _category == null, onTap: () => setState(() => _category = null)),
              for (final category in categories) ...[
                const SizedBox(width: Space.s),
                _FilterChip(label: categoryLabel(category), selected: _category == category, onTap: () => setState(() => _category = category)),
              ],
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: YearGrid(crops: gridCrops, zone: zone, currentMonth: today.month, onOpen: (crop) => _openCrop(context, data, crop, zone)),
        ),

        // Mes parcelles
        const SectionHeader('Mes cultures'),
        GroupedList(
          children: [
            GroupedRow(
              leading: IconTile(icon: Icons.event_note_rounded, color: c.accent),
              title: 'Mes dates',
              chevron: true,
              onTap: () => context.push('/calendar/mine'),
            ),
          ],
        ),

        // Sources et limites : utiles, mais pas besoin de les avoir sous les yeux
        const SizedBox(height: Space.l),
        GroupedList(
          children: [
            GroupedRow(
              leading: IconTile(icon: Icons.info_outline_rounded, color: c.slate),
              title: 'Sources et limites',
              chevron: true,
              onTap: () => _openSources(context, data, usedSources),
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),
      ],
    );
  }

  void _openSources(BuildContext context, CalendarData data, Set<String> usedSources) {
    showNaatalSheet<void>(
      context,
      builder: (ctx) {
        final c = ctx.c;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sources et limites', style: T.title(color: c.ink)),
              const SizedBox(height: Space.s),
              Text('Ce sont des repères. La pluie peut tout changer.', style: T.body(color: c.ink2)),
              const SizedBox(height: Space.l),
              for (final key in usedSources)
                if (data.sources[key] != null) SourceTile(source: data.sources[key]!),
              if (data.undocumented.isNotEmpty) ...[
                const SizedBox(height: Space.s),
                Text('Dates pas encore connues', style: T.body(color: c.ink, weight: 800)),
                const SizedBox(height: Space.xs),
                Text(data.undocumented.join(', '), style: T.body(color: c.ink, weight: 600)),
                const SizedBox(height: Space.xs),
                Text('Pas de date sûre pour ces cultures. Nous ne les inventons pas.', style: T.caption(color: c.ink2, weight: 500)),
              ],
            ],
          ),
        );
      },
    );
  }

  String _windowNote(CalendarWindow w, Span? span) {
    final variant = w.label.isEmpty ? '' : '${w.label}\n';
    if (span == null || (w.periodText.isNotEmpty && w.sow == null)) return '$variant${w.periodText}'.trim();
    return '$variant${spanLabel(span)}';
  }

  String _spokenSummary(String zoneName, bool current, List<_Entry> sowing, List<_Entry> harvesting, List<CropSeason> prepare) {
    String names(List<String> list) => list.take(6).join(', ');
    final when = current ? 'Ce mois-ci' : 'En ${monthNames[_month - 1]}';
    final parts = <String>['Calendrier agricole, zone $zoneName.'];
    if (sowing.isNotEmpty) parts.add('$when, à semer : ${names([for (final e in sowing) e.crop.name])}.');
    if (harvesting.isNotEmpty) parts.add('À récolter : ${names([for (final e in harvesting) e.crop.name])}.');
    for (final s in prepare.take(3)) {
      parts.add('À préparer : ${s.crop.name}, les semis commencent ${s.prepare!.inWords}.');
    }
    if (sowing.isEmpty && harvesting.isEmpty && prepare.isEmpty) parts.add('$when, pas de semis ni de récolte à signaler dans votre zone.');
    return parts.join(' ');
  }

  Future<void> _pickZone(BuildContext context, CalendarData data, String current, String? region) {
    return showNaatalSheet<void>(
      context,
      builder: (ctx) => _ZoneList(
        data: data,
        selected: current,
        region: region,
        onPick: (code) {
          ref.read(calendarZoneChoiceProvider.notifier).state = code;
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _openCrop(BuildContext context, CalendarData data, CalendarCrop crop, String zone) {
    showNaatalSheet<void>(
      context,
      builder: (ctx) => CropSheet(crop: crop, zone: zone, zoneName: data.zone(zone)?.name ?? zone, data: data, today: _today),
    );
  }
}

/// Le grand encadré du haut : le message du mois, en une phrase.
class _Hero extends StatelessWidget {
  const _Hero({required this.current, required this.today, required this.month, required this.sowing, required this.harvesting, required this.hasPrepare});

  final bool current;
  final DateTime today;
  final int month;
  final List<_Entry> sowing;
  final List<_Entry> harvesting;
  final bool hasPrepare;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final name = monthNames[month - 1];
    final String title;
    if (sowing.isNotEmpty) {
      title = current ? 'On sème maintenant' : 'En $name, on sème';
    } else if (harvesting.isNotEmpty) {
      title = current ? 'On récolte maintenant' : 'En $name, on récolte';
    } else if (hasPrepare) {
      title = 'Bientôt les semis';
    } else {
      title = current ? 'Rien à semer ni à récolter' : 'En $name, rien de particulier';
    }
    final eyebrow = current ? 'AUJOURD\'HUI · ${Fmt.dayMonth(today).toUpperCase()}' : name.toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xl),
        gradient: LinearGradient(colors: [c.heroTop, c.heroBottom], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: T.caption(color: Colors.white.withValues(alpha: 0.8), weight: 800)),
          const SizedBox(height: Space.xs),
          Text(title, style: T.largeTitle(color: Colors.white).copyWith(fontSize: 26)),
          if (sowing.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            _HeroLine(icon: Icons.grass_rounded, label: 'À semer', names: [for (final e in sowing) e.crop.name]),
          ],
          if (harvesting.isNotEmpty) ...[
            const SizedBox(height: Space.s),
            _HeroLine(icon: Icons.agriculture_rounded, label: 'À récolter', names: [for (final e in harvesting) e.crop.name]),
          ],
          if (sowing.isEmpty && harvesting.isEmpty) ...[
            const SizedBox(height: Space.s),
            Text(
              hasPrepare ? 'Regardez « Bientôt » plus bas.' : 'Touchez un autre mois.',
              style: T.body(color: Colors.white.withValues(alpha: 0.88)),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroLine extends StatelessWidget {
  const _HeroLine({required this.icon, required this.label, required this.names});

  final IconData icon;
  final String label;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(5).toList();
    final more = names.length - shown.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: Space.s),
        Expanded(
          child: Text(
            '$label : ${shown.join(', ')}${more > 0 ? ' et $more autre${more > 1 ? 's' : ''}' : ''}',
            style: T.body(color: Colors.white, weight: 700),
          ),
        ),
      ],
    );
  }
}

class _CropRow extends StatelessWidget {
  const _CropRow({required this.entries, required this.color, required this.onOpen});

  final List<_Entry> entries;
  final Color color;
  final ValueChanged<CalendarCrop> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 232,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.xs),
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: Space.m),
        itemBuilder: (context, i) => CropCard(crop: entries[i].crop, note: entries[i].note, color: color, onTap: () => onOpen(entries[i].crop)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : c.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: selected ? c.accent : c.line, width: selected ? 2 : 1),
        ),
        child: Text(label, style: T.body(color: selected ? c.onAccent : c.ink, weight: 800)),
      ),
    );
  }
}

/// Quand on ne sait pas dans quelle zone se trouve la personne : on lui demande, on ne devine pas.
class _ZoneChooser extends ConsumerWidget {
  const _ZoneChooser({required this.data});

  final CalendarData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Où cultivez-vous ?', style: T.title(color: c.ink)),
          const SizedBox(height: Space.xs),
          Text('Touchez votre zone.', style: T.body(color: c.ink2)),
          const SizedBox(height: Space.l),
          for (final zone in data.zones) ...[
            PressScale(
              onTap: () => ref.read(calendarZoneChoiceProvider.notifier).state = zone.code,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Space.l),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.l), border: Border.all(color: c.line)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(zone.name, style: T.body(color: c.ink, weight: 800)),
                    const SizedBox(height: 2),
                    Text(zone.description, style: T.caption(color: c.ink2, weight: 500)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.s),
          ],
        ],
      ),
    );
  }
}

class _ZoneList extends StatelessWidget {
  const _ZoneList({required this.data, required this.selected, required this.region, required this.onPick});

  final CalendarData data;
  final String selected;
  final String? region;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mine = region == null ? const <String>[] : (data.regionZones[region] ?? const <String>[]);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.xxl, Space.xl, Space.xxl, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Votre zone', style: T.title(color: c.ink)),
          if (mine.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text('Touchez la zone de votre champ.', style: T.body(color: c.ink2)),
            ),
          const SizedBox(height: Space.l),
          for (final zone in data.zones) ...[
            PressScale(
              onTap: () => onPick(zone.code),
              child: Container(
                padding: const EdgeInsets.all(Space.l),
                decoration: BoxDecoration(
                  color: zone.code == selected ? c.accent.withValues(alpha: 0.12) : c.surface,
                  borderRadius: BorderRadius.circular(Radii.l),
                  border: Border.all(color: zone.code == selected ? c.accent : c.line, width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(child: Text(zone.name, style: T.body(color: c.ink, weight: 800))),
                              if (mine.contains(zone.code)) ...[
                                const SizedBox(width: Space.s),
                                Icon(Icons.place_rounded, size: 16, color: c.domainMeteo),
                                Text(' ma région', style: T.caption(color: c.domainMeteo, weight: 700)),
                              ],
                            ],
                          ),
                          Text(zone.description, style: T.caption(color: c.ink2, weight: 500)),
                        ],
                      ),
                    ),
                    if (zone.code == selected) Icon(Icons.check_circle_rounded, color: c.accent),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.s),
          ],
        ],
      ),
    );
  }
}
