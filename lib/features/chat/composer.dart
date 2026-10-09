part of 'chat_page.dart';

// Step 27: split out of chat_page.dart without behaviour changes.
// The composer: text field, attachments, voice recording, emoji and
// mention suggestions.

class _MentionSuggestions extends StatelessWidget {
  const _MentionSuggestions({required this.targets, required this.onSelect});

  final List<ChatMentionTarget> targets;
  final ValueChanged<ChatMentionTarget> onSelect;

  String _initials(ChatMentionTarget target) {
    final source = target.displayName.trim().isNotEmpty
        ? target.displayName.trim()
        : target.accountTag.trim();
    final parts = source
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '@';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor, width: 1),
        boxShadow: BrandTheme.basePillShadow(isDark: false),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < targets.length; i += 1) ...[
              _MentionSuggestionChip(
                target: targets[i],
                initials: _initials(targets[i]),
                onTap: () => onSelect(targets[i]),
              ),
              if (i != targets.length - 1) const SizedBox(width: kGap8),
            ],
          ],
        ),
      ),
    );
  }
}

class _MentionSuggestionChip extends StatelessWidget {
  const _MentionSuggestionChip({
    required this.target,
    required this.initials,
    required this.onTap,
  });

  final ChatMentionTarget target;
  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.fromLTRB(7, 6, 12, 6),
        decoration: pillDecoration(
          isDark: false,
          radius: 999,
        ).copyWith(border: Border.all(color: kBorderColor, width: 1)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: BrandTheme.darkPillGradient,
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: target.avatarUrl.isEmpty
                  ? Text(
                      initials,
                      style: BrandTheme.pillText.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: target.avatarUrl,
                      fit: BoxFit.cover,
                      width: 32,
                      height: 32,
                      errorWidget: (_, _, _) => Text(
                        initials,
                        style: BrandTheme.pillText.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: kGap8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    target.handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BrandTheme.pillText.copyWith(
                      color: BrandTheme.redTop,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    target.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kTextMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PendingAttachmentKind { image, video, file, audio }

class _PendingChatAttachment {
  const _PendingChatAttachment({
    required this.kind,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.previewBytes,
    this.duration,
    this.file,
    this.bytes,
  });

  final _PendingAttachmentKind kind;
  final XFile? file;
  final String fileName;
  final int? fileSize;
  final String mimeType;
  final Duration? duration;
  final Uint8List? bytes;
  final Uint8List? previewBytes;

  bool get isImage => kind == _PendingAttachmentKind.image;
  bool get isVideo => kind == _PendingAttachmentKind.video;
  bool get isFile => kind == _PendingAttachmentKind.file;
  bool get isAudio => kind == _PendingAttachmentKind.audio;
  String get mediaType => switch (kind) {
    _PendingAttachmentKind.image => 'image',
    _PendingAttachmentKind.video => 'video',
    _PendingAttachmentKind.file => 'file',
    _PendingAttachmentKind.audio => 'audio',
  };
}

/// Telegram-style voice recording inside the composer (web v2): recording
/// starts at once, one click sends, ✕ discards.
class _InlineVoiceRecorder extends StatefulWidget {
  const _InlineVoiceRecorder({required this.onCancel, required this.onSend});

  final VoidCallback onCancel;
  final ValueChanged<_PendingChatAttachment> onSend;

  @override
  State<_InlineVoiceRecorder> createState() => _InlineVoiceRecorderState();
}

class _InlineVoiceRecorderState extends State<_InlineVoiceRecorder> {
  final _recorder = AudioRecorder();
  final _keyFocus = FocusNode(debugLabel: 'voice-recorder');
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  void Function()? _stopWebLevels;
  bool _recording = false;
  bool _finishing = false;
  Duration _duration = Duration.zero;
  DateTime? _startedAt;
  String _error = '';
  final List<double> _levels = List<double>.filled(56, 0.08);

  @override
  void initState() {
    super.initState();
    unawaited(_start());
    // Keys are handled globally: after clicking the mic the Flutter view
    // may not hand focus to this widget, and Enter / Esc must still work.
    HardwareKeyboard.instance.addHandler(_handleKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyFocus.requestFocus();
    });
  }

  bool _handleKey(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      unawaited(_finishAndSend());
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _timer?.cancel();
    _stopWebLevels?.call();
    _keyFocus.dispose();
    unawaited(_amplitudeSub?.cancel());
    unawaited(_recorder.cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  void _pushLevel(double level) {
    if (!mounted || !_recording) return;
    setState(() {
      _levels
        ..removeAt(0)
        ..add(level.clamp(0.08, 1.0));
    });
  }

  Future<String> _recordingPath() async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) return 'voice_$stamp.m4a';
    final dir = await getTemporaryDirectory();
    return '${dir.path}/voice_$stamp.m4a';
  }

  bool get _ru => Localizations.localeOf(context).languageCode == 'ru';

  Future<void> _start() async {
    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        if (!mounted) return;
        final ru = _ru;
        setState(
          () => _error = ru
              ? 'Нет доступа к микрофону. Разрешите микрофон в браузере.'
              : 'Microphone access is disabled. Allow it in the browser.',
        );
        return;
      }
      final path = await _recordingPath();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      if (kIsWeb) {
        try {
          _stopWebLevels = await WebMicLevels.start(_pushLevel);
        } catch (_) {
          // No level meter: the timer still shows that recording is on.
        }
      } else {
        _amplitudeSub = _recorder
            .onAmplitudeChanged(const Duration(milliseconds: 80))
            .listen((amplitude) {
              final current = amplitude.current.isFinite
                  ? amplitude.current
                  : -60.0;
              _pushLevel(((current + 55) / 55).clamp(0.08, 1.0).toDouble());
            });
      }
      _startedAt = DateTime.now();
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        final started = _startedAt;
        if (started == null) return;
        setState(() => _duration = DateTime.now().difference(started));
      });
      if (!mounted) return;
      setState(() => _recording = true);
    } catch (_) {
      if (!mounted) return;
      final ru = _ru;
      setState(
        () => _error = ru
            ? 'Не удалось начать запись.'
            : 'Could not start recording.',
      );
    }
  }

  Future<void> _finishAndSend() async {
    if (_finishing || !_recording) return;
    setState(() => _finishing = true);
    try {
      _timer?.cancel();
      _stopWebLevels?.call();
      _stopWebLevels = null;
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      final path = await _recorder.stop();
      if (path == null || path.trim().isEmpty) {
        throw StateError('Файл записи не создан');
      }
      final bytes = await XFile(path).readAsBytes();
      if (bytes.isEmpty) throw StateError('Файл записи пустой');
      final started = _startedAt;
      final duration = started == null
          ? _duration
          : DateTime.now().difference(started);
      if (duration < const Duration(milliseconds: 600)) {
        // Too short to be a message: treat as an accidental click.
        widget.onCancel();
        return;
      }
      final stamp = DateTime.now().millisecondsSinceEpoch;
      widget.onSend(
        _PendingChatAttachment(
          file: XFile(path),
          kind: _PendingAttachmentKind.audio,
          fileName: 'voice_$stamp.m4a',
          fileSize: bytes.length,
          mimeType: 'audio/mp4',
          duration: duration,
          bytes: bytes,
          previewBytes: null,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final ru = Localizations.localeOf(context).languageCode == 'ru';
      setState(() {
        _finishing = false;
        _recording = false;
        _error = ru
            ? 'Не удалось сохранить запись.'
            : 'Could not save the recording.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    if (_error.isNotEmpty) {
      return SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.mic_off_rounded, size: 20, color: Tokens.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.small.copyWith(color: Tokens.danger),
              ),
            ),
            TextButton(
              onPressed: widget.onCancel,
              child: Text(ru ? 'Закрыть' : 'Close'),
            ),
          ],
        ),
      );
    }
    return Focus(
      focusNode: _keyFocus,
      child: SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            tooltip: ru ? 'Отменить запись (Esc)' : 'Discard recording (Esc)',
            onPressed: _finishing ? null : widget.onCancel,
            icon: const Icon(Icons.delete_outline_rounded, color: Tokens.ink),
          ),
          const SizedBox(width: 4),
          const _RecordingDot(),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              _formatVoiceDuration(_duration),
              style: AppText.smallStrong.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LiveVoiceWaveform(levels: _levels, active: _recording),
          ),
          const SizedBox(width: 12),
          Text(
            ru ? 'Запись…' : 'Recording…',
            style: AppText.caption.copyWith(color: Tokens.textSecondary),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: ru
                ? 'Отправить голосовое (Enter)'
                : 'Send voice message (Enter)',
            onPressed: _finishing || !_recording ? null : _finishAndSend,
            icon: _finishing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, color: BrandTheme.redTop),
          ),
        ],
      ),
      ),
    );
  }
}

class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Tokens.accent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _VoiceRecorderSheet extends StatefulWidget {
  const _VoiceRecorderSheet();

  @override
  State<_VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<_VoiceRecorderSheet> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  Timer? _timer;
  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  bool _recording = false;
  bool _saving = false;
  bool _playing = false;
  bool _locked = false;
  Duration _duration = Duration.zero;
  DateTime? _recordStartedAt;
  String? _recordedPath;
  Uint8List? _recordedBytes;
  String _error = '';
  final List<double> _levels = List<double>.filled(34, 0.16);

  bool get _isRussian => Localizations.localeOf(context).languageCode == 'ru';

  @override
  void initState() {
    super.initState();
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_amplitudeSub?.cancel());
    unawaited(_playerStateSub?.cancel());
    unawaited(_recorder.cancel());
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<String> _recordingPath() async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) return 'voice_$stamp.m4a';
    final dir = await getTemporaryDirectory();
    return '${dir.path}/voice_$stamp.m4a';
  }

  Future<void> _start() async {
    setState(() => _error = '');
    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        if (!mounted) return;
        setState(() {
          _error = _isRussian
              ? 'Нет доступа к микрофону. Разрешите микрофон в настройках.'
              : 'Microphone access is disabled. Allow it in your settings.';
        });
        return;
      }
      await _player.stop();
      final path = await _recordingPath();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      _amplitudeSub?.cancel();
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 90))
          .listen(_handleAmplitude);
      _timer?.cancel();
      _recordStartedAt = DateTime.now();
      _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        final started = _recordStartedAt;
        if (started == null) return;
        setState(() => _duration = DateTime.now().difference(started));
      });
      setState(() {
        _recording = true;
        _locked = false;
        _recordedPath = null;
        _recordedBytes = null;
        _duration = Duration.zero;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = _isRussian
            ? 'Не удалось начать запись.'
            : 'Could not start recording.',
      );
    }
  }

  void _handleAmplitude(Amplitude amplitude) {
    if (!mounted || !_recording) return;
    final current = amplitude.current.isFinite ? amplitude.current : -60.0;
    final normalized = ((current + 55) / 55).clamp(0.08, 1.0).toDouble();
    setState(() {
      _levels
        ..removeAt(0)
        ..add(normalized);
    });
  }

  Future<void> _stop() async {
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final path = await _recorder.stop();
      _timer?.cancel();
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      if (path == null || path.trim().isEmpty) {
        throw StateError('Файл записи не создан');
      }
      final bytes = await XFile(path).readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('Файл записи пустой');
      }
      if (!mounted) return;
      final started = _recordStartedAt;
      setState(() {
        _recording = false;
        _locked = false;
        if (started != null) {
          _duration = DateTime.now().difference(started);
        }
        _recordedPath = path;
        _recordedBytes = bytes;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = _isRussian
            ? 'Не удалось сохранить запись.'
            : 'Could not save the recording.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _timer?.cancel();
      await _amplitudeSub?.cancel();
      _amplitudeSub = null;
      if (_recording) {
        await _recorder.cancel();
      }
    } catch (_) {
      // Cancel is a user escape hatch; keep the UI responsive.
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _saving = false;
      _playing = false;
      _locked = false;
      _duration = Duration.zero;
      _recordStartedAt = null;
      _recordedPath = null;
      _recordedBytes = null;
      _error = '';
      for (var i = 0; i < _levels.length; i++) {
        _levels[i] = 0.16;
      }
    });
  }

  Future<void> _togglePreview() async {
    final path = _recordedPath;
    if (path == null || path.isEmpty) return;
    try {
      if (_playing) {
        await _player.pause();
        return;
      }
      if (_player.audioSource == null) {
        if (kIsWeb) {
          await _player.setUrl(path);
        } else {
          await _player.setFilePath(path);
        }
      }
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = _isRussian
            ? 'Не удалось прослушать запись.'
            : 'Could not play the recording.',
      );
    }
  }

  void _reset() {
    _timer?.cancel();
    unawaited(_amplitudeSub?.cancel());
    _amplitudeSub = null;
    unawaited(_player.stop());
    setState(() {
      _recording = false;
      _saving = false;
      _playing = false;
      _locked = false;
      _duration = Duration.zero;
      _recordStartedAt = null;
      _recordedPath = null;
      _recordedBytes = null;
      _error = '';
    });
  }

  void _attach() {
    final bytes = _recordedBytes;
    final path = _recordedPath;
    if (bytes == null || bytes.isEmpty || path == null || path.isEmpty) return;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    Navigator.of(context).pop(
      _PendingChatAttachment(
        file: XFile(path),
        kind: _PendingAttachmentKind.audio,
        fileName: 'voice_$stamp.m4a',
        fileSize: bytes.length,
        mimeType: 'audio/mp4',
        duration: _duration,
        bytes: bytes,
        previewBytes: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRussian = Localizations.localeOf(context).languageCode == 'ru';
    final hasRecording = _recordedBytes != null && _recordedBytes!.isNotEmpty;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 14, right: 14, bottom: bottomInset + 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: BrandTheme.basePillShadow(isDark: false),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isRussian ? 'ГОЛОСОВОЕ' : 'VOICE MESSAGE',
              style: TextStyle(
                color: kTextDark,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (_recording && !_saving && velocity < -420) {
                  unawaited(_cancelRecording());
                }
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: kBorderColor),
                  boxShadow: BrandTheme.basePillShadow(isDark: false),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: _recording ? BrandTheme.redTop : kTextDark,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _recording
                            ? Icons.graphic_eq_rounded
                            : hasRecording
                            ? Icons.check_rounded
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _recording
                                ? (_locked
                                      ? (isRussian
                                            ? 'ЗАПИСЬ ЗАФИКСИРОВАНА'
                                            : 'RECORDING LOCKED')
                                      : (isRussian
                                            ? 'ИДЕТ ЗАПИСЬ'
                                            : 'RECORDING'))
                                : hasRecording
                                ? (isRussian
                                      ? 'ЗАПИСЬ ГОТОВА'
                                      : 'RECORDING READY')
                                : (isRussian
                                      ? 'НАЖМИТЕ, ЧТОБЫ НАЧАТЬ'
                                      : 'TAP TO START'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kTextDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _LiveVoiceWaveform(
                            levels: _levels,
                            active: _recording || _playing,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatVoiceDuration(_duration),
                      style: const TextStyle(
                        color: kTextDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _recording && !_locked
                  ? Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.keyboard_arrow_left_rounded,
                            color: kTextMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            isRussian
                                ? 'Свайп влево — отменить'
                                : 'Swipe left to cancel',
                            style: const TextStyle(
                              color: kTextMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BrandTheme.redTop,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_recording)
              Row(
                children: [
                  Expanded(
                    child: _SheetPillButton(
                      label: isRussian ? 'ОТМЕНИТЬ' : 'CANCEL',
                      onTap: _saving ? null : _cancelRecording,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _VoiceLockButton(
                    locked: _locked,
                    onTap: _saving
                        ? null
                        : () => setState(() => _locked = !_locked),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetPillButton(
                      label: isRussian ? 'ГОТОВО' : 'DONE',
                      dark: true,
                      loading: _saving,
                      onTap: _saving ? null : _stop,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _SheetPillButton(
                      label: hasRecording
                          ? (_playing
                                ? (isRussian ? 'ПАУЗА' : 'PAUSE')
                                : (isRussian ? 'ПРОСЛУШАТЬ' : 'PLAY'))
                          : (isRussian ? 'ЗАПИСЬ' : 'RECORD'),
                      dark: !hasRecording,
                      loading: _saving,
                      onTap: _saving
                          ? null
                          : hasRecording
                          ? _togglePreview
                          : _start,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetPillButton(
                      label: hasRecording
                          ? (isRussian ? 'ПРИКРЕПИТЬ' : 'ATTACH')
                          : (isRussian ? 'ЗАКРЫТЬ' : 'CLOSE'),
                      dark: hasRecording,
                      onTap: hasRecording
                          ? _attach
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _recording
                  ? Text(
                      _locked
                          ? (isRussian
                                ? 'Можно отпустить экран — запись продолжается.'
                                : 'You can release the screen — recording continues.')
                          : (isRussian
                                ? 'Нажмите на замок, чтобы не удерживать запись.'
                                : 'Tap the lock to record hands-free.'),
                      key: ValueKey(_locked),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : hasRecording
                  ? _SheetPillButton(
                      label: isRussian
                          ? 'УДАЛИТЬ И ЗАПИСАТЬ ЗАНОВО'
                          : 'DELETE AND RECORD AGAIN',
                      onTap: _reset,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceLockButton extends StatelessWidget {
  const _VoiceLockButton({required this.locked, required this.onTap});

  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.42,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: locked ? BrandTheme.redTop : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: kBorderColor),
              boxShadow: BrandTheme.basePillShadow(isDark: false),
            ),
            child: Icon(
              locked ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: locked ? Colors.white : kTextDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveVoiceWaveform extends StatelessWidget {
  const _LiveVoiceWaveform({required this.levels, required this.active});

  final List<double> levels;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      width: double.infinity,
      child: CustomPaint(
        painter: _LiveVoiceWaveformPainter(levels: levels, active: active),
      ),
    );
  }
}

class _LiveVoiceWaveformPainter extends CustomPainter {
  const _LiveVoiceWaveformPainter({required this.levels, required this.active});

  final List<double> levels;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty || size.width <= 0 || size.height <= 0) return;
    final bars = levels.length;
    final step = size.width / bars;
    final barWidth = math.min(4.0, step * 0.56);
    final radius = Radius.circular(barWidth);
    final paint = Paint()
      ..color = active ? BrandTheme.redTop : kTextDark.withValues(alpha: 0.24)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < bars; i++) {
      final level = levels[i].clamp(0.08, 1.0);
      final height = math.max(3.0, size.height * level);
      final x = i * step + (step - barWidth) / 2;
      final y = (size.height - height) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, height), radius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LiveVoiceWaveformPainter oldDelegate) {
    return true;
  }
}

class _SheetPillButton extends StatelessWidget {
  const _SheetPillButton({
    required this.label,
    required this.onTap,
    this.dark = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool dark;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Opacity(
      opacity: enabled || loading ? 1 : 0.42,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: loading ? null : onTap,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: dark && enabled ? BrandTheme.darkPillGradient : null,
              color: dark && enabled ? null : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kBorderColor),
              boxShadow: BrandTheme.basePillShadow(isDark: false),
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: dark && enabled ? Colors.white : kTextDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hintText,
    required this.sending,
    required this.replyingToText,
    required this.attachment,
    required this.onCancelReply,
    required this.onRemoveAttachment,
    this.queuedAttachments = 0,
    required this.onSend,
    required this.onAttach,
    required this.onRecordVoice,
    this.editingText,
    this.onCancelEdit,
    this.focusNode,
    this.recorder,
    this.onInsertEmoji,
    this.onEditLast,
    this.flat = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;

  /// ↑ in an empty field (web): edit the latest own message.
  final VoidCallback? onEditLast;

  /// Shows the emoji button when set (web).
  final ValueChanged<String>? onInsertEmoji;

  /// When set, replaces the text row with an inline voice recorder.
  final Widget? recorder;
  final String hintText;
  final bool sending;
  final String? replyingToText;

  /// Original text of the message being edited; shows an "editing" banner
  /// and turns the send button into "save".
  final String? editingText;
  final VoidCallback? onCancelEdit;
  final _PendingChatAttachment? attachment;
  final VoidCallback onCancelReply;
  final VoidCallback onRemoveAttachment;

  /// Step 34: how many more files wait behind [attachment].
  final int queuedAttachments;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onRecordVoice;

  /// v2: white field with a hairline border, no shadow.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: flat
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(Tokens.radiusLg),
              color: Tokens.bg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.92),
              border: Border.all(color: kBorderColor, width: 1),
              boxShadow: BrandTheme.basePillShadow(isDark: false),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (editingText != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(
                color: flat
                    ? Tokens.surface
                    : kTextDark.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(flat ? 10 : 16),
                border: flat
                    ? const Border(
                        left: BorderSide(color: Tokens.accent, width: 3),
                      )
                    : Border.all(color: kBorderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: flat ? Tokens.accent : BrandTheme.redTop,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Localizations.localeOf(context).languageCode == 'ru'
                              ? 'Редактирование'
                              : 'Editing',
                          style: flat
                              ? AppText.caption.copyWith(
                                  color: Tokens.accent,
                                  fontWeight: FontWeight.w600,
                                )
                              : const TextStyle(
                                  color: BrandTheme.redTop,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                        ),
                        Text(
                          editingText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: flat
                              ? AppText.caption.copyWith(fontSize: 13)
                              : const TextStyle(
                                  color: kTextMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: Localizations.localeOf(context).languageCode == 'ru'
                        ? 'Отменить (Esc)'
                        : 'Cancel (Esc)',
                    onPressed: onCancelEdit,
                    icon: Icon(
                      Icons.close_rounded,
                      color: flat ? Tokens.textSecondary : kTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (replyingToText != null && replyingToText!.trim().isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                color: kTextDark.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorderColor),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.reply_rounded,
                    size: 18,
                    color: BrandTheme.redTop,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      replyingToText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onCancelReply,
                    icon: const Icon(Icons.close_rounded, color: kTextMuted),
                  ),
                ],
              ),
            ),
          ],
          if (attachment != null) ...[
            _PendingAttachmentPreview(
              attachment: attachment!,
              onRemove: onRemoveAttachment,
              flat: flat,
              queued: queuedAttachments,
            ),
            const SizedBox(height: 8),
          ],
          if (recorder != null)
            recorder!
          else
          Row(
            children: [
              if (editingText == null)
                IconButton(
                  tooltip: flat ? 'Прикрепить' : null,
                  onPressed: sending ? null : onAttach,
                  style: flat ? _composerIconStyle : null,
                  icon: Icon(
                    Icons.add_rounded,
                    color: flat ? Tokens.textSecondary : kTextDark,
                    size: flat ? 24 : null,
                  ),
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: Focus(
                  // Desktop / web: Enter sends, Shift+Enter inserts a line
                  // break. Touch keyboards keep their own "new line" key.
                  onKeyEvent: !flat
                      ? null
                      : (node, event) {
                          if (event is! KeyDownEvent) {
                            return KeyEventResult.ignored;
                          }
                          final isEnter =
                              event.logicalKey == LogicalKeyboardKey.enter ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.numpadEnter;
                          if (event.logicalKey == LogicalKeyboardKey.escape) {
                            if (editingText != null) {
                              onCancelEdit?.call();
                              return KeyEventResult.handled;
                            }
                            if (replyingToText != null) {
                              onCancelReply();
                              return KeyEventResult.handled;
                            }
                            if (attachment != null) {
                              onRemoveAttachment();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
                              editingText == null &&
                              controller.text.isEmpty &&
                              onEditLast != null) {
                            onEditLast!();
                            return KeyEventResult.handled;
                          }
                          if (!isEnter) return KeyEventResult.ignored;
                          // Phone-width web: the soft keyboard's Enter adds
                          // a line, sending is the button.
                          if (MediaQuery.sizeOf(context).width < 600) {
                            return KeyEventResult.ignored;
                          }
                          final shift =
                              HardwareKeyboard.instance.isShiftPressed;
                          if (shift) return KeyEventResult.ignored;
                          if (!sending) onSend();
                          return KeyEventResult.handled;
                        },
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: flat ? 8 : 4,
                    textInputAction: TextInputAction.newline,
                    style: flat ? AppText.body : null,
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: flat
                          ? AppText.body.copyWith(color: Tokens.textTertiary)
                          : null,
                      border: InputBorder.none,
                      enabledBorder: flat ? InputBorder.none : null,
                      focusedBorder: flat ? InputBorder.none : null,
                      filled: flat ? false : null,
                      isDense: flat ? true : null,
                      contentPadding: flat
                          ? const EdgeInsets.symmetric(vertical: 12)
                          : null,
                    ),
                  ),
                ),
              ),
              if (onInsertEmoji != null)
                _EmojiPickerButton(onPick: onInsertEmoji!),
              if (editingText == null)
                IconButton(
                  tooltip: 'Голосовое сообщение',
                  onPressed: sending ? null : onRecordVoice,
                  style: flat ? _composerIconStyle : null,
                  icon: Icon(
                    flat ? Icons.mic_none_rounded : Icons.mic_rounded,
                    color: flat ? Tokens.textSecondary : kTextDark,
                  ),
                ),
              if (flat) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _SendButtonV2(
                    sending: sending,
                    editing: editingText != null,
                    onTap: sending ? null : onSend,
                  ),
                ),
              ] else
                IconButton(
                  tooltip: editingText != null
                      ? (Localizations.localeOf(context).languageCode == 'ru'
                            ? 'Сохранить (Enter)'
                            : 'Save (Enter)')
                      : null,
                  onPressed: sending ? null : onSend,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          editingText != null
                              ? Icons.check_circle_rounded
                              : Icons.send_rounded,
                          color: BrandTheme.redTop,
                        ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

const List<String> _emojiPalette = [
  '😀', '😁', '😂', '🤣', '😊', '😍', '🥰', '😘', '😎', '🤩', '🥳', '😏',
  '😉', '🙂', '🤔', '🤗', '😅', '😬', '🙄', '😴', '😢', '😭', '😡', '🤯',
  '👍', '👎', '👏', '🙏', '🤝', '👋', '✌️', '🤞', '💪', '👀', '🫶', '🙌',
  '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '💔', '💯', '🔥', '✨',
  '⭐', '🎉', '🎬', '📸', '🎥', '👗', '👠', '💄', '🕶️', '🧢', '👜', '💍',
  '✅', '❌', '❗', '❓', '⏰', '📅', '📍', '💬', '📎', '💡', '🚀', '🏆',
];

class _EmojiPickerButton extends StatelessWidget {
  const _EmojiPickerButton({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return PopupMenuButton<String>(
      tooltip: ru ? 'Эмодзи' : 'Emoji',
      onSelected: onPick,
      color: Tokens.bg,
      elevation: 6,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        side: const BorderSide(color: Tokens.border),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 12 * 34,
            height: 6 * 34,
            child: GridView.count(
              crossAxisCount: 12,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final emoji in _emojiPalette)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.of(context).pop(emoji),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      style: _composerIconStyle,
      icon: const Icon(
        Icons.sentiment_satisfied_alt_rounded,
        color: Tokens.textSecondary,
      ),
    );
  }
}

/// Composer icons: quiet by default, ink on hover.
final ButtonStyle _composerIconStyle = IconButton.styleFrom(
  foregroundColor: Tokens.textSecondary,
  hoverColor: Tokens.surfaceAlt,
  highlightColor: Tokens.surfaceAlt,
  shape: const CircleBorder(),
).copyWith(
  iconColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.hovered)
        ? Tokens.ink
        : Tokens.textSecondary,
  ),
);

class _SendButtonV2 extends StatelessWidget {
  const _SendButtonV2({
    required this.sending,
    required this.editing,
    required this.onTap,
  });

  final bool sending;
  final bool editing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return Tooltip(
      message: editing
          ? (ru ? 'Сохранить (Enter)' : 'Save (Enter)')
          : (ru ? 'Отправить (Enter)' : 'Send (Enter)'),
      child: Material(
        color: onTap == null ? Tokens.borderStrong : Tokens.ink,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: sending
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    editing ? Icons.check_rounded : Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
          ),
        ),
      ),
    );
  }
}

class _PendingAttachmentPreview extends StatelessWidget {
  const _PendingAttachmentPreview({
    required this.attachment,
    required this.onRemove,
    this.flat = false,
    this.queued = 0,
  });

  final _PendingChatAttachment attachment;
  final VoidCallback onRemove;
  final bool flat;

  /// Step 34: more files behind this one, sent right after it.
  final int queued;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final isFile = attachment.isFile;
    final isAudio = attachment.isAudio;
    final size = _formatFileSize(attachment.fileSize);
    if (flat) {
      final kindLabel = isFile
          ? attachment.fileName
          : isAudio
          ? (isRussian ? 'Голосовое' : 'Voice message') +
                (attachment.duration == null
                    ? ''
                    : ' · ${_formatVoiceDuration(attachment.duration!)}')
          : attachment.isVideo
          ? (isRussian ? 'Видео' : 'Video')
          : (isRussian ? 'Фото' : 'Photo');
      final icon = isAudio
          ? Icons.mic_none_rounded
          : isFile
          ? Icons.insert_drive_file_outlined
          : Icons.play_circle_outline_rounded;
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 0, 2),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child:
                    !isFile &&
                        !isAudio &&
                        !attachment.isVideo &&
                        attachment.previewBytes != null
                    ? Image.memory(attachment.previewBytes!, fit: BoxFit.cover)
                    : ColoredBox(
                        color: Tokens.surfaceAlt,
                        child: Icon(icon, color: Tokens.ink, size: 24),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kindLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.smallStrong,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (size.isNotEmpty) size,
                      if (queued > 0)
                        isRussian
                            ? 'ещё ${_pluralFilesRu(queued)} следом'
                            : '$queued more ${queued == 1 ? 'file' : 'files'} after it',
                      isRussian
                          ? 'Подпись — по желанию, Enter отправит'
                          : 'Caption is optional, Enter sends',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: isRussian ? 'Убрать' : 'Remove',
              onPressed: onRemove,
              style: _composerIconStyle,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: kTextDark.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 74,
              height: 74,
              child: isAudio
                  ? Container(
                      color: kTextDark,
                      child: const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    )
                  : isFile
                  ? Container(
                      color: kTextDark,
                      child: const Icon(
                        Icons.insert_drive_file_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    )
                  : attachment.isVideo
                  ? Container(
                      color: kTextDark,
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    )
                  : attachment.previewBytes == null
                  ? Container(color: Colors.white)
                  : Image.memory(attachment.previewBytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFile
                      ? (isRussian ? 'ФАЙЛ ГОТОВ' : 'FILE READY')
                      : isAudio
                      ? (isRussian ? 'ГОЛОСОВОЕ ГОТОВО' : 'VOICE READY')
                      : attachment.isVideo
                      ? (isRussian ? 'ВИДЕО ГОТОВО' : 'VIDEO READY')
                      : (isRussian ? 'ФОТО ГОТОВО' : 'PHOTO READY'),
                  style: const TextStyle(
                    color: kTextDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFile
                      ? [
                          attachment.fileName,
                          if (size.isNotEmpty) size,
                        ].where((e) => e.trim().isNotEmpty).join(' • ')
                      : isAudio
                      ? [
                          isRussian
                              ? 'Можно добавить подпись и отправить.'
                              : 'You can add a caption and send.',
                          if (size.isNotEmpty) size,
                        ].where((e) => e.trim().isNotEmpty).join(' • ')
                      : isRussian
                      ? 'Добавьте подпись и нажмите отправить.'
                      : 'Add a caption and tap send.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kTextMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}

class _ChatUploadProgress extends StatelessWidget {
  const _ChatUploadProgress();

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kTextDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: BrandTheme.basePillShadow(isDark: true),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isRussian ? 'ЗАГРУЗКА МЕДИА' : 'UPLOADING MEDIA',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kBorderColor),
          boxShadow: BrandTheme.basePillShadow(isDark: false),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 18, height: 18, child: _TypingDots()),
            const SizedBox(width: 10),
            Text(
              isRussian ? 'ПЕЧАТАЕТ...' : 'TYPING...',
              style: const TextStyle(
                color: kTextMuted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (index) {
            final value = (_controller.value + index / 3) % 1;
            final opacity = value < 0.5 ? 1.0 : 0.35;
            return Opacity(
              opacity: opacity,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: kTextMuted,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
