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

class _PortfolioHeroCard extends StatelessWidget {
  const _PortfolioHeroCard({
    required this.model,
    required this.t,
    required this.displayPhotoUrls,
    required this.coverAlignment,
    required this.onOpenPhotos,
    required this.onCompositePdf,
    required this.onCopyLink,
    required this.canUseAgentActions,
    required this.isBusy,
    required this.onInvite,
    required this.onAddToSelection,
    required this.onMessage,
    this.onOpenVideo,
    this.onOpenShowreel,
  });

  final ModelVm model;
  final AppLocalizations t;
  final List<String> displayPhotoUrls;
  final Alignment coverAlignment;
  final void Function(int index) onOpenPhotos;
  final VoidCallback? onOpenVideo;
  final VoidCallback? onOpenShowreel;
  final VoidCallback onCompositePdf;
  final VoidCallback onCopyLink;
  final bool canUseAgentActions;
  final bool isBusy;
  final VoidCallback onInvite;
  final VoidCallback onAddToSelection;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('ru');
    final hasMedia = displayPhotoUrls.isNotEmpty || model.videoUrls.isNotEmpty;
    final title = model.fullName.trim().isEmpty
        ? t.profileNoName
        : model.fullName.trim();
    final location = [
      model.city.trim(),
      model.country.trim(),
    ].where((value) => value.isNotEmpty).join(', ');
    final roles = _profileRolesLabel(t, model.effectiveProfileRoles);
    final statChips = <_PortfolioStatData>[
      if (roles.isNotEmpty) _PortfolioStatData(Icons.badge_rounded, roles),
      if (model.usesPhysicalBasics && model.age > 0)
        _PortfolioStatData(Icons.cake_rounded, '${model.age}'),
      if (model.usesPhysicalBasics && model.height > 0)
        _PortfolioStatData(Icons.straighten_rounded, '${model.height} ${t.cm}'),
      if (location.isNotEmpty)
        _PortfolioStatData(Icons.place_rounded, location),
      _PortfolioStatData(
        Icons.photo_library_rounded,
        isRu
            ? '${displayPhotoUrls.length} фото • ${model.videoUrls.length} видео'
            : '${displayPhotoUrls.length} photos • ${model.videoUrls.length} videos',
      ),
    ];

    final media = hasMedia
        ? _HeroMedia(
            photoUrls: displayPhotoUrls,
            videoUrls: model.videoUrls,
            videoPreviewUrls: model.videoPreviewUrls,
            coverAlignment: coverAlignment,
            heroTag: 'model-photo-${model.id}',
            onOpenPhotos: onOpenPhotos,
            onOpenVideo: onOpenVideo ?? () {},
          )
        : AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: catalogPhotoPlaceholderDecoration(),
              child: const Center(
                child: Icon(Icons.person_rounded, color: kTextMuted, size: 42),
              ),
            ),
          );

    final info = _PortfolioIdentityPanel(
      title: title,
      isPro: model.isProActive,
      statChips: statChips,
      isRu: isRu,
      onCompositePdf: onCompositePdf,
      onCopyLink: onCopyLink,
      canUseAgentActions: canUseAgentActions,
      isBusy: isBusy,
      onInvite: onInvite,
      onAddToSelection: onAddToSelection,
      onMessage: onMessage,
      onOpenShowreel: onOpenShowreel,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [media, const SizedBox(height: 16), info],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: media),
            const SizedBox(width: 18),
            Expanded(flex: 5, child: info),
          ],
        );
      },
    );
  }
}

class _PortfolioIdentityPanel extends StatelessWidget {
  const _PortfolioIdentityPanel({
    required this.title,
    required this.isPro,
    required this.statChips,
    required this.isRu,
    required this.onCompositePdf,
    required this.onCopyLink,
    required this.canUseAgentActions,
    required this.isBusy,
    required this.onInvite,
    required this.onAddToSelection,
    required this.onMessage,
    this.onOpenShowreel,
  });

  final String title;
  final bool isPro;
  final List<_PortfolioStatData> statChips;
  final bool isRu;
  final VoidCallback onCompositePdf;
  final VoidCallback onCopyLink;
  final bool canUseAgentActions;
  final bool isBusy;
  final VoidCallback onInvite;
  final VoidCallback onAddToSelection;
  final VoidCallback onMessage;
  final VoidCallback? onOpenShowreel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isRu ? 'ПОРТФОЛИО' : 'PORTFOLIO',
          style: _commandStyle(
            fontSize: 12,
            color: BrandTheme.redTop,
            weight: FontWeight.w700,
            letterSpacing: 2.1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _commandStyle(
                  fontSize: 28,
                  weight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (isPro) ...[const SizedBox(width: 8), const _ProBadge()],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final chip in statChips) _PortfolioStatChip(chip)],
        ),
        const SizedBox(height: 16),
        if (canUseAgentActions) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PortfolioActionButton(
                label: isRu ? 'ПРИГЛАСИТЬ' : 'INVITE',
                icon: Icons.send_rounded,
                isDark: true,
                busy: isBusy,
                onTap: onInvite,
              ),
              _PortfolioActionButton(
                label: isRu ? 'ДОБАВИТЬ' : 'ADD',
                icon: Icons.playlist_add_rounded,
                isDark: false,
                busy: isBusy,
                onTap: onAddToSelection,
              ),
              _PortfolioActionButton(
                label: isRu ? 'НАПИСАТЬ' : 'MESSAGE',
                icon: Icons.chat_bubble_rounded,
                isDark: false,
                busy: isBusy,
                onTap: onMessage,
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _PortfolioActionButton(
              label: isRu ? 'КОМПОЗИТКА' : 'PDF',
              icon: Icons.picture_as_pdf_rounded,
              isDark: false,
              busy: isBusy,
              onTap: onCompositePdf,
            ),
            _PortfolioActionButton(
              label: isRu ? 'ССЫЛКА' : 'LINK',
              icon: Icons.link_rounded,
              isDark: false,
              busy: isBusy,
              onTap: onCopyLink,
            ),
            if (onOpenShowreel != null)
              _PortfolioActionButton(
                label: 'SHOWREEL',
                icon: Icons.play_arrow_rounded,
                isDark: false,
                busy: isBusy,
                onTap: onOpenShowreel!,
              ),
          ],
        ),
      ],
    );
  }
}

class _PortfolioStatData {
  const _PortfolioStatData(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _PortfolioStatChip extends StatelessWidget {
  const _PortfolioStatChip(this.data);

  final _PortfolioStatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: 16, color: _labelColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle(
                fontSize: 12,
                color: _titleColor,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioActionButton extends StatelessWidget {
  const _PortfolioActionButton({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isDark;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: busy ? null : onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: pillDecoration(isDark: isDark, radius: 999),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? Colors.white : _titleColor,
                  ),
                )
              else
                Icon(
                  icon,
                  size: 18,
                  color: isDark ? Colors.white : _titleColor,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: _commandStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white : _titleColor,
                  weight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
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
    required this.coverAlignment,
    required this.heroTag,
    required this.onOpenPhotos,
    required this.onOpenVideo,
  });

  final List<String> photoUrls;
  final List<String> videoUrls;
  final List<String> videoPreviewUrls;
  final Alignment coverAlignment;
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
                    alignment: coverAlignment,
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

class _PortfolioAddSheet extends StatelessWidget {
  const _PortfolioAddSheet({
    required this.modelName,
    required this.folders,
    required this.onFavorite,
    required this.onCreateSelection,
    required this.onCreateFolder,
    required this.onAddToFolder,
  });

  final String modelName;
  final List<AgentFolder> folders;
  final VoidCallback onFavorite;
  final VoidCallback onCreateSelection;
  final VoidCallback onCreateFolder;
  final ValueChanged<AgentFolder> onAddToFolder;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: pillDecoration(isDark: false, radius: kCardRadius),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.quickAddTitleUpper,
                textAlign: TextAlign.center,
                style: _commandStyle(fontSize: 15, letterSpacing: 1.15),
              ),
              const SizedBox(height: kGap4),
              Text(
                modelName.trim().isEmpty ? t.profileNoName : modelName.trim(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle(fontSize: 14, color: kTextMuted),
              ),
              const SizedBox(height: kGap14),
              Row(
                children: [
                  Expanded(
                    child: _PortfolioSheetAction(
                      icon: Icons.favorite_rounded,
                      label: t.quickAddFavorite,
                      onTap: onFavorite,
                    ),
                  ),
                  const SizedBox(width: kGap10),
                  Expanded(
                    child: _PortfolioSheetAction(
                      icon: Icons.dashboard_customize_rounded,
                      label: t.quickAddSelection,
                      onTap: onCreateSelection,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kGap14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.quickAddFolder,
                      style: _commandStyle(fontSize: 14, letterSpacing: 0.55),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onCreateFolder,
                    icon: const Icon(Icons.create_new_folder_rounded, size: 18),
                    label: Text(t.quickAddCreateFolder),
                    style: TextButton.styleFrom(
                      foregroundColor: BrandTheme.redTop,
                      textStyle: BrandTheme.pillText.copyWith(
                        fontSize: 12,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ),
                ],
              ),
              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: kGap4),
                  child: Text(
                    t.agentNoFolders,
                    style: _bodyStyle(fontSize: 14),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final folder in folders)
                          _PortfolioFolderChip(
                            label: folder.title,
                            selected: folder.containsProfile,
                            onTap: () => onAddToFolder(folder),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioSheetAction extends StatelessWidget {
  const _PortfolioSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kPillRadius),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: pillDecoration(isDark: true, radius: kPillRadius),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _commandStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortfolioFolderChip extends StatelessWidget {
  const _PortfolioFolderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        selected ? Icons.check_rounded : Icons.folder_rounded,
        size: 18,
        color: selected ? Colors.white : BrandTheme.redTop,
      ),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected ? BrandTheme.redTop : Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : kTextDark,
        fontWeight: FontWeight.w800,
      ),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? BrandTheme.redTop : const Color(0xFFE0E0E0),
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
