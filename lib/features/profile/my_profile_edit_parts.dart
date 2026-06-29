part of 'my_profile_edit_page.dart';

class _ProfileQuality {
  const _ProfileQuality({required this.percent, required this.missing});

  final int percent;
  final List<String> missing;

  bool get isStrong => percent >= 80;
}

String _profileTypeLabel(AppLocalizations t, ProfessionalProfileType type) {
  return switch (type) {
    ProfessionalProfileType.model => t.profileTypeModel,
    ProfessionalProfileType.actor => t.profileTypeActor,
    ProfessionalProfileType.photographer => t.profileTypePhotographer,
    ProfessionalProfileType.videographer => t.profileTypeVideographer,
    ProfessionalProfileType.stylist => t.profileTypeStylist,
    ProfessionalProfileType.makeupArtist => t.profileTypeMakeupArtist,
    ProfessionalProfileType.hairStylist => t.profileTypeHairStylist,
  };
}

String _professionalExperienceLabel(
  AppLocalizations t,
  ProfessionalProfileType type,
) {
  return switch (type) {
    ProfessionalProfileType.actor => t.profileActingExperience,
    _ => t.profileExperience,
  };
}

String _professionalSkillsLabel(
  AppLocalizations t,
  ProfessionalProfileType type,
) {
  return switch (type) {
    ProfessionalProfileType.actor => t.profileActorSkills,
    _ => t.profileSkills,
  };
}

String _professionalServicesLabel(
  AppLocalizations t,
  ProfessionalProfileType type,
) {
  return switch (type) {
    ProfessionalProfileType.actor => t.profileActorRoles,
    _ => t.profileServices,
  };
}

String _professionalGenresLabel(
  AppLocalizations t,
  ProfessionalProfileType type,
) {
  return switch (type) {
    ProfessionalProfileType.actor => t.profileActingGenres,
    ProfessionalProfileType.photographer => t.profilePhotoGenres,
    ProfessionalProfileType.videographer => t.profileVideoGenres,
    _ => t.profileWorkGenres,
  };
}

class _ProfileTypeSelector extends StatelessWidget {
  const _ProfileTypeSelector({required this.selected, required this.onChanged});

  final ProfessionalProfileType selected;
  final ValueChanged<ProfessionalProfileType> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(t.profileTypeUpper),
        const SizedBox(height: kGap10),
        Wrap(
          spacing: kGap8,
          runSpacing: kGap8,
          children: [
            for (final type in ProfessionalProfileType.values)
              _ProfileTypeChip(
                label: _profileTypeLabel(t, type),
                selected: type == selected,
                onTap: () => onChanged(type),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProfileTypeChip extends StatelessWidget {
  const _ProfileTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kAnim160,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: pillDecoration(isDark: selected, radius: 999).copyWith(
          border: Border.all(
            color: selected ? Colors.transparent : kBorderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : kTextDark,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ProfileQualityCard extends StatelessWidget {
  const _ProfileQualityCard({required this.quality});

  final _ProfileQuality quality;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final progress = quality.percent / 100;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: pillDecoration(
        isDark: false,
        radius: kSearchRadius,
      ).copyWith(border: Border.all(color: kBorderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.profileQualityComplete(quality.percent),
                  style: const TextStyle(
                    color: kTextDark,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Icon(
                quality.isStrong
                    ? Icons.check_circle_rounded
                    : Icons.info_rounded,
                color: quality.isStrong ? BrandTheme.redTop : kTextMuted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: kBorderColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                quality.isStrong ? BrandTheme.redTop : kTextDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (quality.isStrong)
            _ProfileQualityLine(text: t.profileQualityReady, done: true)
          else
            for (final item in quality.missing)
              _ProfileQualityLine(text: item, done: false),
        ],
      ),
    );
  }
}

class _ProfileQualityLine extends StatelessWidget {
  const _ProfileQualityLine({required this.text, required this.done});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done ? Icons.check_rounded : Icons.add_rounded,
            color: done ? BrandTheme.redTop : kTextMuted,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: kTextMuted,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaBlock extends StatelessWidget {
  const _MediaBlock({
    this.desktop = false,
    required this.uploading,
    required this.onAddPhoto,
    required this.onAddVideo,
    required this.photoUrls,
    required this.coverPhotoUrl,
    required this.videoUrls,
    required this.videoPreviewUrls,
    required this.pendingPhotoUrls,
    required this.pendingCoverPhotoUrl,
    required this.pendingVideoUrls,
    required this.pendingVideoPreviewUrls,
    required this.pickedPhotos,
    required this.pickedCoverPhotoIndex,
    required this.pickedVideos,
    required this.onRemovePhoto,
    required this.onRemoveVideo,
    required this.onMakeCoverPhoto,
  });

  final bool desktop;
  final bool uploading;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddVideo;

  final List<String> photoUrls;
  final String coverPhotoUrl;
  final List<String> videoUrls;
  final List<String> videoPreviewUrls;
  final List<String> pendingPhotoUrls;
  final String pendingCoverPhotoUrl;
  final List<String> pendingVideoUrls;
  final List<String> pendingVideoPreviewUrls;

  final List<XFile> pickedPhotos;
  final int? pickedCoverPhotoIndex;
  final List<XFile> pickedVideos;
  final Future<void> Function(int index, {required bool isPicked})
  onRemovePhoto;
  final Future<void> Function(int index, {required bool isPicked})
  onRemoveVideo;
  final void Function(int index, {required bool isPicked}) onMakeCoverPhoto;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final hasAnything =
        photoUrls.isNotEmpty ||
        videoUrls.isNotEmpty ||
        pendingPhotoUrls.isNotEmpty ||
        pendingVideoUrls.isNotEmpty ||
        pickedPhotos.isNotEmpty ||
        pickedVideos.isNotEmpty;
    final hasPhotos =
        photoUrls.isNotEmpty ||
        pendingPhotoUrls.isNotEmpty ||
        pickedPhotos.isNotEmpty;
    final hasVideo =
        videoUrls.isNotEmpty ||
        pendingVideoUrls.isNotEmpty ||
        pickedVideos.isNotEmpty;
    final thumbSize = desktop ? 112.0 : kProfileThumbSize;
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: BrandPillButton(
                label: t.profileAddPhotoUpper,
                style: BrandPillStyle.light,
                onTap: () {
                  if (uploading) return;
                  onAddPhoto();
                },
              ),
            ),
            const SizedBox(width: kGap10),
            Expanded(
              child: BrandPillButton(
                label: t.profileAddVideoUpper,
                style: BrandPillStyle.light,
                onTap: () {
                  if (uploading) return;
                  onAddVideo();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: kGap12),
        Container(
          constraints: BoxConstraints(
            minHeight: desktop ? 250 : kProfileMediaPreviewMinHeight,
          ),
          decoration: profileMediaBoxDecoration(),
          alignment: Alignment.center,
          padding: kProfileMediaInnerPad,
          child: Stack(
            children: [
              if (!hasAnything)
                Center(
                  child: uploading
                      ? const CircularProgressIndicator()
                      : Text(
                          t.profileMediaPreviewPlaceholder,
                          style: const TextStyle(color: kTextMuted),
                        ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasPhotos)
                      _ThumbRow(
                        wrap: desktop,
                        size: thumbSize,
                        urls: photoUrls,
                        coverUrl: coverPhotoUrl,
                        pendingUrls: pendingPhotoUrls,
                        pendingCoverUrl: pendingCoverPhotoUrl,
                        files: pickedPhotos,
                        pickedCoverIndex: pickedCoverPhotoIndex,
                        onRemove: onRemovePhoto,
                        onMakeCover: onMakeCoverPhoto,
                      ),
                    if (hasVideo) ...[
                      const SizedBox(height: kGap10),
                      _VideoThumbRow(
                        wrap: desktop,
                        size: thumbSize,
                        urls: videoUrls,
                        previewUrls: videoPreviewUrls,
                        pendingUrls: pendingVideoUrls,
                        pendingPreviewUrls: pendingVideoPreviewUrls,
                        files: pickedVideos,
                        onRemove: onRemoveVideo,
                      ),
                    ],
                  ],
                ),
              if (uploading && hasAnything) ...[
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
                if (desktop)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.72),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: pillDecoration(isDark: true, radius: 999),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isRussian ? 'ЗАГРУЗКА МЕДИА' : 'UPLOADING MEDIA',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoThumbRow extends StatelessWidget {
  const _VideoThumbRow({
    this.wrap = false,
    required this.size,
    required this.urls,
    required this.previewUrls,
    required this.pendingUrls,
    required this.pendingPreviewUrls,
    required this.files,
    required this.onRemove,
  });

  final bool wrap;
  final double size;
  final List<String> urls;
  final List<String> previewUrls;
  final List<String> pendingUrls;
  final List<String> pendingPreviewUrls;
  final List<XFile> files;
  final Future<void> Function(int index, {required bool isPicked}) onRemove;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      for (int i = 0; i < urls.length; i++)
        _VideoThumb(
          size: size,
          url: urls[i],
          previewUrl: i < previewUrls.length ? previewUrls[i] : null,
          onRemove: () => onRemove(i, isPicked: false),
        ),
      for (int i = 0; i < pendingUrls.length; i++)
        _VideoThumb(
          size: size,
          url: pendingUrls[i],
          previewUrl: i < pendingPreviewUrls.length
              ? pendingPreviewUrls[i]
              : null,
          pending: true,
        ),
      for (int i = 0; i < files.length; i++)
        _VideoThumb(
          size: size,
          file: files[i],
          onRemove: () => onRemove(i, isPicked: true),
        ),
    ];

    if (wrap) {
      return Wrap(spacing: kGap10, runSpacing: kGap10, children: items);
    }

    return SizedBox(
      height: kProfileThumbSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: kGap10),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({
    required this.size,
    this.url,
    this.previewUrl,
    this.file,
    this.onRemove,
    this.pending = false,
  });

  final double size;
  final String? url;
  final String? previewUrl;
  final XFile? file;
  final VoidCallback? onRemove;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _VideoViewerPage(url: url, file: file),
          ),
        );
      },
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: profileVideoThumbDecoration(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _VideoThumbImage(url: url, previewUrl: previewUrl, file: file),
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: kOverlayStrong,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: kProfilePlayBadgePad,
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: kProfileVideoPlayIconSize,
                  ),
                ),
              ),
            ),
            if (pending) const _PendingMediaBadge(),
            if (onRemove != null)
              Positioned(
                top: kProfileRemoveButtonInset,
                right: kProfileRemoveButtonInset,
                child: _MediaRemoveButton(onTap: onRemove!),
              ),
          ],
        ),
      ),
    );
  }
}

class _PickedXFileImage extends StatelessWidget {
  const _PickedXFileImage({required this.file, this.fit = BoxFit.cover});

  final XFile file;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const _EmptyProfileImagePlaceholder();
        }

        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, _, _) => const _EmptyProfileImagePlaceholder(),
        );
      },
    );
  }
}

class _PickedPhotoViewerPage extends StatelessWidget {
  const _PickedPhotoViewerPage({this.url, this.file});

  final String? url;
  final XFile? file;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim() ?? '';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: file != null
                      ? _PickedXFileImage(file: file!, fit: BoxFit.contain)
                      : imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, _) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (_, _, _) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        )
                      : const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                ),
              ),
            ),
            Positioned(
              top: kProfileViewerBackInset,
              left: kProfileViewerBackInset,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoThumbImage extends StatefulWidget {
  const _VideoThumbImage({this.url, this.previewUrl, this.file});

  final String? url;
  final String? previewUrl;
  final XFile? file;

  @override
  State<_VideoThumbImage> createState() => _VideoThumbImageState();
}

class _VideoThumbImageState extends State<_VideoThumbImage> {
  VideoPlayerController? _controller;
  Future<void>? _init;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(covariant _VideoThumbImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.previewUrl != widget.previewUrl ||
        oldWidget.file?.path != widget.file?.path) {
      _disposeController();
      _setup();
    }
  }

  void _setup() {
    final controller = _videoControllerFor(file: widget.file, url: widget.url);
    _controller = controller;
    if (controller == null) return;

    _init = controller.initialize().then((_) async {
      await controller.setVolume(0);
      await controller.pause();
      if (mounted) setState(() {});
    });
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _init = null;
    controller?.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = widget.previewUrl?.trim() ?? '';
    if (previewUrl.isNotEmpty) {
      return _NetworkThumbImage(url: previewUrl);
    }

    final controller = _controller;
    final init = _init;

    if (controller == null || init == null) {
      return const _VideoThumbFallback(showProgress: false);
    }

    return FutureBuilder<void>(
      future: init,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return const _VideoThumbFallback(showProgress: true);
        }

        final aspectRatio = controller.value.aspectRatio;
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: aspectRatio >= 1 ? kProfileVideoThumbMaxWidth : 96,
            height: aspectRatio >= 1
                ? kProfileVideoThumbMaxWidth / aspectRatio
                : 96 / aspectRatio.clamp(0.2, 5),
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }
}

VideoPlayerController? _videoControllerFor({String? url, XFile? file}) {
  final videoUrl = url?.trim() ?? '';

  if (file != null) {
    final path = file.path.trim();
    if (path.isEmpty) return null;
    if (kIsWeb) {
      return VideoPlayerController.networkUrl(Uri.parse(path));
    }
    return VideoPlayerController.file(File(path));
  }

  if (videoUrl.isEmpty) return null;
  return VideoPlayerController.networkUrl(Uri.parse(videoUrl));
}

class _VideoThumbFallback extends StatelessWidget {
  const _VideoThumbFallback({required this.showProgress});

  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kVideoFallbackBg,
      alignment: Alignment.center,
      child: showProgress
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(
              Icons.videocam,
              color: kVideoFallbackIcon,
              size: kProfileVideoFallbackIconSize,
            ),
    );
  }
}

class _MediaRemoveButton extends StatelessWidget {
  const _MediaRemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: kProfileRemoveButtonSize,
        height: kProfileRemoveButtonSize,
        decoration: profileRemoveButtonDecoration(),
        child: const Center(
          child: Icon(
            Icons.close,
            size: kProfileRemoveIconSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MediaCoverButton extends StatelessWidget {
  const _MediaCoverButton({required this.selected, this.onTap});

  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    final message = selected
        ? (isRussian ? 'Главное фото анкеты' : 'Profile cover photo')
        : (isRussian ? 'Сделать главным фото' : 'Make cover photo');
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 350),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          button: true,
          selected: selected,
          label: message,
          child: Container(
            width: kProfileRemoveButtonSize,
            height: kProfileRemoveButtonSize,
            decoration: BoxDecoration(
              color: selected ? BrandTheme.redTop : kOverlayStrong,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
            ),
            child: Icon(
              selected ? Icons.star_rounded : Icons.star_border_rounded,
              size: 17,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverMediaBadge extends StatelessWidget {
  const _CoverMediaBadge();

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    return Positioned(
      left: 6,
      right: 6,
      bottom: 6,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: BrandTheme.redTop.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          ),
          child: Text(
            isRussian ? 'ГЛАВНОЕ ФОТО' : 'COVER PHOTO',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoViewerPage extends StatefulWidget {
  const _VideoViewerPage({this.url, this.file});

  final String? url;
  final XFile? file;

  @override
  State<_VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<_VideoViewerPage> {
  VideoPlayerController? _controller;
  Future<void>? _init;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final controller = _videoControllerFor(file: widget.file, url: widget.url);
    if (controller == null) return;

    _controller = controller;
    _init = controller.initialize().then((_) async {
      await controller.setLooping(true);
      if (mounted) setState(() {});
    });
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    if (c.value.isPlaying) {
      await c.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await c.play();
      if (mounted) setState(() => _playing = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final init = _init;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: (c == null || init == null)
                    ? const Icon(
                        Icons.videocam_off,
                        color: Colors.white,
                        size: kProfileVideoViewerFallbackIconSize,
                      )
                    : FutureBuilder<void>(
                        future: init,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done ||
                              !c.value.isInitialized) {
                            return const CircularProgressIndicator(
                              color: Colors.white,
                            );
                          }

                          return GestureDetector(
                            onTap: _togglePlay,
                            child: AspectRatio(
                              aspectRatio: c.value.aspectRatio == 0
                                  ? kProfileVideoAspectFallback
                                  : c.value.aspectRatio,
                              child: VideoPlayer(c),
                            ),
                          );
                        },
                      ),
              ),
            ),
            Positioned(
              top: kProfileViewerBackInset,
              left: kProfileViewerBackInset,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            if (c != null && c.value.isInitialized)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: kProfilePlusContainerDuration,
                      opacity: _playing ? 0 : 1,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: kOverlayMedium,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: kProfileViewerPlayBadgePad,
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: kProfileViewerPlayIconSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThumbRow extends StatelessWidget {
  const _ThumbRow({
    this.wrap = false,
    required this.size,
    required this.urls,
    required this.coverUrl,
    required this.pendingUrls,
    required this.pendingCoverUrl,
    required this.files,
    required this.pickedCoverIndex,
    required this.onRemove,
    required this.onMakeCover,
  });

  final bool wrap;
  final double size;
  final List<String> urls;
  final String coverUrl;
  final List<String> pendingUrls;
  final String pendingCoverUrl;
  final List<XFile> files;
  final int? pickedCoverIndex;
  final Future<void> Function(int index, {required bool isPicked}) onRemove;
  final void Function(int index, {required bool isPicked}) onMakeCover;

  @override
  Widget build(BuildContext context) {
    final selectedCoverUrl = coverUrl.trim();
    final fallbackCoverUrl = selectedCoverUrl.isNotEmpty
        ? selectedCoverUrl
        : (urls.isNotEmpty ? urls.first.trim() : '');
    final selectedPendingCoverUrl = pendingCoverUrl.trim();
    final hasPickedCover = pickedCoverIndex != null;
    final items = <Widget>[
      for (int i = 0; i < urls.length; i++)
        _Thumb(
          size: size,
          image: _NetworkThumbImage(url: urls[i], fit: BoxFit.cover),
          isCover: !hasPickedCover && urls[i].trim() == fallbackCoverUrl,
          onMakeCover: !hasPickedCover && urls[i].trim() == fallbackCoverUrl
              ? null
              : () => onMakeCover(i, isPicked: false),
          onRemove: () => onRemove(i, isPicked: false),
        ),
      for (final url in pendingUrls)
        _Thumb(
          size: size,
          image: _NetworkThumbImage(url: url, fit: BoxFit.cover),
          isCover:
              !hasPickedCover &&
              selectedPendingCoverUrl.isNotEmpty &&
              url.trim() == selectedPendingCoverUrl,
          pending: true,
        ),
      for (int i = 0; i < files.length; i++)
        _Thumb(
          size: size,
          image: _PickedXFileImage(file: files[i], fit: BoxFit.cover),
          isCover: hasPickedCover
              ? pickedCoverIndex == i
              : urls.isEmpty && pendingUrls.isEmpty && i == 0,
          onMakeCover:
              (hasPickedCover
                  ? pickedCoverIndex == i
                  : urls.isEmpty && pendingUrls.isEmpty && i == 0)
              ? null
              : () => onMakeCover(i, isPicked: true),
          onRemove: () => onRemove(i, isPicked: true),
        ),
    ];

    if (wrap) {
      return Wrap(spacing: kGap10, runSpacing: kGap10, children: items);
    }

    return SizedBox(
      height: kProfileThumbSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: kGap10),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.size,
    required this.image,
    this.isCover = false,
    this.onMakeCover,
    this.onRemove,
    this.pending = false,
  });

  final double size;
  final Widget image;
  final bool isCover;
  final VoidCallback? onMakeCover;
  final VoidCallback? onRemove;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final network = image is _NetworkThumbImage
            ? (image as _NetworkThumbImage).url
            : null;
        final picked = image is _PickedXFileImage
            ? (image as _PickedXFileImage).file
            : null;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _PickedPhotoViewerPage(url: network, file: picked),
          ),
        );
      },
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: profileThumbDecoration(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (isCover && !pending) const _CoverMediaBadge(),
            if (!pending)
              Positioned(
                left: _kMediaRemoveInset,
                top: _kMediaRemoveInset,
                child: _MediaCoverButton(selected: isCover, onTap: onMakeCover),
              ),
            if (pending) const _PendingMediaBadge(),
            if (onRemove != null)
              Positioned(
                top: _kMediaRemoveInset,
                right: _kMediaRemoveInset,
                child: _MediaRemoveButton(onTap: onRemove!),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingMediaBadge extends StatelessWidget {
  const _PendingMediaBadge();

  @override
  Widget build(BuildContext context) {
    final isRussian =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ru';
    return Positioned(
      left: 6,
      right: 6,
      bottom: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          isRussian ? 'НА МОДЕРАЦИИ' : 'PENDING',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _ProfileNameHelper {
  const _ProfileNameHelper._();

  static _NameParts split(String fullName) {
    final normalized = fullName.trim();
    final parts = normalized.isEmpty
        ? <String>[]
        : normalized.split(RegExp(r'\s+'));

    if (parts.length >= 2) {
      return (surname: parts.first, name: parts.sublist(1).join(' '));
    }
    if (parts.length == 1) {
      return (surname: '', name: parts.first);
    }
    return (surname: '', name: '');
  }

  static _NameParts resolveForSave({
    required bool isNewProfile,
    required String surnameInput,
    required String nameInput,
    required String fallbackFullName,
    required AppLocalizations t,
    required void Function(String message) setError,
  }) {
    final surname = surnameInput.trim();
    final name = nameInput.trim();

    if (isNewProfile) {
      if (surname.isEmpty) {
        setError(t.profileErrorSurnameRequired);
        throw const _ProfileNameResolveException();
      }
      if (name.isEmpty) {
        setError(t.profileErrorNameRequired);
        throw const _ProfileNameResolveException();
      }
      return (surname: surname, name: name);
    }

    if (surname.isEmpty && name.isEmpty) {
      final oldFullName = fallbackFullName.trim();
      if (oldFullName.isEmpty) {
        setError(t.profileErrorFullNameRequired);
        throw const _ProfileNameResolveException();
      }
      return split(oldFullName);
    }

    if (surname.isEmpty && name.isNotEmpty) {
      return (surname: '', name: name);
    }

    if (surname.isNotEmpty && name.isEmpty) {
      return (surname: '', name: surname);
    }

    return (surname: surname, name: name);
  }

  static String buildFullName(_NameParts parts) {
    return [
      parts.surname,
      parts.name,
    ].where((e) => e.trim().isNotEmpty).join(' ').trim();
  }
}

class _ProfileNameResolveException implements Exception {
  const _ProfileNameResolveException();
}

class _Header extends StatelessWidget {
  const _Header({required this.status, required this.comment});
  final ProfileStatus status;
  final String? comment;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    String title;
    String subtitle;
    Color tone;

    switch (status) {
      case ProfileStatus.pending:
        title = t.profileStatusPendingUpper;
        subtitle = t.profileStatusPendingSubtitle;
        tone = kProfileStatusNeutral;
        break;
      case ProfileStatus.approved:
        title = t.profileStatusApprovedUpper;
        subtitle = t.profileStatusApprovedSubtitle;
        tone = BrandTheme.redTop;
        break;
      case ProfileStatus.rejected:
        title = t.profileStatusRejectedUpper;
        subtitle = (comment ?? '').trim().isEmpty
            ? t.profileStatusRejectedSubtitleDefault
            : comment!.trim();
        tone = kProfileStatusRejected;
        break;
      case ProfileStatus.draft:
        title = t.profileStatusDraftUpper;
        subtitle = t.profileStatusDraftSubtitle;
        tone = kProfileStatusNeutral;
        break;
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: tone,
            ),
          ),
          const SizedBox(height: kGap8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: kProfileHeaderSubtitleTextStyle,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: kProfileSectionTitleStyle);
  }
}

class _Row2 extends StatelessWidget {
  const _Row2({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: kGap12),
        Expanded(child: right),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(color: kTextDark),
      decoration: profileFieldDecoration(label: label),
    );
  }
}

class _BrandedDialog extends StatelessWidget {
  const _BrandedDialog({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: kProfileDialogInsetPad,
      child: Container(
        padding: kProfileDialogPad,
        decoration: profileDialogDecoration(),
        child: child,
      ),
    );
  }
}

class _NetworkThumbImage extends StatelessWidget {
  const _NetworkThumbImage({required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    const fallback = _EmptyProfileImagePlaceholder();
    final trimmedUrl = url.trim();

    if (trimmedUrl.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: trimmedUrl,
      fit: fit,
      memCacheWidth: 360,
      maxWidthDiskCache: 720,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => Container(
        color: kSurfaceLoading,
        alignment: Alignment.center,
        child: const SizedBox(
          width: kProfileFallbackSpinnerSize,
          height: kProfileFallbackSpinnerSize,
          child: CircularProgressIndicator(
            strokeWidth: kProfileFallbackSpinnerStroke,
          ),
        ),
      ),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: kLoginCardPad,
      decoration: profileCardDecoration(),
      child: child,
    );
  }
}

class _ProfileMediaUploadResult {
  const _ProfileMediaUploadResult({
    required this.photoUrls,
    required this.videoUrls,
    required this.videoPreviewUrls,
  });

  final List<String> photoUrls;
  final List<String> videoUrls;
  final List<String> videoPreviewUrls;
}

class _ProfileMediaStorage {
  const _ProfileMediaStorage(this._sb);

  final SupabaseClient _sb;

  String _ext(XFile file) {
    final source = file.name.trim().isNotEmpty ? file.name : file.path;
    final p = source.toLowerCase();
    final i = p.lastIndexOf('.');
    if (i == -1) return '';
    return p.substring(i + 1);
  }

  String _contentType({
    required bool isVideo,
    required String ext,
    String? mimeType,
  }) {
    final mime = mimeType?.trim().toLowerCase() ?? '';
    if (mime.startsWith('image/') || mime.startsWith('video/')) return mime;

    if (isVideo) {
      if (ext == 'mov') return 'video/quicktime';
      if (ext == 'webm') return 'video/webm';
      return 'video/mp4';
    }
    if (ext == 'webp') return 'image/webp';
    if (ext == 'png') return 'image/png';
    return 'image/jpeg';
  }

  Future<String> uploadBinary({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _sb.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return _sb.storage.from(bucket).getPublicUrl(path);
  }

  Future<_ProfileMediaUploadResult> uploadPickedMedia({
    required String bucket,
    required String uid,
    required List<XFile> pickedPhotos,
    required List<XFile> pickedVideos,
  }) async {
    if (pickedPhotos.isEmpty && pickedVideos.isEmpty) {
      return const _ProfileMediaUploadResult(
        photoUrls: <String>[],
        videoUrls: <String>[],
        videoPreviewUrls: <String>[],
      );
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final uploadedPhotos = <String>[];
    final uploadedVideos = <String>[];
    final uploadedVideoPreviews = <String>[];

    for (int i = 0; i < pickedPhotos.length; i++) {
      final xf = pickedPhotos[i];
      final ext = _ext(xf);
      final ct = _contentType(isVideo: false, ext: ext, mimeType: xf.mimeType);
      final name = '${stamp}_$i.${ext.isEmpty ? 'jpg' : ext}';
      final storagePath = '$uid/photos/$name';

      final bytes = await xf.readAsBytes();
      final url = await uploadBinary(
        bucket: bucket,
        path: storagePath,
        bytes: bytes,
        contentType: ct,
      );
      uploadedPhotos.add(url);
    }

    for (int i = 0; i < pickedVideos.length; i++) {
      final xf = pickedVideos[i];
      final ext = _ext(xf);
      final ct = _contentType(isVideo: true, ext: ext, mimeType: xf.mimeType);
      final name = '${stamp}_$i.${ext.isEmpty ? 'mp4' : ext}';
      final storagePath = '$uid/videos/$name';

      final videoBytes = await xf.readAsBytes();
      final videoUrl = await uploadBinary(
        bucket: bucket,
        path: storagePath,
        bytes: videoBytes,
        contentType: ct,
      );
      uploadedVideos.add(videoUrl);

      try {
        final previewBytes = await VideoThumbnail.thumbnailData(
          video: xf.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 512,
          quality: 80,
        );

        if (previewBytes != null && previewBytes.isNotEmpty) {
          final previewPath = '$uid/video_previews/${stamp}_$i.jpg';
          final previewUrl = await uploadBinary(
            bucket: bucket,
            path: previewPath,
            bytes: previewBytes,
            contentType: 'image/jpeg',
          );
          uploadedVideoPreviews.add(previewUrl);
        } else {
          uploadedVideoPreviews.add('');
        }
      } catch (_) {
        uploadedVideoPreviews.add('');
      }
    }

    return _ProfileMediaUploadResult(
      photoUrls: List<String>.from(uploadedPhotos),
      videoUrls: List<String>.from(uploadedVideos),
      videoPreviewUrls: List<String>.from(uploadedVideoPreviews),
    );
  }
}
