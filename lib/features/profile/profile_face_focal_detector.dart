import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

const ({double x, double y}) kDefaultCoverFocal = (x: 0, y: -0.72);

class ProfileFaceFocalDetector {
  const ProfileFaceFocalDetector();

  Future<({double x, double y})?> detectFromXFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      return detectFromBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  Future<({double x, double y})?> detectFromUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(cleanUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return detectFromBytes(response.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  ({double x, double y})? detectFromBytes(Uint8List bytes) {
    if (bytes.isEmpty) return null;
    final decoded = img.decodeImage(bytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      return null;
    }

    final oriented = img.bakeOrientation(decoded);
    final source = _resizeForScan(oriented);
    final width = source.width;
    final height = source.height;
    if (width <= 0 || height <= 0) return null;

    final skinMask = Uint8List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = source.getPixel(x, y);
        if (_isSkinLike(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt())) {
          skinMask[y * width + x] = 1;
        }
      }
    }

    final component = _bestComponent(skinMask, width, height);
    if (component == null) return null;

    final centerX = component.centerX / width;
    final centerY = component.centerY / height;
    final focalX = ((centerX - 0.5) * 2).clamp(-1.0, 1.0).toDouble();
    final focalY = ((centerY - 0.5) * 2).clamp(-1.0, 1.0).toDouble();
    return (x: focalX, y: focalY);
  }

  img.Image _resizeForScan(img.Image source) {
    const maxSide = 360;
    final longerSide = math.max(source.width, source.height);
    if (longerSide <= maxSide) return source;
    if (source.width >= source.height) {
      return img.copyResize(
        source,
        width: maxSide,
        interpolation: img.Interpolation.average,
      );
    }
    return img.copyResize(
      source,
      height: maxSide,
      interpolation: img.Interpolation.average,
    );
  }

  bool _isSkinLike(int r, int g, int b) {
    final maxRgb = math.max(r, math.max(g, b));
    final minRgb = math.min(r, math.min(g, b));
    final visibleRed = r > 70 && g > 35 && b > 20 && r > g && r > b;
    final balanced = maxRgb - minRgb > 12 && (r - g).abs() > 8;
    final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
    final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
    final ycbcrSkin = cb >= 77 && cb <= 135 && cr >= 133 && cr <= 180;
    return visibleRed && balanced && ycbcrSkin;
  }

  _FaceComponent? _bestComponent(Uint8List skinMask, int width, int height) {
    final visited = Uint8List(skinMask.length);
    final queue = <int>[];
    _FaceComponent? best;
    var bestScore = 0.0;

    for (var start = 0; start < skinMask.length; start++) {
      if (skinMask[start] == 0 || visited[start] == 1) continue;

      var minX = width;
      var maxX = 0;
      var minY = height;
      var maxY = 0;
      var area = 0;
      var sumX = 0.0;
      var sumY = 0.0;
      queue
        ..clear()
        ..add(start);
      visited[start] = 1;

      for (var head = 0; head < queue.length; head++) {
        final index = queue[head];
        final x = index % width;
        final y = index ~/ width;
        area++;
        sumX += x;
        sumY += y;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;

        void addNeighbor(int next) {
          if (next < 0 || next >= skinMask.length) return;
          if (skinMask[next] == 0 || visited[next] == 1) return;
          visited[next] = 1;
          queue.add(next);
        }

        if (x > 0) addNeighbor(index - 1);
        if (x < width - 1) addNeighbor(index + 1);
        if (y > 0) addNeighbor(index - width);
        if (y < height - 1) addNeighbor(index + width);
      }

      final componentWidth = maxX - minX + 1;
      final componentHeight = maxY - minY + 1;
      final centerX = sumX / area;
      final centerY = sumY / area;
      final component = _FaceComponent(
        area: area,
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        centerX: centerX,
        centerY: centerY,
      );
      final score = _scoreComponent(
        component,
        componentWidth,
        componentHeight,
        width,
        height,
      );
      if (score > bestScore) {
        bestScore = score;
        best = component;
      }
    }

    return bestScore > 0 ? best : null;
  }

  double _scoreComponent(
    _FaceComponent component,
    int componentWidth,
    int componentHeight,
    int imageWidth,
    int imageHeight,
  ) {
    final imageArea = imageWidth * imageHeight;
    final areaRatio = component.area / imageArea;
    final widthRatio = componentWidth / imageWidth;
    final heightRatio = componentHeight / imageHeight;
    if (areaRatio < 0.002 || areaRatio > 0.45) return 0;
    if (widthRatio < 0.035 || heightRatio < 0.035) return 0;
    if (widthRatio > 0.75 || heightRatio > 0.75) return 0;

    final aspect = componentWidth / componentHeight;
    if (aspect < 0.35 || aspect > 2.2) return 0;

    final centerX = component.centerX / imageWidth;
    final centerY = component.centerY / imageHeight;
    final centerPenalty = (centerX - 0.5).abs();
    final upperBias = centerY <= 0.62 ? 1.18 : (centerY <= 0.78 ? 0.82 : 0.45);
    final sizeScore = math.sqrt(component.area.toDouble());
    final centerScore = (1.0 - centerPenalty).clamp(0.35, 1.0);
    final aspectScore = (1.0 - (aspect - 0.78).abs() * 0.32).clamp(0.45, 1.0);
    return sizeScore * upperBias * centerScore * aspectScore;
  }
}

class _FaceComponent {
  const _FaceComponent({
    required this.area,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.centerX,
    required this.centerY,
  });

  final int area;
  final int minX;
  final int maxX;
  final int minY;
  final int maxY;
  final double centerX;
  final double centerY;
}
