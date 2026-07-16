import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../data/stores.dart';
import 'gis_data.dart';

/// Interactive barangay map — Flutter port of the web's custom-drawn
/// GIS map (js/gis-map.js), view + pins only (no editing tools).
///
/// Layers, back to front, with the web stylesheet's colors:
/// boundary fill → vegetation → water → roads → buildings →
/// tagged buildings (category colors) → report pins.
///
/// Modes:
///  • view (default): shows [IncidentStore] pins; tapping a pin calls
///    [onPinTap] with the report, tapping a tagged building calls
///    [onTaggedBuildingTap] with its tag.
///  • pick ([onPick] != null): tapping anywhere drops a pin and reports
///    its normalized (0..1) position — the incident modal's pin-picker.
class GisMapView extends StatefulWidget {
  const GisMapView({
    super.key,
    this.onPick,
    this.onPinTap,
    this.onTaggedBuildingTap,
    this.focusPoint,
    this.showReportPins = true,
  });

  /// Pick mode: called with the normalized tap position.
  final ValueChanged<Offset>? onPick;

  /// View mode: called when an incident pin is tapped.
  final ValueChanged<IncidentReport>? onPinTap;

  /// View mode: called when a tagged building footprint is tapped.
  final ValueChanged<BuildingTag>? onTaggedBuildingTap;

  /// Normalized point to center on at (2×) zoom when the map opens —
  /// used by the blotter's "View on Map".
  final Offset? focusPoint;

  final bool showReportPins;

  @override
  State<GisMapView> createState() => _GisMapViewState();
}

class _GisMapViewState extends State<GisMapView> {
  final _controller = TransformationController();
  Offset? _picked; // normalized
  bool _framed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fit the boundary to the viewport (the web's GIS_FIT_MARGIN view);
  /// optionally zoom in on [widget.focusPoint].
  void _frame(GisMapData data, Size viewport) {
    if (_framed || viewport.isEmpty) return;
    _framed = true;
    final fit = math.min(
        viewport.width / data.size.width, viewport.height / data.size.height);
    var scale = fit;
    var offset = Offset(
      (viewport.width - data.size.width * fit) / 2,
      (viewport.height - data.size.height * fit) / 2,
    );
    final focus = widget.focusPoint;
    if (focus != null) {
      scale = fit * 2.5;
      final target = Offset(
          focus.dx * data.size.width, focus.dy * data.size.height);
      offset = Offset(
        viewport.width / 2 - target.dx * scale,
        viewport.height / 2 - target.dy * scale,
      );
    }
    // T·S — scale the scene, then place it: entries set directly to
    // stay compatible across vector_math versions.
    _controller.value = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, offset.dx)
      ..setEntry(1, 3, offset.dy);
  }

  void _handleTap(GisMapData data, Offset scenePoint) {
    final normalized = Offset(
      (scenePoint.dx / data.size.width).clamp(0.0, 1.0),
      (scenePoint.dy / data.size.height).clamp(0.0, 1.0),
    );
    if (widget.onPick != null) {
      setState(() => _picked = normalized);
      widget.onPick!(normalized);
      return;
    }
    if (widget.onPinTap != null && widget.showReportPins) {
      // Hit-test existing report pins (~18 map units at current zoom).
      final scale = _controller.value.getMaxScaleOnAxis();
      final threshold = 22 / scale;
      for (final r in IncidentStore.instance.all) {
        final p = r.mapPoint;
        if (p == null) continue;
        final pinPos =
            Offset(p.dx * data.size.width, p.dy * data.size.height);
        if ((pinPos - scenePoint).distance <= threshold) {
          widget.onPinTap!(r);
          return;
        }
      }
    }
    // Then tagged buildings — tapping a colored footprint opens its tag.
    final onBuilding = widget.onTaggedBuildingTap;
    if (onBuilding == null) return;
    final state = GisStateStore.instance;
    for (final entry in state.buildingTags.entries) {
      if (entry.value.type.isEmpty) continue;
      final path = _taggedBuildingPath(data, state, entry.key);
      if (path != null && path.contains(scenePoint)) {
        onBuilding(entry.value);
        return;
      }
    }
  }

  /// Footprint for a tagged building id: an OSM building from the base
  /// layer, or a custom-drawn one ('c<id>') projected from the API state.
  static Path? _taggedBuildingPath(
      GisMapData data, GisStateStore state, String key) {
    final base = data.buildingPathById[key];
    if (base != null) return base;
    if (!key.startsWith('c')) return null;
    for (final b in state.customBuildings) {
      if (b.tagKey != key || b.ring.length < 3) continue;
      return Path()
        ..addPolygon(
            [for (final (lng, lat) in b.ring) data.projectLonLat(lng, lat)],
            true);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showReportPins) IncidentStore.instance.ensureLoaded();
    // Tagged buildings (government / business / households) come from the
    // shared DB — same tags the web MIS map edits.
    GisStateStore.instance.ensureLoaded();
    return FutureBuilder<GisMapData>(
      future: GisMapData.load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Map data failed to load.\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.inkMuted),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.gold));
        }
        final data = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final viewport =
                Size(constraints.maxWidth, constraints.maxHeight);
            _frame(data, viewport);
            final fit = math.min(viewport.width / data.size.width,
                viewport.height / data.size.height);
            return ClipRect(
              child: InteractiveViewer(
                transformationController: _controller,
                constrained: false,
                minScale: fit,
                maxScale: fit * 30,
                boundaryMargin: EdgeInsets.zero,
                child: GestureDetector(
                  onTapUp: (details) =>
                      _handleTap(data, details.localPosition),
                  child: CustomPaint(
                    size: data.size,
                    painter: _GisPainter(
                      data: data,
                      controller: _controller,
                      incidents: IncidentStore.instance,
                      gisState: GisStateStore.instance,
                      showReportPins: widget.showReportPins,
                      picked: _picked,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GisPainter extends CustomPainter {
  _GisPainter({
    required this.data,
    required this.controller,
    required this.incidents,
    required this.gisState,
    required this.showReportPins,
    required this.picked,
  }) : super(repaint: Listenable.merge([controller, incidents, gisState]));

  final GisMapData data;
  final TransformationController controller;
  final IncidentStore incidents;
  final GisStateStore gisState;
  final bool showReportPins;
  final Offset? picked;

  // Web colors (css/system.css .gis-* rules).
  static const _vegetationColors = {
    'farmland': (Color(0x38EAB308), Color(0x66A16207)),
    'farmyard': (Color(0x2ED97706), Color(0x66A16207)),
    'orchard': (Color(0x4784CC16), Color(0x664D7C0F)),
    'meadow': (Color(0x38A3E635), Color(0x594D7C0F)),
    'wood': (Color(0x47158B3D), Color(0x7314532D)),
  };

  // Tagged-building category colors (GIS_BUILDING_TYPE_META /
  // GIS_HOUSEHOLD_SUBCAT_META in js/gis-map.js). Households with a
  // vulnerable classification take the classification's color, same as
  // the web map's gis-cat-* fills.
  static const _buildingTypeColors = {
    'government': Color(0xFF92400E),
    'business': Color(0xFF0891B2),
    'households': Color(0xFF1D4ED8),
  };
  static const _householdSubcatColors = {
    'seniors': Color(0xFFF59E0B),
    'pwd': Color(0xFF8B5CF6),
    'solo-parent': Color(0xFFDB2777),
    'indigent': Color(0xFF0D9488),
  };

  static Color? colorForTag(BuildingTag tag) {
    if (tag.type == 'households' && tag.subcat.isNotEmpty) {
      return _householdSubcatColors[tag.subcat] ??
          _buildingTypeColors['households'];
    }
    return _buildingTypeColors[tag.type];
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Strokes are divided by the current zoom so they stay hairline on
    // screen, like the web's vector-effect: non-scaling-stroke.
    final zoom = controller.value.getMaxScaleOnAxis();
    double px(double logical) => logical / zoom;

    // Page-colored backdrop.
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF6F5F1));

    // Boundary fill (rgba(37,99,235,.08)).
    canvas.drawPath(data.boundary, Paint()..color = const Color(0x142563EB));

    // Vegetation (outside context faded to 35%).
    canvas.drawPath(
        data.vegetationOutside, Paint()..color = const Color(0x0F22C55E));
    for (final entry in data.vegetationByKind.entries) {
      final (fill, stroke) =
          _vegetationColors[entry.key] ?? _vegetationColors['wood']!;
      canvas.drawPath(entry.value, Paint()..color = fill);
      canvas.drawPath(
        entry.value,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px(1)
          ..color = stroke,
      );
    }

    // Water lines (#3b82f6, 2px).
    canvas.drawPath(
      data.water,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = px(2)
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF3B82F6),
    );

    // Roads: service 1.2px #cbd5e1 · local 2px #94a3b8 · major 2.8px #64748b.
    void road(String type, double width, Color color) =>
        canvas.drawPath(
          data.roadsByType[type]!,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = px(width)
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
    road('service', 1.2, const Color(0xFFCBD5E1));
    road('local', 2, const Color(0xFF94A3B8));
    road('major', 2.8, const Color(0xFF64748B));

    // Buildings (rgba(13,27,62,.12) fill / .35 stroke; outside faded).
    canvas.drawPath(
        data.buildingsOutside, Paint()..color = const Color(0x0A0D1B3E));
    canvas.drawPath(data.buildings, Paint()..color = const Color(0x1F0D1B3E));
    canvas.drawPath(
      data.buildings,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = px(1)
        ..color = const Color(0x590D1B3E),
    );

    // Tagged buildings (government / business / households) in their
    // category colors, over the plain footprints — like the web map's
    // .gis-building-tagged + gis-cat-* fills.
    for (final entry in gisState.buildingTags.entries) {
      final tag = entry.value;
      final color = colorForTag(tag);
      if (color == null) continue;
      final path =
          _GisMapViewState._taggedBuildingPath(data, gisState, entry.key);
      if (path == null) continue;
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.55));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px(1.4)
          ..color = color,
      );
    }

    // Custom-drawn buildings without a tag still get a plain footprint.
    for (final b in gisState.customBuildings) {
      if (b.ring.length < 3 || gisState.buildingTags.containsKey(b.tagKey)) {
        continue;
      }
      final path = Path()
        ..addPolygon(
            [for (final (lng, lat) in b.ring) data.projectLonLat(lng, lat)],
            true);
      canvas.drawPath(path, Paint()..color = const Color(0x1F0D1B3E));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px(1)
          ..color = const Color(0x590D1B3E),
      );
    }

    // Boundary outline on top (navy, 2px).
    canvas.drawPath(
      data.boundary,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = px(2)
        ..color = AppColors.navy,
    );

    // Report pins (constant on-screen size).
    if (showReportPins) {
      for (final r in incidents.all) {
        final p = r.mapPoint;
        if (p == null) continue;
        _drawPin(
          canvas,
          Offset(p.dx * size.width, p.dy * size.height),
          zoom,
          r.resolved ? const Color(0xFF16A34A) : AppColors.flagRed,
        );
      }
    }

    // Picked location (pick mode).
    if (picked != null) {
      _drawPin(
        canvas,
        Offset(picked!.dx * size.width, picked!.dy * size.height),
        zoom,
        AppColors.royalBlue,
      );
    }
  }

  /// Teardrop marker anchored at [tip]; sized in screen pixels.
  void _drawPin(Canvas canvas, Offset tip, double zoom, Color color) {
    final r = 9 / zoom; // head radius
    final h = 24 / zoom; // total height
    final head = tip - Offset(0, h - r);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
          head.dx - r, head.dy + r * 0.9, head.dx - r, head.dy)
      ..arcTo(Rect.fromCircle(center: head, radius: r), math.pi, math.pi,
          false)
      ..quadraticBezierTo(
          head.dx + r, head.dy + r * 0.9, tip.dx, tip.dy)
      ..close();
    canvas.drawShadow(path, Colors.black45, 2 / zoom, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 / zoom
        ..color = Colors.white,
    );
    canvas.drawCircle(head, r * 0.38, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _GisPainter old) =>
      old.data != data || old.picked != picked ||
      old.showReportPins != showReportPins;
}
