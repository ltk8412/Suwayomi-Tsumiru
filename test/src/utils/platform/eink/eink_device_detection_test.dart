import 'package:flutter_test/flutter_test.dart';
import 'package:tsumiru/src/utils/platform/eink/eink_device_detection.dart';

void main() {
  group('detectEinkDevice', () {
    test('detects Onyx Boox devices', () {
      expect(
        detectEinkDevice(model: 'Nova Air C', manufacturer: 'ONYX'),
        isTrue,
      );
      expect(detectEinkDevice(model: 'Leaf3', manufacturer: 'Boox'), isTrue);
    });

    test('detects Meebook M103', () {
      expect(detectEinkDevice(model: 'M103', manufacturer: 'Meebook'), isTrue);
    });

    test('detects Hisense A-series', () {
      expect(detectEinkDevice(model: 'A5', manufacturer: 'Hisense'), isTrue);
      expect(detectEinkDevice(model: 'A9', manufacturer: 'Hisense'), isTrue);
    });

    test('detects by soc manufacturer', () {
      expect(
        detectEinkDevice(
          model: 'unknown',
          manufacturer: 'unknown',
          socManufacturer: 'onyx',
        ),
        isTrue,
      );
    });

    test('detects other e-ink vendors', () {
      expect(detectEinkDevice(model: 'B751', manufacturer: 'Bigme'), isTrue);
      expect(detectEinkDevice(model: 'M6', manufacturer: 'Meebook'), isTrue);
    });

    test('ignores regular phones and tablets', () {
      expect(
        detectEinkDevice(model: 'Pixel 7', manufacturer: 'Google'),
        isFalse,
      );
      expect(
        detectEinkDevice(model: 'SM-X700', manufacturer: 'samsung'),
        isFalse,
      );
      expect(
        detectEinkDevice(model: 'SM-A500F', manufacturer: 'samsung'),
        isFalse,
      );
    });
  });
}
