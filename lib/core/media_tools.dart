import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_logger.dart';

class PreparedVideo {
  const PreparedVideo({
    required this.path,
    required this.originalBytes,
    required this.preparedBytes,
    required this.compressed,
  });

  final String path;
  final int originalBytes;
  final int preparedBytes;
  final bool compressed;
}

class MediaTools {
  const MediaTools._();

  static const MethodChannel _channel = MethodChannel('modelapp/media_tools');

  static Future<PreparedVideo> prepareVideo({
    required String inputPath,
    required String outputPath,
  }) async {
    final input = File(inputPath);
    final originalBytes = input.existsSync() ? input.lengthSync() : 0;
    if (kIsWeb || !Platform.isIOS || originalBytes == 0) {
      return PreparedVideo(
        path: inputPath,
        originalBytes: originalBytes,
        preparedBytes: originalBytes,
        compressed: false,
      );
    }

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'compressVideo',
        <String, dynamic>{'inputPath': inputPath, 'outputPath': outputPath},
      );
      final preparedPath = (result?['path'] ?? '').toString().trim();
      final compressed = result?['compressed'] == true;
      final output = File(preparedPath);
      final preparedBytes = output.existsSync() ? output.lengthSync() : 0;

      if (preparedPath.isNotEmpty &&
          compressed &&
          preparedBytes > 0 &&
          preparedBytes < originalBytes) {
        return PreparedVideo(
          path: preparedPath,
          originalBytes: originalBytes,
          preparedBytes: preparedBytes,
          compressed: true,
        );
      }
    } catch (e, st) {
      AppLogger.error(
        'Video preparation failed, uploading original',
        error: e,
        stackTrace: st,
      );
    }

    return PreparedVideo(
      path: inputPath,
      originalBytes: originalBytes,
      preparedBytes: originalBytes,
      compressed: false,
    );
  }
}
