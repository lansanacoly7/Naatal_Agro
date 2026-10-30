import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../ui/appearance.dart';
import '../../ui/map_tiles.dart';
import '../../ui/ui.dart';
import 'market_page_data.dart';

/// Le trajet tracé sur la carte entre la position de la personne et le marché, en voiture ou à pied.
class MarketRoutePage extends StatefulWidget {
  const MarketRoutePage({super.key, required this.market, required this.route, required this.origin});

  final MarketOverview market;
  final MarketRoute route;
  final LatLng origin;

  @override
  State<MarketRoutePage> createState() => _MarketRoutePageState();
}

class _MarketRoutePageState extends State<MarketRoutePage> {
  late bool _car = widget.route.car != null;

  RouteMode? get _mode => _car ? widget.route.car : widget.route.foot;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final mode = _mode;
    final line = (mode?.points.isNotEmpty ?? false) ? mode!.points : [widget.origin, widget.route.destination];
    final bounds = LatLngBounds.fromPoints([...line, widget.origin, widget.route.destination]);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text(widget.market.name, style: T.title(color: c.ink)),
      ),
      body: Column(
        children: [
          Expanded(
            // La carte reste claire, même en mode sombre
            child: LightOnly(
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.fromLTRB(48, 80, 48, 80), maxZoom: 16),
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                    ),
                    children: [
                      const NaatalTileLayer(),
                      PolylineLayer(
                        polylines: [
                          Polyline(points: line, strokeWidth: 9, color: Colors.white, borderStrokeWidth: 0),
                          Polyline(
                            points: line,
                            strokeWidth: 5,
                            color: _car ? NaatalColors.light.domainMeteo : NaatalColors.light.accent,
                            pattern: _car ? const StrokePattern.solid() : StrokePattern.dashed(segments: const [10, 8]),
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.origin,
                            width: UserAvatarPin.markerWidth,
                            height: UserAvatarPin.markerHeight,
                            alignment: Alignment.topCenter,
                            child: const UserAvatarPin(),
                          ),
                          Marker(
                            point: widget.route.destination,
                            width: 56,
                            height: MapPin.heightFor(44),
                            alignment: Alignment.topCenter,
                            child: MapPin(color: NaatalColors.light.domainMarches, child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const MapCredit(),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(Space.gutter, Space.l, Space.gutter, MediaQuery.paddingOf(context).bottom + Space.l),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _ModeButton(icon: Icons.directions_car_rounded, label: 'Voiture', selected: _car, enabled: widget.route.car != null, onTap: () => setState(() => _car = true))),
                    const SizedBox(width: Space.s),
                    Expanded(child: _ModeButton(icon: Icons.directions_walk_rounded, label: 'À pied', selected: !_car, enabled: widget.route.foot != null, onTap: () => setState(() => _car = false))),
                  ],
                ),
                const SizedBox(height: Space.m),
                Text(
                  mode == null ? 'Trajet indisponible' : durationWords(mode.minutes),
                  style: T.largeTitle(color: c.ink).copyWith(fontSize: 34),
                ),
                Text(
                  mode == null ? '' : '${Fmt.decimal(mode.distanceKm)} km · ${_car ? 'en voiture' : 'à pied'}',
                  style: T.body(color: c.ink2, weight: 600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.icon, required this.label, required this.selected, required this.enabled, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = !enabled ? c.ink2.withValues(alpha: 0.5) : (selected ? c.onAccent : c.ink);
    return PressScale(
      onTap: enabled ? onTap : null,
      semanticLabel: label,
      child: Container(
        height: Hit.min,
        decoration: BoxDecoration(
          color: selected && enabled ? c.accent : c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 24),
            const SizedBox(width: Space.s),
            Text(label, style: T.body(color: fg, weight: 800)),
          ],
        ),
      ),
    );
  }
}
