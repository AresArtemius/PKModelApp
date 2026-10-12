/// Social links on an account page: the free-text «Instagram / Telegram /
/// WhatsApp» field may hold several links; each gets its own button.
class AccountLink {
  const AccountLink({required this.label, required this.url, required this.kind});

  final String label;
  final String url;
  final AccountLinkKind kind;
}

enum AccountLinkKind { website, telegram, instagram, vk, whatsapp, youtube, tiktok, other }

List<AccountLink> parseAccountLinks({
  required String website,
  required String social,
  required bool ru,
}) {
  final out = <AccountLink>[];
  final site = website.trim();
  if (site.isNotEmpty) {
    out.add(AccountLink(label: ru ? 'Сайт' : 'Website', url: _normalize(site), kind: AccountLinkKind.website));
  }
  final parts = social
      .split(RegExp(r'[\s,;|]+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);
  for (final raw in parts) {
    final value = raw.startsWith('@') ? raw : raw;
    final lower = value.toLowerCase();
    AccountLinkKind kind;
    String url;
    if (lower.contains('t.me/') || lower.contains('telegram.me/') || lower.contains('telegram.org')) {
      kind = AccountLinkKind.telegram;
      url = _normalize(value);
    } else if (lower.contains('instagram.com/')) {
      kind = AccountLinkKind.instagram;
      url = _normalize(value);
    } else if (lower.contains('vk.com/')) {
      kind = AccountLinkKind.vk;
      url = _normalize(value);
    } else if (lower.contains('wa.me/') || lower.contains('whatsapp.com/')) {
      kind = AccountLinkKind.whatsapp;
      url = _normalize(value);
    } else if (lower.contains('youtube.com/') || lower.contains('youtu.be/')) {
      kind = AccountLinkKind.youtube;
      url = _normalize(value);
    } else if (lower.contains('tiktok.com/')) {
      kind = AccountLinkKind.tiktok;
      url = _normalize(value);
    } else if (value.startsWith('@') && value.length > 1) {
      // A bare «@handle» is most likely Telegram in this market.
      kind = AccountLinkKind.telegram;
      url = 'https://t.me/${value.substring(1)}';
    } else if (RegExp(r'^\+?\d[\d\s\-()]{7,}$').hasMatch(value)) {
      kind = AccountLinkKind.whatsapp;
      url = 'https://wa.me/${value.replaceAll(RegExp(r'[^\d]'), '')}';
    } else if (lower.contains('.')) {
      kind = AccountLinkKind.other;
      url = _normalize(value);
    } else {
      continue;
    }
    out.add(AccountLink(label: _label(kind, ru), url: url, kind: kind));
  }
  return out;
}

String _normalize(String v) {
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  return 'https://$v';
}

String _label(AccountLinkKind kind, bool ru) => switch (kind) {
  AccountLinkKind.website => ru ? 'Сайт' : 'Website',
  AccountLinkKind.telegram => 'Telegram',
  AccountLinkKind.instagram => 'Instagram',
  AccountLinkKind.vk => 'VK',
  AccountLinkKind.whatsapp => 'WhatsApp',
  AccountLinkKind.youtube => 'YouTube',
  AccountLinkKind.tiktok => 'TikTok',
  AccountLinkKind.other => ru ? 'Ссылка' : 'Link',
};
