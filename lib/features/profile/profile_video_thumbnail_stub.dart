import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

abstract final class ProfileVideoThumbnail {
  static Future<Uint8List?> webBytes(XFile file) async => null;
}
