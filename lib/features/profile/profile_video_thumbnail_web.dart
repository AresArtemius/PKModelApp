import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

abstract final class ProfileVideoThumbnail {
  static const _maxSide = 720;
  static const _timeout = Duration(seconds: 10);

  static Future<Uint8List?> webBytes(XFile file) async {
    web.HTMLVideoElement? video;
    String? objectUrl;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;

      final mimeType = _videoMimeType(file);
      final blob = web.Blob(
        <web.BlobPart>[bytes.toJS].toJS,
        web.BlobPropertyBag(type: mimeType),
      );
      objectUrl = web.URL.createObjectURL(blob);

      video = web.HTMLVideoElement()
        ..muted = true
        ..preload = 'metadata'
        ..src = objectUrl;
      video
        ..setAttribute('playsinline', 'true')
        ..setAttribute('webkit-playsinline', 'true');

      await _firstEvent(video, 'loadedmetadata');
      final seekTarget = _seekTarget(video.duration);
      if (seekTarget > 0) {
        video.currentTime = seekTarget;
        await _firstEvent(video, 'seeked');
      } else {
        await _firstEvent(video, 'loadeddata');
      }

      final width = video.videoWidth;
      final height = video.videoHeight;
      if (width <= 0 || height <= 0) return null;

      final size = _thumbnailSize(width: width, height: height);
      final canvas = web.HTMLCanvasElement()
        ..width = size.width
        ..height = size.height;
      final rawContext = canvas.getContext('2d');
      if (rawContext == null) return null;
      final context = rawContext as web.CanvasRenderingContext2D;
      context.drawImage(video, 0, 0, size.width, size.height);

      final dataUrl = canvas.toDataURL('image/jpeg', 0.78.toJS);
      final comma = dataUrl.indexOf(',');
      if (comma == -1 || comma == dataUrl.length - 1) return null;
      return Uint8List.fromList(base64Decode(dataUrl.substring(comma + 1)));
    } catch (_) {
      return null;
    } finally {
      try {
        video?.pause();
        if (video != null) {
          video
            ..removeAttribute('src')
            ..load();
        }
      } catch (_) {
        // Best-effort cleanup for browser media resources.
      }
      if (objectUrl != null) {
        web.URL.revokeObjectURL(objectUrl);
      }
    }
  }

  static Future<void> _firstEvent(
    web.HTMLVideoElement video,
    String eventName,
  ) {
    final success = web.EventStreamProvider<web.Event>(
      eventName,
    ).forTarget(video).first;
    final failure = web.EventStreamProvider<web.Event>('error')
        .forTarget(video)
        .first
        .then<void>((_) => throw StateError('Video thumbnail error'));
    return Future.any<void>([success, failure]).timeout(_timeout);
  }

  static double _seekTarget(double duration) {
    if (!duration.isFinite || duration <= 0.25) return 0;
    return math.min(1.0, math.max(0.2, duration * 0.08));
  }

  static ({int width, int height}) _thumbnailSize({
    required int width,
    required int height,
  }) {
    if (width <= _maxSide && height <= _maxSide) {
      return (width: width, height: height);
    }
    final scale = _maxSide / math.max(width, height);
    return (
      width: math.max(1, (width * scale).round()),
      height: math.max(1, (height * scale).round()),
    );
  }

  static String _videoMimeType(XFile file) {
    final mime = file.mimeType?.trim().toLowerCase();
    if (mime != null && mime.startsWith('video/')) return mime;
    final name = file.name.toLowerCase();
    if (name.endsWith('.mov')) return 'video/quicktime';
    if (name.endsWith('.webm')) return 'video/webm';
    return 'video/mp4';
  }
}
