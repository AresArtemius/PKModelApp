import 'package:image_picker/image_picker.dart';

abstract final class ProfileMediaWebNativePicker {
  static bool get isSupported => false;

  static Future<List<XFile>> pickPhotos() async => const <XFile>[];

  static Future<List<XFile>> pickVideos() async => const <XFile>[];
}
