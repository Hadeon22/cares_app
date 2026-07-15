import 'package:flutter_test/flutter_test.dart';

import 'package:cares_app/gis/gis_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GeoJSON assets load and project into non-empty layers', () async {
    final data = await GisMapData.load();

    // Canvas is 1000 map units wide; height follows the boundary's aspect.
    expect(data.size.width, 1000);
    expect(data.size.height, greaterThan(0));

    expect(data.boundaryPoints.length, greaterThan(3));
    expect(data.boundary.getBounds().isEmpty, isFalse);
    expect(data.buildings.getBounds().isEmpty, isFalse);
    expect(data.water.getBounds().isEmpty, isFalse);
    expect(data.vegetationByKind, isNotEmpty);
    // All three road classes exist in the dataset.
    for (final type in ['major', 'local', 'service']) {
      expect(data.roadsByType[type]!.getBounds().isEmpty, isFalse,
          reason: '$type roads should not be empty');
    }

    // Every boundary point lands inside the padded canvas.
    for (final p in data.boundaryPoints) {
      expect(p.dx, inInclusiveRange(0, data.size.width));
      expect(p.dy, inInclusiveRange(0, data.size.height));
    }
  });
}
