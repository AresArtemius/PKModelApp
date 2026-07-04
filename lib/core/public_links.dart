const String _publicBaseUrl = String.fromEnvironment(
  'PUBLIC_BASE_URL',
  defaultValue: 'https://aresartemius.github.io/PKModelApp/#',
);

String _joinPublicPath(String path) {
  final base = _publicBaseUrl.trim().isEmpty
      ? 'https://aresartemius.github.io/PKModelApp/#'
      : _publicBaseUrl;
  final cleanBase = base.endsWith('/')
      ? base.substring(0, base.length - 1)
      : base;
  final cleanPath = path.startsWith('/') ? path : '/$path';
  return '$cleanBase$cleanPath';
}

String publicProfileLink(String profileId) {
  return _joinPublicPath('/p/${Uri.encodeComponent(profileId)}');
}

String publicSelectionLink(String selectionId) {
  return _joinPublicPath('/s/${Uri.encodeComponent(selectionId)}');
}
