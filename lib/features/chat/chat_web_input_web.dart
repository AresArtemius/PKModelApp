import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Microphone level meter for the inline voice recorder. The `record`
/// package gives no usable amplitude on the web, so this opens its own
/// analyser on a second microphone stream and reports 0..1 every ~80 ms.
class WebMicLevels {
  const WebMicLevels._();

  /// Returns a function that stops the meter and releases the microphone.
  static Future<void Function()> start(void Function(double level) onLevel) async {
    final constraints = web.MediaStreamConstraints(audio: true.toJS);
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(constraints)
        .toDart;
    final context = web.AudioContext();
    final source = context.createMediaStreamSource(stream);
    final analyser = context.createAnalyser()..fftSize = 512;
    source.connect(analyser);
    final buffer = Uint8List(analyser.fftSize);
    final jsBuffer = buffer.toJS;

    final timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      analyser.getByteTimeDomainData(jsBuffer);
      final samples = jsBuffer.toDart;
      var sum = 0.0;
      for (final sample in samples) {
        final centered = (sample - 128) / 128;
        sum += centered * centered;
      }
      final rms = samples.isEmpty ? 0.0 : (sum / samples.length);
      // RMS of speech sits around 0.02–0.2; stretch it to the bar range.
      final level = (rms * 60).clamp(0.0, 1.0);
      onLevel(level);
    });

    return () {
      timer.cancel();
      final tracks = stream.getTracks().toDart;
      for (final track in tracks) {
        track.stop();
      }
      unawaited(context.close().toDart.then((_) {}));
    };
  }
}

/// A file the browser handed us through paste or drag-and-drop.
class WebInputFile {
  const WebInputFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

/// Browser-level paste and drag-and-drop of files for the chat composer.
///
/// Flutter's text field only receives pasted text, and the canvas has no
/// drop zone of its own, so the listeners sit on the document.
class ChatWebInput {
  const ChatWebInput._();

  /// Returns a function that removes the listeners again.
  static void Function() install({
    required void Function(WebInputFile file) onFile,
    required void Function(bool dragging) onDragState,
  }) {
    final document = web.document;
    var depth = 0;

    bool hasFiles(web.DataTransfer? transfer) {
      if (transfer == null) return false;
      final types = transfer.types.toDart;
      return types.any((type) => type.toDart == 'Files');
    }

    Future<void> deliver(web.File file) async {
      try {
        final buffer = await file.arrayBuffer().toDart;
        final bytes = Uint8List.view(buffer.toDart);
        if (bytes.isEmpty) return;
        onFile(
          WebInputFile(
            name: file.name,
            mimeType: file.type,
            bytes: bytes,
          ),
        );
      } catch (_) {
        // A file the browser could not read: nothing to attach.
      }
    }

    final onPaste = ((web.Event event) {
      final clipboard = (event as web.ClipboardEvent).clipboardData;
      if (clipboard == null) return;
      final items = clipboard.items;
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        if (item.kind != 'file') continue;
        final file = item.getAsFile();
        if (file == null) continue;
        event.preventDefault();
        unawaited(deliver(file));
        return;
      }
    }).toJS;

    final onDragEnter = ((web.Event event) {
      final transfer = (event as web.DragEvent).dataTransfer;
      if (!hasFiles(transfer)) return;
      event.preventDefault();
      depth += 1;
      if (depth == 1) onDragState(true);
    }).toJS;

    final onDragOver = ((web.Event event) {
      final transfer = (event as web.DragEvent).dataTransfer;
      if (!hasFiles(transfer)) return;
      event.preventDefault();
      transfer!.dropEffect = 'copy';
    }).toJS;

    final onDragLeave = ((web.Event event) {
      final transfer = (event as web.DragEvent).dataTransfer;
      if (!hasFiles(transfer)) return;
      depth = depth > 0 ? depth - 1 : 0;
      if (depth == 0) onDragState(false);
    }).toJS;

    final onDrop = ((web.Event event) {
      final transfer = (event as web.DragEvent).dataTransfer;
      depth = 0;
      onDragState(false);
      if (!hasFiles(transfer)) return;
      event.preventDefault();
      final files = transfer!.files;
      if (files.length == 0) return;
      final file = files.item(0);
      if (file != null) unawaited(deliver(file));
    }).toJS;

    document.addEventListener('paste', onPaste);
    document.addEventListener('dragenter', onDragEnter);
    document.addEventListener('dragover', onDragOver);
    document.addEventListener('dragleave', onDragLeave);
    document.addEventListener('drop', onDrop);

    return () {
      document.removeEventListener('paste', onPaste);
      document.removeEventListener('dragenter', onDragEnter);
      document.removeEventListener('dragover', onDragOver);
      document.removeEventListener('dragleave', onDragLeave);
      document.removeEventListener('drop', onDrop);
    };
  }
}
