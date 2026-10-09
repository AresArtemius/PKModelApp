part of 'chat_page.dart';

// Step 27: split out of chat_page.dart without behaviour changes.
// Pinned messages, message search, media viewer, audio and video players.

class _PinnedMessagesPanel extends StatelessWidget {
  const _PinnedMessagesPanel({
    required this.messages,
    required this.isRussian,
    required this.previewBuilder,
    required this.onTap,
    required this.onUnpin,
    this.flat = false,
  });

  final List<ChatMessage> messages;
  final bool isRussian;
  final String Function(ChatMessage message) previewBuilder;
  final ValueChanged<ChatMessage> onTap;
  final ValueChanged<ChatMessage> onUnpin;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final visibleMessages = messages.take(3).toList(growable: false);
    if (flat) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: Tokens.bg,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: const Border(
            left: BorderSide(color: Tokens.accent, width: 3),
            top: BorderSide(color: Tokens.border),
            right: BorderSide(color: Tokens.border),
            bottom: BorderSide(color: Tokens.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (isRussian ? 'Закреплено' : 'Pinned') +
                  (messages.length > 1 ? ' · ${messages.length}' : ''),
              style: AppText.caption.copyWith(
                color: Tokens.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final message in visibleMessages)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => onTap(message),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          previewBuilder(message).trim().isEmpty
                              ? (isRussian ? 'Сообщение' : 'Message')
                              : previewBuilder(message).trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.small,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isRussian ? 'Открепить' : 'Unpin',
                    onPressed: () => onUnpin(message),
                    style: _composerIconStyle,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
                ],
              ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.push_pin_rounded,
                size: 18,
                color: BrandTheme.redTop,
              ),
              const SizedBox(width: 8),
              Text(
                isRussian ? 'ЗАКРЕПЛЕНО' : 'PINNED',
                style: const TextStyle(
                  color: kTextDark,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const Spacer(),
              Text(
                messages.length.toString(),
                style: const TextStyle(
                  color: kTextMuted,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final message in visibleMessages)
            _PinnedMessageRow(
              message: message,
              preview: previewBuilder(message),
              isRussian: isRussian,
              onTap: () => onTap(message),
              onUnpin: () => onUnpin(message),
            ),
        ],
      ),
    );
  }
}

class _PinnedMessageRow extends StatelessWidget {
  const _PinnedMessageRow({
    required this.message,
    required this.preview,
    required this.isRussian,
    required this.onTap,
    required this.onUnpin,
  });

  final ChatMessage message;
  final String preview;
  final bool isRussian;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final cleanPreview = preview.trim().isEmpty
        ? (isRussian ? 'Сообщение' : 'Message')
        : preview.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Text(
                cleanPreview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextMuted,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: isRussian ? 'Открепить' : 'Unpin',
            onPressed: onUnpin,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: kTextMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          ),
        ],
      ),
    );
  }
}

class _ChatSearchPanel extends StatelessWidget {
  const _ChatSearchPanel({
    required this.controller,
    required this.query,
    required this.hitCount,
    required this.currentPosition,
    required this.loading,
    required this.errorText,
    required this.onChanged,
    required this.onClose,
    required this.onPrevious,
    required this.onNext,
    required this.onSubmitted,
    this.flat = false,
  });

  final TextEditingController controller;
  final String query;
  final int hitCount;
  final int currentPosition;
  final bool loading;
  final String errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSubmitted;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final hasQuery = query.trim().isNotEmpty;
    final hasHits = hitCount > 0;
    final hasError = errorText.trim().isNotEmpty;
    final statusText = !hasQuery
        ? (isRussian ? 'Поиск' : 'Search')
        : loading
        ? '...'
        : hasError
        ? (isRussian ? 'Ошибка' : 'Error')
        : hasHits
        ? '$currentPosition / $hitCount'
        : (isRussian ? 'Нет' : 'None');

    if (flat) {
      return Container(
        height: 44,
        padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
        decoration: BoxDecoration(
          color: Tokens.bg,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: Tokens.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Tokens.textSecondary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: onChanged,
                onSubmitted: (_) => onSubmitted(),
                textInputAction: TextInputAction.search,
                style: AppText.small,
                decoration: InputDecoration(
                  hintText: isRussian ? 'Поиск по переписке' : 'Search messages',
                  hintStyle: AppText.small.copyWith(color: Tokens.textTertiary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Text(
              statusText,
              style: AppText.caption.copyWith(
                color: hasError || (hasQuery && !loading && !hasHits)
                    ? Tokens.danger
                    : Tokens.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: isRussian ? 'Предыдущее' : 'Previous',
              onPressed: hasHits && !loading ? onPrevious : null,
              style: _composerIconStyle,
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: isRussian ? 'Следующее' : 'Next',
              onPressed: hasHits && !loading ? onNext : null,
              style: _composerIconStyle,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: isRussian ? 'Закрыть (Esc)' : 'Close (Esc)',
              onPressed: onClose,
              style: _composerIconStyle,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kBorderColor),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: kTextDark, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: isRussian ? 'Поиск по сообщениям' : 'Search messages',
                border: InputBorder.none,
                isDense: true,
                hintStyle: const TextStyle(
                  color: kTextMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: const TextStyle(
                color: kTextDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 46, maxWidth: 86),
            child: Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: hasError || (hasQuery && !loading && !hasHits)
                    ? BrandTheme.redTop
                    : kTextMuted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kTextMuted,
                ),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: hasError ? errorText : null,
            onPressed: hasHits && !loading ? onPrevious : null,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            color: kTextDark,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: hasError ? errorText : null,
            onPressed: hasHits && !loading ? onNext : null,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            color: kTextDark,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            color: kTextDark,
          ),
        ],
      ),
    );
  }
}

class _AudioMessagePlayer extends ConsumerStatefulWidget {
  const _AudioMessagePlayer({
    required this.message,
    required this.showReadStatus,
    required this.onListened,
    this.flat = false,
    this.mine = false,
  });

  final ChatMessage message;
  final bool showReadStatus;
  final VoidCallback onListened;

  /// v2: play circle + waveform + duration, no inner card.
  final bool flat;
  final bool mine;

  @override
  ConsumerState<_AudioMessagePlayer> createState() =>
      _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends ConsumerState<_AudioMessagePlayer> {
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  bool _loading = false;
  bool _playing = false;
  bool _listenedMarked = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _stateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _playing = state.playing;
        _loading =
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      });
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
    _positionSub = _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _durationSub = _player.durationStream.listen((duration) {
      if (!mounted || duration == null) return;
      setState(() => _duration = duration);
    });
  }

  @override
  void dispose() {
    unawaited(_stateSub?.cancel());
    unawaited(_positionSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.message.mediaUrl.trim().isEmpty) return;
    try {
      if (_playing) {
        await _player.pause();
        return;
      }
      if (_player.audioSource == null) {
        final url = await ref
            .read(protectedMediaUrlServiceProvider)
            .resolve(widget.message.mediaUrl);
        await _player.setUrl(url);
      }
      await _player.play();
      _markListenedOnce();
    } catch (_) {
      if (!mounted) return;
      final isRussian = Localizations.localeOf(context).languageCode == 'ru';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRussian
                ? 'Не удалось воспроизвести аудио'
                : 'Could not play audio',
          ),
        ),
      );
    }
  }

  void _markListenedOnce() {
    if (_listenedMarked || widget.message.listenedAt != null) return;
    _listenedMarked = true;
    widget.onListened();
  }

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final knownDuration = _duration.inMilliseconds > 0
        ? _duration
        : widget.message.audioDuration ?? Duration.zero;
    final total = knownDuration.inMilliseconds <= 0
        ? 1
        : knownDuration.inMilliseconds;
    final progress = (_position.inMilliseconds / total).clamp(0.0, 1.0);
    final displayDuration = knownDuration.inMilliseconds > 0
        ? knownDuration
        : _position;
    final listened = widget.message.listenedAt != null;
    final read = widget.message.readAt != null;
    final statusText = listened
        ? (isRussian ? 'прослушано' : 'listened')
        : read
        ? (isRussian ? 'прочитано' : 'read')
        : (isRussian ? 'доставлено' : 'delivered');
    if (widget.flat) {
      final mine = widget.mine;
      final fg = mine ? Colors.white : Tokens.ink;
      final muted = mine
          ? Colors.white.withValues(alpha: 0.7)
          : Tokens.textSecondary;
      return SizedBox(
        width: 260,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              onTap: _loading ? null : _toggle,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: mine ? Colors.white : Tokens.ink,
                  shape: BoxShape.circle,
                ),
                child: _loading
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: mine ? Tokens.ink : Colors.white,
                        ),
                      )
                    : Icon(
                        _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: mine ? Tokens.ink : Colors.white,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _VoiceWaveform(
                    seed: widget.message.id,
                    progress: progress,
                    active: _playing,
                    activeColor: fg,
                    inactiveColor: fg.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatVoiceDuration(
                          _playing ? _position : displayDuration,
                        ),
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1,
                        ),
                      ),
                      if (mine && listened) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.graphic_eq_rounded, size: 13, color: muted),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: 232,
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: _loading ? null : _toggle,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: kTextDark,
                shape: BoxShape.circle,
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mic_rounded, size: 14, color: kTextDark),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isRussian ? 'Голосовое' : 'Voice message',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: kTextDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Text(
                      _formatVoiceDuration(displayDuration),
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _VoiceWaveform(
                  seed: widget.message.id,
                  progress: progress,
                  active: _playing,
                ),
                if (widget.showReadStatus) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        listened
                            ? Icons.graphic_eq_rounded
                            : read
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 14,
                        color: listened || read
                            ? BrandTheme.redTop
                            : kTextMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: listened || read
                              ? BrandTheme.redTop
                              : kTextMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({
    required this.seed,
    required this.progress,
    required this.active,
    this.activeColor,
    this.inactiveColor,
  });

  final String seed;
  final double progress;
  final bool active;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      width: double.infinity,
      child: CustomPaint(
        painter: _VoiceWaveformPainter(
          seed: seed,
          progress: progress.clamp(0.0, 1.0),
          active: active,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
        ),
      ),
    );
  }
}

class _VoiceWaveformPainter extends CustomPainter {
  const _VoiceWaveformPainter({
    required this.seed,
    required this.progress,
    required this.active,
    this.activeColor,
    this.inactiveColor,
  });

  final String seed;
  final double progress;
  final bool active;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final hash = seed.hashCode.abs();
    final bars = math.max(18, (size.width / 5).floor());
    final step = size.width / bars;
    final barWidth = math.min(3.0, step * 0.56);
    final radius = Radius.circular(barWidth);
    final inactivePaint = Paint()
      ..color = inactiveColor ?? kTextDark.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final activePaint = Paint()
      ..color =
          activeColor ??
          (active ? BrandTheme.redTop : kTextDark.withValues(alpha: 0.84))
      ..style = PaintingStyle.fill;

    for (var i = 0; i < bars; i++) {
      final wave =
          0.34 +
          0.66 * ((math.sin((i + 1) * ((hash % 11) + 3) * 0.72) + 1) / 2);
      final height = math.max(5.0, size.height * wave);
      final x = i * step + (step - barWidth) / 2;
      final y = (size.height - height) / 2;
      final rect = Rect.fromLTWH(x, y, barWidth, height);
      final isFilled = bars <= 1 ? progress > 0 : i / (bars - 1) <= progress;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        isFilled ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.progress != progress ||
        oldDelegate.active != active ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

class _MediaViewerDialog extends StatelessWidget {
  const _MediaViewerDialog({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isFile) {
      return _FileViewerDialog(message: message);
    }
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: message.isVideo
                  ? _VideoPlayerSurface(source: message.mediaUrl)
                  : InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4,
                      child: _ProtectedCachedNetworkImage(
                        source: message.mediaUrl,
                        fit: BoxFit.contain,
                        memCacheWidth: 1400,
                        maxWidthDiskCache: 2000,
                        placeholder: const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _ViewerCloseButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileViewerDialog extends StatelessWidget {
  const _FileViewerDialog({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final size = _formatFileSize(message.fileSize);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: BrandTheme.basePillShadow(isDark: false),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: kTextDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.fileDisplayName.isEmpty
                            ? (isRussian ? 'Файл' : 'File')
                            : message.fileDisplayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kTextDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          height: 1.15,
                        ),
                      ),
                      if (size.isNotEmpty || message.fileMime.isNotEmpty)
                        Text(
                          [
                            if (size.isNotEmpty) size,
                            if (message.fileMime.isNotEmpty) message.fileMime,
                          ].join(' • '),
                          style: const TextStyle(
                            color: kTextMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SelectableText(
              message.mediaUrl,
              style: const TextStyle(
                color: kTextMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: message.mediaUrl),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isRussian ? 'Ссылка скопирована' : 'Link copied',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(isRussian ? 'СКОПИРОВАТЬ' : 'COPY'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerCloseButton extends StatelessWidget {
  const _ViewerCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _ProtectedCachedNetworkImage extends ConsumerWidget {
  const _ProtectedCachedNetworkImage({
    required this.source,
    required this.fit,
    required this.placeholder,
    required this.errorWidget,
    this.memCacheWidth,
    this.maxWidthDiskCache,
  });

  final String source;
  final BoxFit fit;
  final Widget placeholder;
  final Widget errorWidget;
  final int? memCacheWidth;
  final int? maxWidthDiskCache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(_protectedMediaUrlProvider(source));
    return url.when(
      data: (resolved) {
        if (resolved.trim().isEmpty) return errorWidget;
        return CachedNetworkImage(
          imageUrl: resolved,
          fit: fit,
          memCacheWidth: memCacheWidth,
          maxWidthDiskCache: maxWidthDiskCache,
          placeholder: (_, _) => placeholder,
          errorWidget: (_, _, _) => errorWidget,
        );
      },
      loading: () => placeholder,
      error: (_, _) => errorWidget,
    );
  }
}

final _protectedMediaUrlProvider = FutureProvider.autoDispose
    .family<String, String>((ref, source) {
      return ref.read(protectedMediaUrlServiceProvider).resolve(source);
    });

class _VideoPlayerSurface extends ConsumerStatefulWidget {
  const _VideoPlayerSurface({required this.source});

  final String source;

  @override
  ConsumerState<_VideoPlayerSurface> createState() =>
      _VideoPlayerSurfaceState();
}

class _VideoPlayerSurfaceState extends ConsumerState<_VideoPlayerSurface> {
  VideoPlayerController? _controller;
  bool _ready = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      final url = await ref
          .read(protectedMediaUrlServiceProvider)
          .resolve(widget.source);
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _ready = true);
      await controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось открыть видео');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _ready ? _controller!.value.aspectRatio : 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_ready)
            GestureDetector(
              onTap: () {
                setState(() {
                  _controller!.value.isPlaying
                      ? _controller!.pause()
                      : _controller!.play();
                });
              },
              child: VideoPlayer(_controller!),
            )
          else if (_error.isNotEmpty)
            Text(
              _error,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          if (_ready && !_controller!.value.isBuffering)
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          if (_ready && !_controller!.value.isPlaying)
            const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 78,
            ),
        ],
      ),
    );
  }
}
