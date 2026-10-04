/// Supabase Storage image transformations (available on the Pro plan).
///
/// Photos are stored as public objects at
/// `…/storage/v1/object/public/<bucket>/<path>`. The same object can be served
/// resized through `…/storage/v1/render/image/public/<bucket>/<path>?width=…`,
/// which is what catalogue cards should load instead of the 1600 px original.
/// Anything that is not a public Storage image URL is returned unchanged.
library;

const int kCatalogCardImageWidth = 600;
const int kCatalogPreviewImageWidth = 900;
const int kStorageImageQuality = 80;

const String _objectPublicSegment = '/storage/v1/object/public/';
const String _renderPublicSegment = '/storage/v1/render/image/public/';

const Set<String> _videoExtensions = {'mp4', 'mov', 'webm', 'm4v', 'avi'};

String storageImageVariant(
  String url, {
  required int width,
  int quality = kStorageImageQuality,
}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;
  if (!trimmed.contains(_objectPublicSegment)) return trimmed;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.path.isEmpty) return trimmed;

  final dot = uri.path.lastIndexOf('.');
  if (dot != -1) {
    final ext = uri.path.substring(dot + 1).toLowerCase();
    if (_videoExtensions.contains(ext)) return trimmed;
  }

  final newPath = uri.path.replaceFirst(
    _objectPublicSegment,
    _renderPublicSegment,
  );
  final params = <String, String>{
    ...uri.queryParameters,
    'width': '$width',
    // Only the width is given; with the default `cover` mode Storage keeps
    // the original height and crops a narrow centre strip out of the photo.
    // `contain` scales the whole picture down to the width instead.
    'resize': 'contain',
    'quality': '$quality',
  };
  return uri.replace(path: newPath, queryParameters: params).toString();
}
