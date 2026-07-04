import 'package:image_picker/image_picker.dart';

class ProfileMediaWebUploadCacheItem {
  const ProfileMediaWebUploadCacheItem({
    required this.file,
    required this.storage,
  });

  final XFile file;
  final String storage;
}

class ProfileMediaWebUploadCache {
  const ProfileMediaWebUploadCache._();

  static bool get isSupported => false;

  static String registerNativeHandle(Object handle) => '';

  static Future<String> saveItem({
    required String taskId,
    required String itemId,
    required XFile source,
  }) async {
    return '';
  }

  static Future<ProfileMediaWebUploadCacheItem?> restoreItem({
    required String taskId,
    required String itemId,
    required String name,
    required String mimeType,
  }) async {
    return null;
  }

  static Future<void> deleteTask(String taskId) async {}
}
