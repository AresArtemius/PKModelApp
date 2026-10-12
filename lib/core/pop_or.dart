import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Back-button behaviour for pushed pages: when there is a navigation
/// stack, go back to where the user came from (feed, chat, casting…);
/// otherwise (direct link, reload) fall back to the page's own default.
void popOr(BuildContext context, VoidCallback? fallback) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  fallback?.call();
}
