import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

class ProfileMediaWebUploadCache {
  const ProfileMediaWebUploadCache._();

  static const _dbName = 'pk_modelapp_profile_media_uploads';
  static const _storeName = 'files';
  static const _version = 1;

  static bool get isSupported {
    try {
      web.window.indexedDB;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveItem({
    required String taskId,
    required String itemId,
    required XFile source,
  }) async {
    if (!isSupported) return;
    final bytes = await source.readAsBytes();
    final db = await _openDb();
    try {
      final transaction = db.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);
      await _waitRequest(
        store.put(
          _recordFor(source: source, bytes: bytes),
          _key(taskId, itemId).toJS,
        ),
      );
      await _waitTransaction(transaction);
    } finally {
      db.close();
    }
  }

  static Future<XFile?> restoreItem({
    required String taskId,
    required String itemId,
    required String name,
    required String mimeType,
  }) async {
    if (!isSupported) return null;
    final db = await _openDb();
    try {
      final transaction = db.transaction(_storeName.toJS, 'readonly');
      final store = transaction.objectStore(_storeName);
      final raw = await _waitRequest(store.get(_key(taskId, itemId).toJS));
      await _waitTransaction(transaction);
      if (raw == null || raw.isUndefinedOrNull) return null;

      final record = raw as JSObject;
      final bytes = _readBytes(record['bytes']);
      if (bytes == null || bytes.isEmpty) return null;

      final restoredName = _readString(record['name']);
      final restoredMimeType = _readString(record['mimeType']);
      final finalName = restoredName.trim().isEmpty ? name : restoredName;
      final finalMimeType = restoredMimeType.trim().isEmpty
          ? mimeType
          : restoredMimeType;

      return XFile.fromData(
        bytes,
        name: finalName,
        mimeType: finalMimeType.isEmpty ? null : finalMimeType,
        length: bytes.length,
        path: 'indexeddb://profile-media/$taskId/$itemId',
      );
    } finally {
      db.close();
    }
  }

  static Future<void> deleteTask(String taskId) async {
    if (!isSupported) return;
    final db = await _openDb();
    try {
      final transaction = db.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);
      final rawKeys = await _waitRequest(store.getAllKeys());
      final keys = _readStringList(rawKeys);
      for (final key in keys) {
        if (key.startsWith('$taskId/')) {
          await _waitRequest(store.delete(key.toJS));
        }
      }
      await _waitTransaction(transaction);
    } finally {
      db.close();
    }
  }

  static Future<web.IDBDatabase> _openDb() async {
    final request = web.window.indexedDB.open(_dbName, _version);
    web.EventStreamProvider<web.Event>(
      'upgradeneeded',
    ).forTarget(request).listen((_) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    });
    final raw = await _waitRequest(request);
    return raw as web.IDBDatabase;
  }

  static JSObject _recordFor({
    required XFile source,
    required Uint8List bytes,
  }) {
    final record = JSObject();
    record['name'] = source.name.toJS;
    record['mimeType'] = (source.mimeType ?? '').toJS;
    record['bytes'] = bytes.toJS;
    record['length'] = bytes.length.toJS;
    record['savedAt'] = DateTime.now().toIso8601String().toJS;
    return record;
  }

  static Future<JSAny?> _waitRequest(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    late final StreamSubscription<web.Event> successSub;
    late final StreamSubscription<web.Event> errorSub;

    void cleanup() {
      unawaited(successSub.cancel());
      unawaited(errorSub.cancel());
    }

    successSub = web.EventStreamProvider<web.Event>('success')
        .forTarget(request)
        .listen((_) {
          if (completer.isCompleted) return;
          cleanup();
          completer.complete(request.result);
        });
    errorSub = web.EventStreamProvider<web.Event>('error')
        .forTarget(request)
        .listen((_) {
          if (completer.isCompleted) return;
          cleanup();
          completer.completeError(
            request.error ?? StateError('IndexedDB request failed'),
          );
        });

    return completer.future;
  }

  static Future<void> _waitTransaction(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    late final StreamSubscription<web.Event> completeSub;
    late final StreamSubscription<web.Event> errorSub;
    late final StreamSubscription<web.Event> abortSub;

    void cleanup() {
      unawaited(completeSub.cancel());
      unawaited(errorSub.cancel());
      unawaited(abortSub.cancel());
    }

    completeSub = web.EventStreamProvider<web.Event>('complete')
        .forTarget(transaction)
        .listen((_) {
          if (completer.isCompleted) return;
          cleanup();
          completer.complete();
        });
    errorSub = web.EventStreamProvider<web.Event>('error')
        .forTarget(transaction)
        .listen((_) {
          if (completer.isCompleted) return;
          cleanup();
          completer.completeError(
            transaction.error ?? StateError('IndexedDB transaction failed'),
          );
        });
    abortSub = web.EventStreamProvider<web.Event>('abort')
        .forTarget(transaction)
        .listen((_) {
          if (completer.isCompleted) return;
          cleanup();
          completer.completeError(
            transaction.error ?? StateError('IndexedDB transaction aborted'),
          );
        });

    return completer.future;
  }

  static String _key(String taskId, String itemId) => '$taskId/$itemId';

  static Uint8List? _readBytes(JSAny? raw) {
    if (raw == null || raw.isUndefinedOrNull) return null;
    final dart = raw.dartify();
    if (dart is Uint8List) return dart;
    if (dart is ByteBuffer) return Uint8List.view(dart);
    if (dart is List<int>) return Uint8List.fromList(dart);
    if (dart is List) return Uint8List.fromList(dart.whereType<int>().toList());
    return null;
  }

  static String _readString(JSAny? raw) {
    if (raw == null || raw.isUndefinedOrNull) return '';
    return raw.dartify()?.toString() ?? '';
  }

  static List<String> _readStringList(JSAny? raw) {
    if (raw == null || raw.isUndefinedOrNull) return const <String>[];
    final dart = raw.dartify();
    if (dart is! List) return const <String>[];
    return dart.map((e) => e.toString()).toList();
  }
}
