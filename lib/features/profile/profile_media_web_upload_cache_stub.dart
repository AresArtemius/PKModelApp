import 'package:image_picker/image_picker.dart';

class ProfileMediaWebUploadCache {
  const ProfileMediaWebUploadCache._();

  static bool get isSupported => false;

  static Future<void> saveItem({
    required String taskId,
    required String itemId,
    required XFile source,
  }) async {}

  static Future<XFile?> restoreItem({
    required String taskId,
    required String itemId,
    required String name,
    required String mimeType,
  }) async {
    return null;
  }

  static Future<void> deleteTask(String taskId) async {}
}
