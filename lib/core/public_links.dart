const String _publicBaseUrl = String.fromEnvironment(
  'PUBLIC_BASE_URL',
  defaultValue: 'https://app.pk.management',
);

String _joinPublicPath(String path) {
  final base = _publicBaseUrl.trim().isEmpty
      ? 'https://app.pk.management'
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

String publicProfileTokenLink({
  required String profileId,
  required String token,
}) {
  final id = profileId.trim();
  final cleanToken = token.trim();
  if (id.isEmpty) return '';
  if (cleanToken.isEmpty) return publicProfileLink(id);
  return _joinPublicPath(
    '/p/${Uri.encodeComponent(id)}?t=${Uri.encodeQueryComponent(cleanToken)}',
  );
}

/// Step 45: links shared from the feed.
String publicCastingLink(String castingId) {
  return _joinPublicPath('/castings?casting=${Uri.encodeQueryComponent(castingId)}');
}

String publicAccountLink(String tag) {
  return _joinPublicPath('/@${Uri.encodeComponent(tag)}');
}

String publicSelectionLink(String selectionId) {
  return _joinPublicPath('/s/${Uri.encodeComponent(selectionId)}');
}

String publicSelectionFeedbackLink({
  required String selectionId,
  required String accessToken,
}) {
  final id = selectionId.trim();
  final token = accessToken.trim();
  if (id.isEmpty) return '';
  if (token.isEmpty) return publicSelectionLink(id);
  return _joinPublicPath(
    '/s/${Uri.encodeComponent(id)}'
    '?access=${Uri.encodeQueryComponent(token)}',
  );
}
