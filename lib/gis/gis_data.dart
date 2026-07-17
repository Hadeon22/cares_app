import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

/// Loads and projects the barangay GeoJSON layers — the same five files
/// the web system renders (js/gis-map.js + data/*.geojson), bundled as
/// Flutter assets. Everything is parsed once and cached.
///
/// Coordinates are projected to "map units": an equirectangular fit of
/// the barangay boundary into a canvas 1000 units wide (latitude scaled
/// by cos(midLat) so shapes keep their real-world aspect), matching the
/// web map's local viewBox approach.
class GisMapData {
  GisMapData._({
    required this.size,
    required this.boundary,
    required this.boundaryPoints,
    required this.buildings,
    required this.buildingsOutside,
    required this.buildingPathById,
    required this.buildingInsideIds,
    required this.vegetationPathById,
    required this.vegetationKindById,
    required this.vegetationInsideIds,
    required this.roadsByType,
    required this.water,
    required this.vegetationByKind,
    required this.vegetationOutside,
    required this.minLon,
    required this.maxLat,
    required this.cosLat,
    required this.scale,
  });

  /// Canvas size in map units (width fixed at 1000).
  final Size size;

  // Projection parameters (see _load) — kept so real-world lat/lng can be
  // converted to/from the normalized (0..1) pin coordinates the map uses.
  final double minLon;
  final double maxLat;
  final double cosLat;
  final double scale;

  /// lat/lng → normalized (0..1) canvas position, or null when the point
  /// falls well outside the rendered area (so far-away pins are skipped
  /// rather than smeared onto the map edge).
  Offset? normalizedFromLatLng(double lat, double lng) {
    final n = Offset(
      (lng - minLon) * cosLat * scale / size.width,
      (maxLat - lat) * scale / size.height,
    );
    if (n.dx < -0.05 || n.dx > 1.05 || n.dy < -0.05 || n.dy > 1.05) {
      return null;
    }
    return n;
  }

  /// Normalized (0..1) canvas position → (lat, lng).
  (double lat, double lng) latLngFromNormalized(Offset n) => (
        maxLat - n.dy * size.height / scale,
        minLon + n.dx * size.width / (cosLat * scale),
      );

  /// lng/lat → map units (the same projection the layers were built with).
  /// Used to draw geometry that arrives at runtime, e.g. custom-drawn
  /// buildings from GET /api/gis/state.
  Offset projectLonLat(double lon, double lat) => Offset(
        (lon - minLon) * cosLat * scale,
        (maxLat - lat) * scale,
      );

  final Path boundary;

  /// Boundary ring in map units — used for hit tests.
  final List<Offset> boundaryPoints;

  final Path buildings;
  final Path buildingsOutside; // context past the border, drawn faded

  /// Every building footprint keyed by its OSM way id — so buildings tagged
  /// in the MIS (government / business / household) can be drawn in their
  /// category color and hit-tested on tap.
  final Map<String, Path> buildingPathById;

  /// Ids of buildings whose centroid is inside the boundary (the rest are
  /// the faded outside-context footprints). Used to rebuild the merged
  /// building layers when web-side deletions (tombstones) hide some.
  final Set<String> buildingInsideIds;

  /// Per-feature vegetation, so web-side "cut" edits can be subtracted from
  /// individual areas: id → footprint / kind / inside-boundary flag.
  final Map<String, Path> vegetationPathById;
  final Map<String, String> vegetationKindById;
  final Set<String> vegetationInsideIds;

  final Map<String, Path> roadsByType; // major / local / service
  final Path water;
  final Map<String, Path> vegetationByKind;
  final Path vegetationOutside;

  static Future<GisMapData>? _future;

  /// Cached loader — safe to call from multiple screens.
  static Future<GisMapData> load() => _future ??= _load();

  static Future<GisMapData> _load() async {
    const prefix = 'assets/gis';
    final boundaryJson = jsonDecode(
        await rootBundle.loadString('$prefix/conde-labak-boundary.geojson'));
    final buildingsJson = jsonDecode(
        await rootBundle.loadString('$prefix/conde-labak-buildings.geojson'));
    final roadsJson = jsonDecode(
        await rootBundle.loadString('$prefix/conde-labak-roads.geojson'));
    final waterJson = jsonDecode(
        await rootBundle.loadString('$prefix/conde-labak-water.geojson'));
    final vegetationJson = jsonDecode(
        await rootBundle.loadString('$prefix/conde-labak-vegetation.geojson'));

    // ── Projection from the boundary's bounding box ──────────
    final boundaryRingLonLat =
        _firstPolygonRing(boundaryJson['features'][0]['geometry']);
    var minLon = double.infinity, maxLon = -double.infinity;
    var minLat = double.infinity, maxLat = -double.infinity;
    for (final p in boundaryRingLonLat) {
      minLon = math.min(minLon, p[0]);
      maxLon = math.max(maxLon, p[0]);
      minLat = math.min(minLat, p[1]);
      maxLat = math.max(maxLat, p[1]);
    }
    // Small margin so context just past the border stays visible.
    final lonPad = (maxLon - minLon) * 0.06;
    final latPad = (maxLat - minLat) * 0.06;
    minLon -= lonPad;
    maxLon += lonPad;
    minLat -= latPad;
    maxLat += latPad;

    final cosLat = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final scale = 1000 / ((maxLon - minLon) * cosLat);
    final size =
        Size(1000, (maxLat - minLat) * scale);

    // Takes `dynamic` so it can map directly over decoded JSON lists.
    Offset project(dynamic lonLat) => Offset(
          ((lonLat[0] as num) - minLon) * cosLat * scale,
          (maxLat - (lonLat[1] as num)) * scale,
        );

    // ── Boundary ─────────────────────────────────────────────
    final boundaryPoints =
        boundaryRingLonLat.map<Offset>(project).toList();
    final boundaryPath = Path()..addPolygon(boundaryPoints, true);

    bool insideBoundary(Offset p) =>
        _pointInPolygon(p, boundaryPoints);

    // ── Buildings (split inside / outside the border) ────────
    final buildings = Path();
    final buildingsOutside = Path();
    final buildingPathById = <String, Path>{};
    final buildingInsideIds = <String>{};
    for (final f in buildingsJson['features'] as List) {
      final ring = _firstPolygonRing(f['geometry']);
      if (ring.isEmpty) continue;
      final pts = ring.map<Offset>(project).toList();
      final inside = insideBoundary(_centroid(pts));
      (inside ? buildings : buildingsOutside).addPolygon(pts, true);
      final id = (f['id'] ?? f['properties']?['id'])?.toString();
      if (id != null) {
        buildingPathById[id] = Path()..addPolygon(pts, true);
        if (inside) buildingInsideIds.add(id);
      }
    }

    // ── Roads, classified like gisRoadTypeForHighway() ───────
    final roadsByType = {
      'major': Path(),
      'local': Path(),
      'service': Path(),
    };
    const majorHighways = {
      'tertiary', 'secondary', 'primary', 'trunk', 'motorway'
    };
    for (final f in roadsJson['features'] as List) {
      final geom = f['geometry'];
      if (geom['type'] != 'LineString') continue;
      final highway = (f['properties']?['highway'] ?? '') as String;
      final type = majorHighways.contains(highway)
          ? 'major'
          : highway == 'service'
              ? 'service'
              : 'local';
      _addPolyline(
          roadsByType[type]!, (geom['coordinates'] as List), project);
    }

    // ── Water ────────────────────────────────────────────────
    final water = Path();
    for (final f in waterJson['features'] as List) {
      final geom = f['geometry'];
      if (geom['type'] == 'LineString') {
        _addPolyline(water, geom['coordinates'] as List, project);
      }
    }

    // ── Vegetation by kind (split inside / outside) ──────────
    final vegetationByKind = <String, Path>{};
    final vegetationOutside = Path();
    final vegetationPathById = <String, Path>{};
    final vegetationKindById = <String, String>{};
    final vegetationInsideIds = <String>{};
    for (final f in vegetationJson['features'] as List) {
      final ring = _firstPolygonRing(f['geometry']);
      if (ring.isEmpty) continue;
      final pts = ring.map<Offset>(project).toList();
      final kind = (f['properties']?['kind'] ?? 'wood') as String;
      final inside = insideBoundary(_centroid(pts));
      if (inside) {
        (vegetationByKind[kind] ??= Path()).addPolygon(pts, true);
      } else {
        vegetationOutside.addPolygon(pts, true);
      }
      final id = (f['id'] ?? f['properties']?['id'])?.toString();
      if (id != null) {
        vegetationPathById[id] = Path()..addPolygon(pts, true);
        vegetationKindById[id] = kind;
        if (inside) vegetationInsideIds.add(id);
      }
    }

    return GisMapData._(
      size: size,
      boundary: boundaryPath,
      boundaryPoints: boundaryPoints,
      buildings: buildings,
      buildingsOutside: buildingsOutside,
      buildingPathById: buildingPathById,
      buildingInsideIds: buildingInsideIds,
      vegetationPathById: vegetationPathById,
      vegetationKindById: vegetationKindById,
      vegetationInsideIds: vegetationInsideIds,
      roadsByType: roadsByType,
      water: water,
      vegetationByKind: vegetationByKind,
      vegetationOutside: vegetationOutside,
      minLon: minLon,
      maxLat: maxLat,
      cosLat: cosLat,
      scale: scale,
    );
  }

  // ── GeoJSON helpers ────────────────────────────────────────

  /// Outer ring of a Polygon (or first polygon of a MultiPolygon).
  static List<dynamic> _firstPolygonRing(Map<String, dynamic> geometry) {
    final coords = geometry['coordinates'] as List;
    switch (geometry['type']) {
      case 'Polygon':
        return coords[0] as List;
      case 'MultiPolygon':
        return coords[0][0] as List;
      default:
        return const [];
    }
  }

  static void _addPolyline(
      Path path, List coords, Offset Function(dynamic) project) {
    if (coords.length < 2) return;
    final first = project(coords[0]);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < coords.length; i++) {
      final p = project(coords[i]);
      path.lineTo(p.dx, p.dy);
    }
  }

  static Offset _centroid(List<Offset> pts) {
    var x = 0.0, y = 0.0;
    for (final p in pts) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / pts.length, y / pts.length);
  }

  /// Ray-casting point-in-polygon test.
  static bool _pointInPolygon(Offset p, List<Offset> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i], b = ring[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx <
              (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }
}
