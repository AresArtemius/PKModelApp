part of 'model_profile_page.dart';

class _TopBar extends StatefulWidget {
  const _TopBar({
    required this.backKey,
    required this.title,
    required this.isPro,
    required this.onCopyLink,
    required this.onBack,
  });

  final GlobalKey backKey;
  final String title;
  final bool isPro;
  final VoidCallback onCopyLink;
  final VoidCallback onBack;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  double _backWidth = 56;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box =
          widget.backKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final w = box.size.width;
      if (mounted && w > 0 && (w - _backWidth).abs() > 0.5) {
        setState(() => _backWidth = w);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        KeyedSubtree(
          key: widget.backKey,
          child: _IconPill(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: widget.onBack,
          ),
        ),
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _commandStyle(
                      fontSize: _topBarTitleFontSize,
                      weight: FontWeight.w700,
                      color: _topBarTextColor,
                      letterSpacing: 1.35,
                    ),
                  ),
                ),
                if (widget.isPro) ...[
                  const SizedBox(width: 8),
                  const _ProBadge(),
                ],
              ],
            ),
          ),
        ),
        SizedBox(
          width: _backWidth,
          child: Center(
            child: _IconPill(
              icon: Icons.link_rounded,
              onTap: widget.onCopyLink,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
      ),
      child: Text(
        'PRO',
        style: _commandStyle(
          fontSize: 10,
          color: Colors.white,
          weight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _HeroMedia extends StatelessWidget {
  const _HeroMedia({
    required this.photoUrls,
    required this.videoUrls,
    required this.videoPreviewUrls,
    required this.heroTag,
    required this.onOpenPhotos,
    required this.onOpenVideo,
  });

  final List<String> photoUrls;
  final List<String> videoUrls;
  final List<String> videoPreviewUrls;
  final String heroTag;
  final void Function(int index) onOpenPhotos;
  final VoidCallback onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrls.isNotEmpty;
    final hasVideo = videoUrls.isNotEmpty;
    final firstPreview = videoPreviewUrls.isNotEmpty
        ? videoPreviewUrls.first.trim()
        : '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(_heroMediaRadius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPhoto)
              GestureDetector(
                onTap: () => onOpenPhotos(0),
                child: Hero(
                  tag: heroTag,
                  child: CachedNetworkImage(
                    imageUrl: photoUrls.first,
                    memCacheWidth: _profileHeroCacheWidth,
                    maxWidthDiskCache: _profileHeroCacheWidth,
                    fit: BoxFit.cover,
                    alignment: _profileCoverImageAlignment,
                    placeholder: (_, _) => DecoratedBox(
                      decoration: catalogPhotoPlaceholderDecoration(),
                    ),
                    errorWidget: (_, _, _) => Container(
                      decoration: catalogPhotoPlaceholderDecoration(),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                ),
              )
            else if (hasVideo)
              GestureDetector(
                onTap: onOpenVideo,
                child: firstPreview.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: firstPreview,
                            memCacheWidth: _profileHeroCacheWidth,
                            maxWidthDiskCache: _profileHeroCacheWidth,
                            fit: BoxFit.cover,
                            placeholder: (_, _) => DecoratedBox(
                              decoration: catalogPhotoPlaceholderDecoration(),
                            ),
                            errorWidget: (_, _, _) => _GeneratedVideoThumbnail(
                              videoUrl: videoUrls.first,
                            ),
                          ),
                          const Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Color(0x66000000),
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _ModelVideoPreview(url: videoUrls.first),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.rows});
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final r in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  r.key,
                  style: const TextStyle(
                    color: _labelColor,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  r.value,
                  textAlign: TextAlign.right,
                  style: _bodyStyle(
                    color: _titleColor,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _PhotoGalleryPage extends StatefulWidget {
  const _PhotoGalleryPage({required this.urls, required this.initialIndex});
  final List<String> urls;
  final int initialIndex;

  @override
  State<_PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<_PhotoGalleryPage> {
  late final PageController _pc;

  @override
  void initState() {
    super.initState();
    _pc = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pc,
              itemCount: widget.urls.length,
              itemBuilder: (_, i) => Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: widget.urls[i],
                    fit: BoxFit.contain,
                    placeholder: (_, _) =>
                        const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: _galleryCloseOffset,
              left: _galleryCloseOffset,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenVideoPage extends StatefulWidget {
  const _FullScreenVideoPage({required this.url});
  final String url;

  @override
  State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  late final VideoPlayerController _c;
  late final Future<void> _init;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true);
    _init = _c.initialize().then((_) {
      if (mounted) {
        _c.play();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: FutureBuilder<void>(
                future: _init,
                builder: (_, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const CircularProgressIndicator();
                  }
                  if (snap.hasError || !_c.value.isInitialized) {
                    return const Icon(Icons.videocam_off, color: Colors.white);
                  }

                  final aspectRatio = _c.value.aspectRatio > 0
                      ? _c.value.aspectRatio
                      : (16 / 9);

                  return AspectRatio(
                    aspectRatio: aspectRatio,
                    child: VideoPlayer(_c),
                  );
                },
              ),
            ),
            Positioned(
              top: _galleryCloseOffset,
              left: _galleryCloseOffset,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: _videoControlsBottom,
              left: 0,
              right: 0,
              child: Center(
                child: IconButton(
                  iconSize: _videoPlayButtonSize,
                  icon: Icon(
                    _c.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _c.value.isPlaying ? _c.pause() : _c.play();
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kSearchRadius),
        onTap: onTap,
        child: Container(
          width: _iconPillWidth,
          height: _iconPillHeight,
          decoration: catalogSearchDecoration(radius: kSearchRadius),
          child: Icon(icon, color: _titleColor, size: kIconSizeSmall),
        ),
      ),
    );
  }
}

class _ModelVideoPreview extends StatefulWidget {
  const _ModelVideoPreview({required this.url});
  final String url;

  @override
  State<_ModelVideoPreview> createState() => _ModelVideoPreviewState();
}

class _ModelVideoPreviewState extends State<_ModelVideoPreview> {
  late final VideoPlayerController _c;
  late final Future<void> _init;
  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..setVolume(0);
    _init = _c.initialize().then((_) {
      if (mounted) _c.play();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: _videoPreviewLoadingHeight,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!_c.value.isInitialized) {
          return const SizedBox(
            height: _videoPreviewLoadingHeight,
            child: Center(child: Icon(Icons.videocam_off)),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: _videoPreviewHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _c.value.size.width,
                    height: _c.value.size.height,
                    child: VideoPlayer(_c),
                  ),
                ),
                const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x66000000),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModelVideoThumb extends StatelessWidget {
  const _ModelVideoThumb({required this.videoUrl, required this.previewUrl});

  final String videoUrl;
  final String previewUrl;

  @override
  Widget build(BuildContext context) {
    final hasPreview = previewUrl.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_mediaThumbRadius),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasPreview)
              CachedNetworkImage(
                imageUrl: previewUrl,
                memCacheWidth: _profileThumbCacheWidth,
                maxWidthDiskCache: _profileThumbCacheWidth,
                fit: BoxFit.cover,
                placeholder: (_, _) => DecoratedBox(
                  decoration: catalogPhotoPlaceholderDecoration(),
                ),
                errorWidget: (_, _, _) =>
                    _GeneratedVideoThumbnail(videoUrl: videoUrl),
              )
            else
              _GeneratedVideoThumbnail(videoUrl: videoUrl),
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: _videoThumbIconSize,
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

class _GeneratedVideoThumbnail extends StatefulWidget {
  const _GeneratedVideoThumbnail({required this.videoUrl});

  final String videoUrl;

  @override
  State<_GeneratedVideoThumbnail> createState() =>
      _GeneratedVideoThumbnailState();
}

class _GeneratedVideoThumbnailState extends State<_GeneratedVideoThumbnail> {
  Future<String?>? _thumbFuture;

  @override
  void initState() {
    super.initState();
    _thumbFuture = _buildThumb();
  }

  @override
  void didUpdateWidget(covariant _GeneratedVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _thumbFuture = _buildThumb();
    }
  }

  Future<String?> _buildThumb() async {
    return _videoThumbnailForUrl(widget.videoUrl);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _thumbFuture,
      builder: (context, snap) {
        final path = snap.data;
        if (path == null || path.isEmpty) {
          if (snap.connectionState != ConnectionState.done) {
            return DecoratedBox(
              decoration: catalogPhotoPlaceholderDecoration(),
            );
          }
          return _InlineVideoFramePreview(url: widget.videoUrl);
        }

        return Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return _InlineVideoFramePreview(url: widget.videoUrl);
          },
        );
      },
    );
  }
}

class _InlineVideoFramePreview extends StatefulWidget {
  const _InlineVideoFramePreview({required this.url});

  final String url;

  @override
  State<_InlineVideoFramePreview> createState() =>
      _InlineVideoFramePreviewState();
}

class _InlineVideoFramePreviewState extends State<_InlineVideoFramePreview> {
  VideoPlayerController? _controller;
  Future<void>? _init;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant _InlineVideoFramePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _initController();
    }
  }

  void _initController() {
    final url = widget.url.trim();
    if (url.isEmpty) {
      _controller = null;
      _init = null;
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..setVolume(0);
    _controller = controller;
    _init = controller.initialize().then((_) async {
      if (!mounted) return;
      await controller.seekTo(Duration.zero);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final init = _init;
    if (controller == null || init == null) {
      return const _VideoPreviewFallbackIcon();
    }

    return FutureBuilder<void>(
      future: init,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return DecoratedBox(decoration: catalogPhotoPlaceholderDecoration());
        }
        if (snap.hasError || !controller.value.isInitialized) {
          return const _VideoPreviewFallbackIcon();
        }

        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
      },
    );
  }
}

class _VideoPreviewFallbackIcon extends StatelessWidget {
  const _VideoPreviewFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: catalogPhotoPlaceholderDecoration(),
      alignment: Alignment.center,
      child: const Icon(Icons.videocam, color: kTextMuted),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: catalogCardDecoration(),
      child: child,
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({
    required this.photoUrls,
    required this.photoCategoryLabels,
    required this.videoUrls,
    required this.videoPreviewUrls,
    required this.videoCategoryLabels,
    required this.showreelUrl,
    required this.onOpenPhotos,
    required this.onOpenVideo,
  });

  final List<String> photoUrls;
  final List<String> photoCategoryLabels;
  final List<String> videoUrls;
  final List<String> videoPreviewUrls;
  final List<String> videoCategoryLabels;
  final String showreelUrl;
  final void Function(int index) onOpenPhotos;
  final void Function(int index) onOpenVideo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (_mediaGridGap * 2)) / 3;
        final itemHeight = itemWidth * 1.12;

        return Wrap(
          spacing: _mediaGridGap,
          runSpacing: _mediaGridGap,
          children: [
            for (var i = 0; i < photoUrls.length; i++)
              _MediaTile(
                width: itemWidth,
                height: itemHeight,
                label: i < photoCategoryLabels.length
                    ? photoCategoryLabels[i]
                    : '',
                onTap: () => onOpenPhotos(i),
                child: CachedNetworkImage(
                  imageUrl: photoUrls[i],
                  memCacheWidth: _profileThumbCacheWidth,
                  maxWidthDiskCache: _profileThumbCacheWidth,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => DecoratedBox(
                    decoration: catalogPhotoPlaceholderDecoration(),
                  ),
                  errorWidget: (_, _, _) => Container(
                    decoration: catalogPhotoPlaceholderDecoration(),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: kTextMuted,
                    ),
                  ),
                ),
              ),
            for (var i = 0; i < videoUrls.length; i++)
              _MediaTile(
                width: itemWidth,
                height: itemHeight,
                label: videoUrls[i].trim() == showreelUrl.trim()
                    ? 'SHOWREEL'
                    : (i < videoCategoryLabels.length
                          ? videoCategoryLabels[i]
                          : ''),
                onTap: () => onOpenVideo(i),
                child: _ModelVideoThumb(
                  videoUrl: videoUrls[i],
                  previewUrl: i < videoPreviewUrls.length
                      ? videoPreviewUrls[i]
                      : '',
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ShowreelCard extends StatelessWidget {
  const _ShowreelCard({
    required this.videoUrl,
    required this.previewUrl,
    required this.onTap,
  });

  final String videoUrl;
  final String previewUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: _MediaTile(
        width: double.infinity,
        height: double.infinity,
        label: 'SHOWREEL',
        onTap: onTap,
        child: _ModelVideoThumb(videoUrl: videoUrl, previewUrl: previewUrl),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.width,
    required this.height,
    required this.child,
    required this.onTap,
    this.label = '',
  });

  final double width;
  final double height;
  final Widget child;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_mediaThumbRadius),
        onTap: onTap,
        child: Ink(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_mediaThumbRadius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 12,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_mediaThumbRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                if (label.trim().isNotEmpty)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: label.trim().toUpperCase() == 'SHOWREEL'
                            ? BrandTheme.redTop.withValues(alpha: 0.92)
                            : Colors.black.withValues(alpha: 0.64),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label.trim().toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
