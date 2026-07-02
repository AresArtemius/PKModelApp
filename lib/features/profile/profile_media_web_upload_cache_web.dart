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
  static const _opfsDirectoryName = 'profile_media_upload_files';
  static const _storageIndexedDb = 'indexeddb';
  static const _storageOpfs = 'opfs';
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
    final opfsFileName = _opfsFileName(taskId, itemId);
    final db = await _openDb();
    try {
      JSObject record;
      try {
        await _saveBytesToOpfs(fileName: opfsFileName, bytes: bytes);
        record = _recordForOpfs(
          source: source,
          bytes: bytes,
          opfsFileName: opfsFileName,
        );
      } catch (_) {
        record = _recordForIndexedDb(source: source, bytes: bytes);
      }

      final transaction = db.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);
      await _waitRequest(store.put(record, _key(taskId, itemId).toJS));
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
      final storage = _readString(record['storage']);
      final bytes = storage == _storageOpfs
          ? await _restoreBytesFromOpfs(_readString(record['opfsFileName']))
          : _readBytes(record['bytes']);
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
        path: storage == _storageOpfs
            ? 'opfs://profile-media/$taskId/$itemId'
            : 'indexeddb://profile-media/$taskId/$itemId',
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
          final raw = await _waitRequest(store.get(key.toJS));
          if (raw != null && !raw.isUndefinedOrNull) {
            final record = raw as JSObject;
            final storage = _readString(record['storage']);
            final opfsFileName = _readString(record['opfsFileName']);
            if (storage == _storageOpfs && opfsFileName.isNotEmpty) {
              await _deleteOpfsFile(opfsFileName);
            }
          }
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

  static Future<void> _saveBytesToOpfs({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final directory = await _openOpfsDirectory();
    final fileHandle = await directory
        .getFileHandle(fileName, web.FileSystemGetFileOptions(create: true))
        .toDart;
    final writable = await fileHandle.createWritable().toDart;
    await writable.write(bytes.toJS).toDart;
    await writable.close().toDart;
  }

  static Future<Uint8List?> _restoreBytesFromOpfs(String fileName) async {
    if (fileName.isEmpty) return null;
    try {
      final directory = await _openOpfsDirectory();
      final fileHandle = await directory.getFileHandle(fileName).toDart;
      final file = await fileHandle.getFile().toDart;
      final buffer = await file.arrayBuffer().toDart;
      return Uint8List.view(buffer.toDart);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _deleteOpfsFile(String fileName) async {
    if (fileName.isEmpty) return;
    try {
      final directory = await _openOpfsDirectory();
      await directory.removeEntry(fileName).toDart;
    } catch (_) {}
  }

  static Future<web.FileSystemDirectoryHandle> _openOpfsDirectory() async {
    final root = await web.window.navigator.storage.getDirectory().toDart;
    return root
        .getDirectoryHandle(
          _opfsDirectoryName,
          web.FileSystemGetDirectoryOptions(create: true),
        )
        .toDart;
  }

  static JSObject _recordForOpfs({
    required XFile source,
    required Uint8List bytes,
    required String opfsFileName,
  }) {
    final record = JSObject();
    record['name'] = source.name.toJS;
    record['mimeType'] = (source.mimeType ?? '').toJS;
    record['storage'] = _storageOpfs.toJS;
    record['opfsFileName'] = opfsFileName.toJS;
    record['length'] = bytes.length.toJS;
    record['savedAt'] = DateTime.now().toIso8601String().toJS;
    return record;
  }

  static JSObject _recordForIndexedDb({
    required XFile source,
    required Uint8List bytes,
  }) {
    final record = JSObject();
    record['name'] = source.name.toJS;
    record['mimeType'] = (source.mimeType ?? '').toJS;
    record['storage'] = _storageIndexedDb.toJS;
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

  static String _opfsFileName(String taskId, String itemId) {
    final safe = _key(
      taskId,
      itemId,
    ).replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '$safe.bin';
  }

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
