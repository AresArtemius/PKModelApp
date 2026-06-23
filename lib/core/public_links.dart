const String _publicBaseUrl = String.fromEnvironment(
  'PUBLIC_BASE_URL',
  defaultValue: 'modelapp:/',
);

String _joinPublicPath(String path) {
  final base = _publicBaseUrl.trim().isEmpty ? 'modelapp:/' : _publicBaseUrl;
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
