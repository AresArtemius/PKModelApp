import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_provider.dart';

final protectedMediaUrlServiceProvider = Provider<ProtectedMediaUrlService>((
  ref,
) {
  return ProtectedMediaUrlService(ref.read(supabaseProvider));
});

class ProtectedMediaUrlService {
  ProtectedMediaUrlService(this._sb);

  static const signedUrlTtl = Duration(minutes: 55);
  static const _storageScheme = 'storage';

  final SupabaseClient _sb;
  final Map<String, _SignedMediaCacheEntry> _cache = {};

  static String storageUri({required String bucket, required String path}) {
    final cleanBucket = bucket.trim();
    final cleanPath = path.trim().replaceFirst(RegExp(r'^/+'), '');
    if (cleanBucket.isEmpty || cleanPath.isEmpty) return '';
    return '$_storageScheme://$cleanBucket/$cleanPath';
  }

  Future<String> resolve(String source, {Duration ttl = signedUrlTtl}) async {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '';
    final ref = ProtectedMediaReference.tryParse(trimmed);
    if (ref == null) return trimmed;

    final key = '${ref.bucket}/${ref.path}';
    final now = DateTime.now();
    final cached = _cache[key];
    if (cached != null && cached.expiresAt.isAfter(now)) {
      return cached.url;
    }

    final seconds = ttl.inSeconds.clamp(60, 60 * 60 * 24 * 7);
    final signed = await _sb.storage
        .from(ref.bucket)
        .createSignedUrl(ref.path, seconds);
    _cache[key] = _SignedMediaCacheEntry(
      url: signed,
      expiresAt: now.add(ttl).subtract(const Duration(minutes: 3)),
    );
    return signed;
  }
}

class ProtectedMediaReference {
  const ProtectedMediaReference({required this.bucket, required this.path});

  final String bucket;
  final String path;

  static ProtectedMediaReference? tryParse(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    if (uri.scheme == ProtectedMediaUrlService._storageScheme) {
      final bucket = uri.host.trim();
      final path = uri.path.replaceFirst(RegExp(r'^/+'), '').trim();
      if (bucket.isEmpty || path.isEmpty) return null;
      return ProtectedMediaReference(bucket: bucket, path: path);
    }

    final segments = uri.pathSegments;
    final objectIndex = segments.indexOf('object');
    if (objectIndex < 0 || objectIndex + 3 >= segments.length) return null;

    final visibility = segments[objectIndex + 1];
    if (visibility != 'public' && visibility != 'sign') return null;

    final bucket = segments[objectIndex + 2].trim();
    final path = segments.sublist(objectIndex + 3).join('/').trim();
    if (bucket.isEmpty || path.isEmpty) return null;
    return ProtectedMediaReference(bucket: bucket, path: path);
  }
}

class _SignedMediaCacheEntry {
  const _SignedMediaCacheEntry({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;
}
