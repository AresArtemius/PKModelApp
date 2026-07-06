import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

import 'profile_media_web_upload_cache_web.dart';

extension type _FileHandleArray(JSObject _) implements JSObject {
  external int get length;

  web.FileSystemFileHandle at(int index) =>
      getProperty<web.FileSystemFileHandle>(index.toString().toJS);
}

abstract final class ProfileMediaWebNativePicker {
  static bool get isSupported {
    try {
      return web.window.hasProperty('showOpenFilePicker'.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  static Future<List<XFile>> pickPhotos() {
    return _pick(
      multiple: true,
      description: 'Images',
      mimeType: 'image/*',
      extensions: const ['.jpg', '.jpeg', '.png', '.webp', '.heic'],
    );
  }

  static Future<List<XFile>> pickVideos() {
    return _pick(
      multiple: true,
      description: 'Videos',
      mimeType: 'video/*',
      extensions: const ['.mp4', '.mov', '.m4v', '.webm'],
    );
  }

  static Future<List<XFile>> _pick({
    required bool multiple,
    required String description,
    required String mimeType,
    required List<String> extensions,
  }) async {
    if (!isSupported) return const <XFile>[];
    final options = JSObject();
    options['multiple'] = multiple.toJS;
    options['types'] = <JSObject>[
      _acceptType(
        description: description,
        mimeType: mimeType,
        extensions: extensions,
      ),
    ].toJS;

    final rawPromise = web.window.callMethod<JSAny?>(
      'showOpenFilePicker'.toJS,
      options,
    );
    if (rawPromise == null || rawPromise.isUndefinedOrNull) {
      return const <XFile>[];
    }
    final rawHandles = await (rawPromise as JSPromise<JSAny?>).toDart;
    if (rawHandles == null || rawHandles.isUndefinedOrNull) {
      return const <XFile>[];
    }
    final handles = _FileHandleArray(rawHandles as JSObject);
    final files = <XFile>[];
    for (var i = 0; i < handles.length; i++) {
      final handle = handles.at(i);
      final file = await handle.getFile().toDart;
      final buffer = await file.arrayBuffer().toDart;
      final path = ProfileMediaWebUploadCache.registerNativeHandle(handle);
      files.add(
        XFile.fromData(
          Uint8List.view(buffer.toDart),
          name: file.name,
          mimeType: file.type.isEmpty ? null : file.type,
          length: file.size,
          path: path,
        ),
      );
    }
    return files;
  }

  static JSObject _acceptType({
    required String description,
    required String mimeType,
    required List<String> extensions,
  }) {
    final accept = JSObject();
    accept[mimeType] = extensions.map((e) => e.toJS).toList().toJS;

    final type = JSObject();
    type['description'] = description.toJS;
    type['accept'] = accept;
    return type;
  }
}
