import 'package:flutter_test/flutter_test.dart';
import 'package:modelapp/core/storage_image_variant.dart';

void main() {
  const original =
      'https://abc.supabase.co/storage/v1/object/public/profile-media/u1/photo.jpg';

  group('storageImageVariant', () {
    test('rewrites a public object URL into a render URL with size', () {
      expect(
        storageImageVariant(original, width: 600),
        'https://abc.supabase.co/storage/v1/render/image/public/profile-media/u1/photo.jpg?width=600&resize=contain&quality=80',
      );
    });

    test('keeps existing query parameters', () {
      expect(
        storageImageVariant('$original?v=3', width: 600, quality: 70),
        'https://abc.supabase.co/storage/v1/render/image/public/profile-media/u1/photo.jpg?v=3&width=600&resize=contain&quality=70',
      );
    });

    test('leaves videos, signed and foreign URLs unchanged', () {
      const video =
          'https://abc.supabase.co/storage/v1/object/public/profile-media/u1/clip.mp4';
      const signed =
          'https://abc.supabase.co/storage/v1/object/sign/profile-media/u1/photo.jpg?token=x';
      const foreign = 'https://example.com/images/photo.jpg';
      expect(storageImageVariant(video, width: 600), video);
      expect(storageImageVariant(signed, width: 600), signed);
      expect(storageImageVariant(foreign, width: 600), foreign);
      expect(storageImageVariant('  ', width: 600), '');
    });
  });
}
