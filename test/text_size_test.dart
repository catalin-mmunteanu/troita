import 'package:flutter_test/flutter_test.dart';
import 'package:troita/app/text_size.dart';

void main() {
  test('text size snaps to its steps and stays in range', () {
    expect(TextSize.clamp(1.0), closeTo(1.0, 1e-9));
    expect(TextSize.clamp(1.0 + 0.15), closeTo(1.15, 1e-9));
    expect(TextSize.clamp(1.2), closeTo(1.15, 1e-9));
    expect(TextSize.clamp(3), closeTo(TextSize.max, 1e-9));
    expect(TextSize.clamp(0.1), closeTo(TextSize.min, 1e-9));
    // The old Lecturi size could be 1.75; it lands on the largest step.
    expect(TextSize.clamp(1.75), closeTo(1.6, 1e-9));
  });

  test('labels', () {
    expect(TextSize.label(1), 'Normal');
    expect(TextSize.label(1.3), '130 %');
  });
}
