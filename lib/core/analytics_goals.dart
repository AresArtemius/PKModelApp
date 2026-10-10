export 'analytics_goals_stub.dart' if (dart.library.html) 'analytics_goals_web.dart';

/// Goal names (Метрика → Цели, тип «JavaScript-событие», идентификатор = имя).
abstract final class Goals {
  /// Visit of /feed.
  static const feedVisit = 'feed_visit';

  /// A post, a profile or a casting shared to the feed.
  static const feedRepost = 'feed_repost';

  /// A casting opened from a feed card.
  static const feedCastingOpen = 'feed_casting_open';

  /// A response sent to a casting that was opened from the feed.
  static const feedCastingRespond = 'feed_casting_respond';

  /// A new post written in the composer.
  static const feedPost = 'feed_post';
}
