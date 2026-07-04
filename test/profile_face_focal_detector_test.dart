import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:modelapp/features/profile/profile_face_focal_detector.dart';

void main() {
  test('detects an upper face-like area as cover focal point', () {
    final image = img.Image(width: 320, height: 480);
    img.fill(image, color: img.ColorRgb8(245, 245, 245));

    const centerX = 170;
    const centerY = 135;
    const radiusX = 54;
    const radiusY = 68;
    for (var y = centerY - radiusY; y <= centerY + radiusY; y++) {
      for (var x = centerX - radiusX; x <= centerX + radiusX; x++) {
        final dx = (x - centerX) / radiusX;
        final dy = (y - centerY) / radiusY;
        if (dx * dx + dy * dy <= 1) {
          image.setPixelRgb(x, y, 230, 170, 140);
        }
      }
    }

    final bytes = Uint8List.fromList(img.encodeJpg(image));
    final focal = const ProfileFaceFocalDetector().detectFromBytes(bytes);

    expect(focal, isNotNull);
    expect(focal!.x, greaterThan(0));
    expect(focal.y, lessThan(-0.25));
  });

  test('returns null when no face-like area is present', () {
    final image = img.Image(width: 320, height: 480);
    img.fill(image, color: img.ColorRgb8(240, 240, 240));

    final bytes = Uint8List.fromList(img.encodePng(image));
    final focal = const ProfileFaceFocalDetector().detectFromBytes(bytes);

    expect(focal, isNull);
  });
}
