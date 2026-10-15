import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

/// Écran à grand titre qui se réduit au défilement, comme dans iOS.
///
/// [slivers] reçoit le contenu. Un espace est ajouté en bas pour que la barre
/// flottante ne cache jamais le dernier élément (sauf si [reserveNav] est faux).
class LargeTitleScaffold extends StatelessWidget {
  const LargeTitleScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.eyebrow,
    this.actions,
    this.onRefresh,
    this.reserveNav = true,
    this.bottom,
    this.controller,
  });

  final String title;

  /// Petite ligne au-dessus du titre (date, nombre d'éléments…).
  final String? eyebrow;
  final List<Widget> slivers;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;
  final bool reserveNav;

  /// Barre fixe sous le contenu (bouton principal, par exemple).
  final Widget? bottom;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final canPop = Navigator.of(context).canPop();
    final top = MediaQuery.paddingOf(context).top;
    final expanded = top + (eyebrow == null ? 104 : 124);
    final collapsed = top + kToolbarHeight;

    final scroll = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _TitleHeader(
            title: title,
            eyebrow: eyebrow,
            actions: actions ?? const [],
            canPop: canPop,
            expandedHeight: expanded,
            collapsedHeight: collapsed,
            background: c.bg,
            line: c.line,
            ink: c.ink,
            ink2: c.ink2,
            top: top,
          ),
        ),
        ...slivers,
        SliverToBoxAdapter(
          child: SizedBox(height: reserveNav ? Space.navClearance : Space.huge),
        ),
      ],
    );

    final body = onRefresh == null
        ? scroll
        : RefreshIndicator(
            color: c.accent,
            backgroundColor: c.surface,
            edgeOffset: collapsed,
            onRefresh: onRefresh!,
            child: scroll,
          );

    return Scaffold(
      backgroundColor: c.bg,
      body: bottom == null ? body : Column(children: [Expanded(child: body), bottom!]),
    );
  }
}

class _TitleHeader extends SliverPersistentHeaderDelegate {
  _TitleHeader({
    required this.title,
    required this.eyebrow,
    required this.actions,
    required this.canPop,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.background,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.top,
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;
  final bool canPop;
  final double expandedHeight;
  final double collapsedHeight;
  final Color background;
  final Color line;
  final Color ink;
  final Color ink2;
  final double top;

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final range = math.max(1.0, maxExtent - minExtent);
    final t = (1 - shrinkOffset / range).clamp(0.0, 1.0); // 1 = déplié, 0 = réduit
    final eased = Curves.easeOutCubic.transform(t);

    final fontSize = 20 + (34 - 20) * eased;
    final leftExpanded = Space.gutter;
    final leftCollapsed = canPop ? 56.0 : Space.gutter;
    final left = leftCollapsed + (leftExpanded - leftCollapsed) * eased;
    final bottomPad = 12 + 4 * eased;

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: line.withValues(alpha: (1 - eased) * 0.9))),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          if (eyebrow != null)
            Positioned(
              left: Space.gutter,
              right: 90,
              top: top + 10,
              child: Opacity(
                opacity: eased,
                child: Text(
                  eyebrow!.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: T.caption(color: ink2, weight: 700).copyWith(letterSpacing: 0.8),
                ),
              ),
            ),
          Positioned(
            left: left,
            right: 96,
            bottom: bottomPad,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: T.largeTitle(color: ink).copyWith(fontSize: fontSize),
            ),
          ),
          if (canPop)
            Positioned(
              left: 4,
              top: top,
              height: kToolbarHeight,
              child: const BackButton(),
            ),
          Positioned(
            right: Space.s,
            top: top,
            height: kToolbarHeight,
            child: Row(children: actions),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TitleHeader old) =>
      old.title != title || old.eyebrow != eyebrow || old.canPop != canPop || old.background != background;
}
