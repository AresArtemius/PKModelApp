import 'dart:typed_data';

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

/// Native platforms get amplitude from the recorder itself.
class WebMicLevels {
  const WebMicLevels._();

  static Future<void Function()> start(
    void Function(double level) onLevel,
  ) async {
    return () {};
  }
}

/// Paste / drag-and-drop of files is a browser feature; native apps use
/// their own pickers, so this does nothing there.
class ChatWebInput {
  const ChatWebInput._();

  /// Returns a function that removes the listeners again.
  static void Function() install({
    required void Function(WebInputFile file) onFile,
    required void Function(bool dragging) onDragState,
  }) {
    return () {};
  }
}
