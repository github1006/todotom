import 'package:flutter_test/flutter_test.dart';
import 'package:todotom/utils/date_only.dart';

void main() {
  test('format muestra día/mes/año', () {
    expect(DateOnly.format(DateTime(2026, 9, 30)), '30/09/2026');
  });

  test('toStorage y fromStorage conservan el día', () {
    final date = DateTime(2026, 3, 5, 18, 45);
    final stored = DateOnly.toStorage(date);
    final restored = DateOnly.fromStorage(stored);
    expect(restored.year, 2026);
    expect(restored.month, 3);
    expect(restored.day, 5);
  });
}
