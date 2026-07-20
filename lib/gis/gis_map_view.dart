import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../data/stores.dart';
import 'gis_data.dart';

/// Report marker colors — resident-filed vs official-filed (same scheme as
/// the web map and its legend).
const Color kReportResidentColor = Color(0xFF15803D);
const Color kReportOfficialColor = Color(0xFF1D4ED8);

/// Strokes and markers don't hold a constant screen size across the zoom
/// range: at the fitted view that makes the whole barangay a mat of heavy
/// lines and oversized pins, and zoomed right in it leaves them looking
/// undersized against the detail. Both instead grow with the user's zoom
/// ([userZoom], 1 = fitted view) at a damped rate, so they read light when
/// zoomed out and substantial when zoomed in.

/// Multiplier on every layer's logical stroke width.
double _strokeScale(double userZoom) =>
    (0.55 * math.sqrt(userZoom)).clamp(0.55, 1.8);

/// On-screen size (logical px) of a report marker's glyph.
double _markerScreenPx(double userZoom) =>
    (10 * math.pow(userZoom, 0.45)).toDouble().clamp(10.0, 30.0);

/// Layer visibility + building filters — the mobile version of the web
/// map's filter row (Map Layers toggles, Building Type, and Household
/// Classification dropdowns in js/gis-map.js).
///
/// Like the web map: while a building filter is active, untagged
/// footprints are hidden and only matching tagged buildings stay visible.
class GisMapFilters {
  const GisMapFilters({
    this.showVegetation = true,
    this.showWater = true,
    this.showRoads = true,
    this.showBuildings = true,
    this.showHazard = true,
    this.showConstruction = true,
    this.showReports = true,
    this.buildingType,
    this.householdClass,
  });

  final bool showVegetation;
  final bool showWater;
  final bool showRoads;
  final bool showBuildings;
  final bool showHazard;
  final bool showConstruction;
  final bool showReports;

  /// 'government' | 'business' | 'households' (null = all).
  final String? buildingType;

  /// 'seniors' | 'pwd' | 'solo-parent' | 'indigent' (null = all).
  final String? householdClass;

  /// A building filter is active — untagged footprints hide (web parity).
  bool get filteringBuildings => buildingType != null || householdClass != null;

  /// True when every map layer is visible (nothing toggled off) — lets the
  /// Map Layers button show an "active filter" state.
  bool get allLayersOn =>
      showVegetation &&
      showWater &&
      showRoads &&
      showBuildings &&
      showHazard &&
      showConstruction &&
      showReports;

  /// Whether a tagged building passes the two dropdown filters (they
  /// combine, same as the web map).
  bool tagMatches(BuildingTag tag) {
    if (buildingType != null && tag.type != buildingType) return false;
    if (householdClass != null &&
        !(tag.type == 'households' && tag.subcat == householdClass)) {
      return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is GisMapFilters &&
      other.showVegetation == showVegetation &&
      other.showWater == showWater &&
      other.showRoads == showRoads &&
      other.showBuildings == showBuildings &&
      other.showHazard == showHazard &&
      other.showConstruction == showConstruction &&
      other.showReports == showReports &&
      other.buildingType == buildingType &&
      other.householdClass == householdClass;

  @override
  int get hashCode => Object.hash(
      showVegetation,
      showWater,
      showRoads,
      showBuildings,
      showHazard,
      showConstruction,
      showReports,
      buildingType,
      householdClass);
}

/// Report type → marker icon, shared by the map markers and the Recent
/// Community Reports feed. This set is the reference — the web map's
/// GIS_REPORT_TYPE_META glyphs are drawn to match these.
const Map<String, IconData> kReportTypeIcons = {
  'noise': Icons.volume_up,
  'dispute': Icons.gavel,
  'altercation': Icons.front_hand,
  'theft': Icons.local_police,
  'vandalism': Icons.format_paint,
  'domestic': Icons.home,
  'flooding': Icons.water,
  'vehicular': Icons.directions_car,
  'fire': Icons.local_fire_department,
  'medical': Icons.medical_services,
  'other': Icons.priority_high,
};

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
    this.onFeatureTap,
    this.focusPoint,
    this.focusRequest,
    this.typeFilter,
    this.filters = const GisMapFilters(),
    this.showReportPins = true,
    this.initialPick,
  });

  /// Pick mode: called with the normalized tap position.
  final ValueChanged<Offset>? onPick;

  /// Pick mode: a normalized point to show as the dropped pin when the map
  /// first appears (so an already-chosen location is drawn, not just tapped).
  final Offset? initialPick;

  /// View mode: called when an incident pin is tapped.
  final ValueChanged<IncidentReport>? onPinTap;

  /// View mode: called when a tagged building footprint is tapped.
  final ValueChanged<BuildingTag>? onTaggedBuildingTap;

  /// View mode: called when a staff-drawn feature (hazard ping, accident
  /// marker, construction area) is tapped.
  final ValueChanged<MapFeatureInfo>? onFeatureTap;

  /// Normalized point to center on at (2×) zoom when the map opens —
  /// used by the blotter's "View on Map".
  final Offset? focusPoint;

  /// Live focus channel: set a normalized point on this notifier and the
  /// map flies to it (the report feed's view-on-map button).
  final ValueNotifier<Offset?>? focusRequest;

  /// When set, only report markers of this type key are shown/tappable
  /// (the filter dropdown above the map).
  final String? typeFilter;

  /// Layer toggles + building filters (the web map's filter row).
  final GisMapFilters filters;

  final bool showReportPins;

  @override
  State<GisMapView> createState() => _GisMapViewState();
}

class _GisMapViewState extends State<GisMapView> {
  /// The whole barangay is fitted into [_fitMargin] of the viewport by the
  /// painter itself, so the map opens with the full boundary in view (with
  /// breathing room) at the InteractiveViewer's identity transform — no
  /// externally-set initial transform to fight. The controller then only
  /// carries the *user's* zoom/pan on top of that fitted base.
  static const double _fitMargin = 0.9;

  /// How far past the fitted view the user may zoom in (identity = fitted).
  static const double _maxUserZoom = 60;

  final _controller = TransformationController();
  late Offset? _picked = widget.initialPick; // normalized

  /// One-time apply of [GisMapView.focusPoint] (blotter "View on Map").
  bool _focusApplied = false;

  // Captured on every layout so the transform clamp and programmatic
  // focusing can work outside build().
  GisMapData? _data;
  Size? _viewport;
  bool _clamping = false;

  /// Scene→viewport fit scale: shrinks the full map ([data.size]) into
  /// [_fitMargin] of [viewport]. The painter, the clamp, and hit-testing
  /// all derive their geometry from this so they stay in lock-step.
  double _fitScale(GisMapData data, Size viewport) =>
      _fitMargin *
      math.min(viewport.width / data.size.width,
          viewport.height / data.size.height);

  /// Top-left offset that centers the fitted map in the viewport.
  Offset _fitOffset(GisMapData data, Size viewport, double fit) => Offset(
        (viewport.width - data.size.width * fit) / 2,
        (viewport.height - data.size.height * fit) / 2,
      );

  @override
  void initState() {
    super.initState();
    // InteractiveViewer's own minScale doesn't reliably stop pinch
    // zoom-out with an externally-set transform, so clamp every change:
    // never below the fitted view, never panned past the map edges.
    _controller.addListener(_clampTransform);
    widget.focusRequest?.addListener(_onFocusRequest);
  }

  @override
  void dispose() {
    widget.focusRequest?.removeListener(_onFocusRequest);
    _controller.dispose();
    super.dispose();
  }

  void _clampTransform() {
    if (_clamping) return;
    final viewport = _viewport;
    if (viewport == null || viewport.isEmpty) return;
    // The controller now holds only the user's zoom/pan over the fitted
    // base: identity = the fitted whole-barangay view. Keep zoom in
    // [1, max] and never let the fitted content be panned off the viewport.
    final m = _controller.value;
    final scale = m.getMaxScaleOnAxis();
    final s = scale.clamp(1.0, _maxUserZoom);
    final w = viewport.width * s;
    final h = viewport.height * s;
    final tx = m.storage[12];
    final ty = m.storage[13];
    final nx = w <= viewport.width + 0.5
        ? (viewport.width - w) / 2
        : tx.clamp(viewport.width - w, 0.0);
    final ny = h <= viewport.height + 0.5
        ? (viewport.height - h) / 2
        : ty.clamp(viewport.height - h, 0.0);
    if (s != scale || (nx - tx).abs() > 0.5 || (ny - ty).abs() > 0.5) {
      _clamping = true;
      _controller.value = Matrix4.identity()
        ..setEntry(0, 0, s)
        ..setEntry(1, 1, s)
        ..setEntry(0, 3, nx)
        ..setEntry(1, 3, ny);
      _clamping = false;
    }
  }

  /// Fly to a normalized scene point at [userZoom]× the fitted view. The
  /// point is first mapped into fitted-viewport space (where identity =
  /// the fitted whole map), then the user transform zooms/centers on it.
  void _flyTo(Offset normalized, double userZoom) {
    final data = _data;
    final viewport = _viewport;
    if (data == null || viewport == null || viewport.isEmpty) return;
    final fit = _fitScale(data, viewport);
    final off = _fitOffset(data, viewport, fit);
    // Target in fitted-viewport coordinates (userZoom == 1).
    final fx = off.dx + normalized.dx * data.size.width * fit;
    final fy = off.dy + normalized.dy * data.size.height * fit;
    _controller.value = Matrix4.identity()
      ..setEntry(0, 0, userZoom)
      ..setEntry(1, 1, userZoom)
      ..setEntry(0, 3, viewport.width / 2 - fx * userZoom)
      ..setEntry(1, 3, viewport.height / 2 - fy * userZoom);
  }

  /// Feed's "view on map": fly to the requested normalized point.
  void _onFocusRequest() {
    final focus = widget.focusRequest?.value;
    if (focus == null) return;
    _flyTo(focus, 2.5);
  }

  /// Scene point (in [data.size] coordinates) for a viewport-space tap,
  /// undoing the painter's fit transform and the user's zoom/pan.
  Offset _sceneFromLocal(GisMapData data, Size viewport, Offset local) {
    // InteractiveViewer already maps the screen tap into child (viewport)
    // space, so [local] is pre-fit. Undo the fit transform only.
    final fit = _fitScale(data, viewport);
    final off = _fitOffset(data, viewport, fit);
    return Offset((local.dx - off.dx) / fit, (local.dy - off.dy) / fit);
  }

  void _handleTap(GisMapData data, Size viewport, Offset local) {
    final scenePoint = _sceneFromLocal(data, viewport, local);
    final normalized = Offset(
      (scenePoint.dx / data.size.width).clamp(0.0, 1.0),
      (scenePoint.dy / data.size.height).clamp(0.0, 1.0),
    );
    if (widget.onPick != null) {
      setState(() => _picked = normalized);
      widget.onPick!(normalized);
      return;
    }
    final filters = widget.filters;
    if (widget.onPinTap != null &&
        widget.showReportPins &&
        filters.showReports) {
      // Hit-test existing report markers. The drawn glyph is zoom-dependent
      // ([_markerScreenPx]), so derive the radius from the same curve, with a
      // floor that keeps small zoomed-out markers tappable. Converted into
      // scene units via the full scene→screen scale (fit × the user's zoom).
      final fit = _fitScale(data, viewport);
      final userZoom = _controller.value.getMaxScaleOnAxis();
      final zoom = fit * userZoom;
      final threshold = math.max(_markerScreenPx(userZoom) * 0.9, 18) / zoom;
      for (final r in IncidentStore.instance.all) {
        final p = r.mapPoint;
        // Resolved reports aren't drawn (web parity), so don't hit-test
        // them — nor markers hidden by the type filter.
        if (p == null || r.resolved) continue;
        if (widget.typeFilter != null && r.typeKey != widget.typeFilter) {
          continue;
        }
        final pinPos = Offset(p.dx * data.size.width, p.dy * data.size.height);
        if ((pinPos - scenePoint).distance <= threshold) {
          widget.onPinTap!(r);
          return;
        }
      }
    }
    final state = GisStateStore.instance;
    final onFeature = widget.onFeatureTap;
    if (onFeature != null) {
      // Hazard pings (their radius is in map units).
      for (final h in filters.showHazard ? state.hazards : <HazardZone>[]) {
        final pos = data.projectLonLat(h.lng, h.lat);
        if ((pos - scenePoint).distance <= h.radius) {
          onFeature(MapFeatureInfo(
            title: h.typeLabel,
            badge: h.severity.isEmpty
                ? 'Hazard zone'
                : '${h.severity[0].toUpperCase()}${h.severity.substring(1)} severity',
            body: h.notes,
          ));
          return;
        }
      }
      // Construction areas.
      for (final c in state.construction) {
        if (!filters.showConstruction) break;
        if (c.ring.length < 3) continue;
        final path = Path()
          ..addPolygon(
              [for (final (lng, lat) in c.ring) data.projectLonLat(lng, lat)],
              true);
        if (path.contains(scenePoint)) {
          onFeature(MapFeatureInfo(
            title: c.name.isEmpty ? 'Construction Area' : c.name,
            badge: 'Construction · ${c.statusLabel}',
            body: c.notes,
          ));
          return;
        }
      }
    }
    // Then tagged buildings — tapping a colored footprint opens its tag.
    final onBuilding = widget.onTaggedBuildingTap;
    if (onBuilding == null || !filters.showBuildings) return;
    for (final entry in state.buildingTags.entries) {
      if (entry.value.type.isEmpty) continue;
      if (!filters.tagMatches(entry.value)) continue;
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
            final viewport = Size(constraints.maxWidth, constraints.maxHeight);
            // Kept for the transform clamp + programmatic focus.
            _data = data;
            _viewport = viewport;
            // Blotter "View on Map": zoom to the requested point once the
            // first real layout is in (identity otherwise = fitted view).
            final focus = widget.focusPoint;
            if (focus != null && !_focusApplied) {
              _focusApplied = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _flyTo(focus, 2.5);
              });
            }
            return ClipRect(
              // The painter fits the whole map into the viewport, so the
              // InteractiveViewer starts at identity showing the full
              // barangay and only carries the user's zoom/pan on top.
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1,
                maxScale: _maxUserZoom,
                boundaryMargin: EdgeInsets.zero,
                child: GestureDetector(
                  onTapUp: (details) =>
                      _handleTap(data, viewport, details.localPosition),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _GisPainter(
                      data: data,
                      controller: _controller,
                      incidents: IncidentStore.instance,
                      gisState: GisStateStore.instance,
                      showReportPins: widget.showReportPins,
                      typeFilter: widget.typeFilter,
                      filters: widget.filters,
                      picked: _picked,
                      fitMargin: _fitMargin,
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
    required this.fitMargin,
    this.typeFilter,
    this.filters = const GisMapFilters(),
  }) : super(repaint: Listenable.merge([controller, incidents, gisState]));

  final GisMapData data;
  final TransformationController controller;
  final IncidentStore incidents;
  final GisStateStore gisState;
  final bool showReportPins;
  final Offset? picked;

  /// Fraction of the viewport the fitted map fills (matches the state's
  /// [_GisMapViewState._fitMargin] so the painter and hit-testing agree).
  final double fitMargin;

  /// When set, only report markers of this type key are drawn.
  final String? typeFilter;

  /// Layer visibility + building filters (web filter-row parity).
  final GisMapFilters filters;

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

  // Hazard type colors (GIS_HAZARD_TYPE_META) and severity fill opacities
  // (.gis-hazard-severity-* in css/system.css).
  static const _hazardColors = {
    'flood': Color(0xFF3B82F6),
    'landslide': Color(0xFFB45309),
    'fire': Color(0xFFEF4444),
    'other': Color(0xFFEAB308),
  };
  static const _hazardFillAlpha = {
    'low': 0.18,
    'medium': 0.30,
    'high': 0.45,
    'critical': 0.55,
  };

  // Unified report marker colors: who filed it decides the color (same
  // scheme as the web map).
  static const _pinResident = kReportResidentColor;
  static const _pinOfficial = kReportOfficialColor;

  // ── Derived base layers ─────────────────────────────────────
  // Web-side edits (tombstoned buildings, vegetation cuts) reshape the
  // static base layers. Rebuilding merged paths is O(features), so the
  // result is cached per (map data, state version) and shared by every
  // painter instance.
  static GisMapData? _derivedFor;
  static int _derivedVersion = -1;
  static Path? _derivedBuildings;
  static Path? _derivedBuildingsOutside;
  static Map<String, Path>? _derivedVegByKind;

  void _ensureDerivedLayers() {
    if (_derivedFor == data && _derivedVersion == gisState.version) return;
    _derivedFor = data;
    _derivedVersion = gisState.version;

    // Buildings minus tombstones.
    final hidden = gisState.deletedBuildingIds
        .where(data.buildingPathById.containsKey)
        .toSet();
    if (hidden.isEmpty) {
      _derivedBuildings = data.buildings;
      _derivedBuildingsOutside = data.buildingsOutside;
    } else {
      final inside = Path();
      final outside = Path();
      data.buildingPathById.forEach((id, path) {
        if (hidden.contains(id)) return;
        (data.buildingInsideIds.contains(id) ? inside : outside)
            .addPath(path, Offset.zero);
      });
      _derivedBuildings = inside;
      _derivedBuildingsOutside = outside;
    }

    // Base vegetation minus cut rings (per-feature subtraction).
    final cutIds = gisState.vegetationCuts.keys
        .where(data.vegetationPathById.containsKey)
        .toSet();
    if (cutIds.isEmpty) {
      _derivedVegByKind = data.vegetationByKind;
    } else {
      final byKind = <String, Path>{};
      data.vegetationPathById.forEach((id, path) {
        if (!data.vegetationInsideIds.contains(id)) return;
        final kind = data.vegetationKindById[id] ?? 'wood';
        (byKind[kind] ??= Path()).addPath(
            _applyCuts(path, gisState.vegetationCuts[id]), Offset.zero);
      });
      _derivedVegByKind = byKind;
    }
  }

  /// Subtracts each cut ring from a vegetation footprint.
  Path _applyCuts(Path path, List<List<LngLat>>? cuts) {
    if (cuts == null || cuts.isEmpty) return path;
    var result = path;
    for (final ring in cuts) {
      if (ring.length < 3) continue;
      final cut = Path()
        ..addPolygon(
            [for (final (lng, lat) in ring) data.projectLonLat(lng, lat)],
            true);
      result = Path.combine(PathOperation.difference, result, cut);
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // [size] is the viewport. Fit the whole map ([data.size]) into it and
    // center — this is what makes the map open showing the full barangay,
    // regardless of InteractiveViewer's initial transform. The user's
    // zoom/pan is applied on top of this by the InteractiveViewer.
    final fit = fitMargin *
        math.min(size.width / data.size.width, size.height / data.size.height);
    final offset = Offset(
      (size.width - data.size.width * fit) / 2,
      (size.height - data.size.height * fit) / 2,
    );

    // Rebuild base layers when web-side edits (tombstones / cuts) changed.
    _ensureDerivedLayers();

    // Page-colored backdrop over the whole viewport (drawn before the fit
    // transform so it also fills the letterbox margins).
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFF6F5F1));

    // From here on, draw in scene (data) coordinates.
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(fit);

    // Strokes/markers are divided by the full scene→screen scale (fit ×
    // user zoom) to give them a screen-space size, then scaled by the
    // user's zoom so they lighten when zoomed out and thicken when zoomed in.
    final userZoom = controller.value.getMaxScaleOnAxis();
    final zoom = fit * userZoom;
    final strokeScale = _strokeScale(userZoom);
    double px(double logical) => logical * strokeScale / zoom;

    // Boundary fill (rgba(37,99,235,.08)).
    canvas.drawPath(data.boundary, Paint()..color = const Color(0x142563EB));

    // Vegetation (outside context faded to 35%) — skipped entirely when
    // the Vegetation layer toggle is off.
    if (filters.showVegetation) {
      canvas.drawPath(
          data.vegetationOutside, Paint()..color = const Color(0x0F22C55E));
      for (final entry
          in (_derivedVegByKind ?? data.vegetationByKind).entries) {
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

      // Staff-drawn vegetation from the shared DB, with any cut rings
      // subtracted (same visual language as the base layer).
      for (final v in gisState.customVegetation) {
        if (v.ring.length < 3) continue;
        final path = _applyCuts(
          Path()
            ..addPolygon(
                [for (final (lng, lat) in v.ring) data.projectLonLat(lng, lat)],
                true),
          gisState.vegetationCuts['${v.id}'],
        );
        final (fill, stroke) =
            _vegetationColors[v.kind] ?? _vegetationColors['wood']!;
        canvas.drawPath(path, Paint()..color = fill);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = px(1)
            ..color = stroke,
        );
      }
    }

    // Water lines (#3b82f6, 2px).
    if (filters.showWater) {
      canvas.drawPath(
        data.water,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px(2)
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF3B82F6),
      );
    }

    if (filters.showRoads) {
      // Roads: service 1.2px #cbd5e1 · local 2px #94a3b8 · major 2.8px #64748b.
      void road(String type, double width, Color color) => canvas.drawPath(
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

      // Staff-drawn roads from the shared DB, same three-tier styling.
      const roadStyles = {
        'service': (1.2, Color(0xFFCBD5E1)),
        'local': (2.0, Color(0xFF94A3B8)),
        'major': (2.8, Color(0xFF64748B)),
      };
      for (final r in gisState.customRoads) {
        if (r.points.length < 2) continue;
        final (width, color) = roadStyles[r.roadType] ?? roadStyles['local']!;
        final path = Path();
        final first = data.projectLonLat(r.points.first.$1, r.points.first.$2);
        path.moveTo(first.dx, first.dy);
        for (final (lng, lat) in r.points.skip(1)) {
          final p = data.projectLonLat(lng, lat);
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = px(width)
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
      }
    }

    // Buildings (rgba(13,27,62,.12) fill / .35 stroke; outside faded),
    // minus any tombstoned by the web map's Edit Mode. Web parity: while a
    // building-type/classification filter is active, plain (untagged)
    // footprints are hidden so only matching tagged buildings remain.
    if (filters.showBuildings && !filters.filteringBuildings) {
      final buildingsIn = _derivedBuildings ?? data.buildings;
      final buildingsOut = _derivedBuildingsOutside ?? data.buildingsOutside;
      canvas.drawPath(buildingsOut, Paint()..color = const Color(0x0A0D1B3E));
      canvas.drawPath(buildingsIn, Paint()..color = const Color(0x1F0D1B3E));
      canvas.drawPath(
        buildingsIn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px(1)
          ..color = const Color(0x590D1B3E),
      );
    }

    // Tagged buildings (government / business / households) in their
    // category colors, over the plain footprints — like the web map's
    // .gis-building-tagged + gis-cat-* fills.
    for (final entry in gisState.buildingTags.entries) {
      if (!filters.showBuildings) break;
      if (gisState.deletedBuildingIds.contains(entry.key)) continue;
      final tag = entry.value;
      if (!filters.tagMatches(tag)) continue;
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

    // Custom-drawn buildings without a tag still get a plain footprint
    // (hidden, like all untagged footprints, while a building filter is on).
    for (final b in gisState.customBuildings) {
      if (!filters.showBuildings || filters.filteringBuildings) break;
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

    // Construction areas (rgba(234,179,8,.15) fill, amber outline).
    for (final c in gisState.construction) {
      if (!filters.showConstruction) break;
      if (c.ring.length < 3) continue;
      final path = Path()
        ..addPolygon(
            [for (final (lng, lat) in c.ring) data.projectLonLat(lng, lat)],
            true);
      canvas.drawPath(path, Paint()..color = const Color(0x26EAB308));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px(2)
          ..color = const Color(0xFFEAB308),
      );
    }

    // Hazard pings — translucent circles sized in map units, tinted by
    // hazard type, opacity by severity (web .gis-hazard-* styling).
    for (final h in gisState.hazards) {
      if (!filters.showHazard) break;
      final center = data.projectLonLat(h.lng, h.lat);
      final color = _hazardColors[h.hazardType] ?? _hazardColors['other']!;
      final alpha = _hazardFillAlpha[h.severity] ?? 0.25;
      canvas.drawCircle(
          center, h.radius, Paint()..color = color.withValues(alpha: alpha));
      canvas.drawCircle(
        center,
        h.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = px(1.6)
          ..color = color,
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

    // Report markers (constant on-screen size). One unified marker for
    // concerns and accidents: the report type's icon drawn bare on a
    // transparent background, colored by who filed it (resident green /
    // official navy). Resolved reports drop off the map — same as the web —
    // and live on in the feed/history.
    if (showReportPins && filters.showReports) {
      for (final r in incidents.all) {
        final p = r.mapPoint;
        if (p == null || r.resolved) continue;
        if (typeFilter != null && r.typeKey != typeFilter) continue;
        _drawTypeMarker(
          canvas,
          Offset(p.dx * data.size.width, p.dy * data.size.height),
          zoom,
          userZoom,
          r.isOfficial ? _pinOfficial : _pinResident,
          kReportTypeIcons[r.typeKey] ?? Icons.priority_high,
        );
      }
    }

    // Picked location (pick mode).
    if (picked != null) {
      _drawPin(
        canvas,
        Offset(picked!.dx * data.size.width, picked!.dy * data.size.height),
        zoom,
        AppColors.royalBlue,
      );
    }

    canvas.restore();
  }

  /// Bare report-type icon centered on the reported location — transparent
  /// background, sized in screen pixels by [_markerScreenPx] so it stays
  /// unobtrusive at the fitted view and reads clearly zoomed in.
  void _drawTypeMarker(Canvas canvas, Offset center, double zoom,
      double userZoom, Color color, IconData icon) {
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: _markerScreenPx(userZoom) / zoom,
          fontFamily: icon.fontFamily,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Teardrop marker anchored at [tip]; sized in screen pixels. When [icon]
  /// is given it is drawn white in the pin head (the report type glyph);
  /// otherwise the classic white dot is used.
  void _drawPin(Canvas canvas, Offset tip, double zoom, Color color,
      {IconData? icon}) {
    final r = 9 / zoom; // head radius
    final h = 24 / zoom; // total height
    final head = tip - Offset(0, h - r);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(head.dx - r, head.dy + r * 0.9, head.dx - r, head.dy)
      ..arcTo(Rect.fromCircle(center: head, radius: r), math.pi, math.pi, false)
      ..quadraticBezierTo(head.dx + r, head.dy + r * 0.9, tip.dx, tip.dy)
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
    if (icon == null) {
      canvas.drawCircle(head, r * 0.38, Paint()..color = Colors.white);
    } else {
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: r * 1.35,
            fontFamily: icon.fontFamily,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, head - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _GisPainter old) =>
      old.data != data ||
      old.picked != picked ||
      old.showReportPins != showReportPins ||
      old.typeFilter != typeFilter ||
      old.fitMargin != fitMargin ||
      old.filters != filters;
}
