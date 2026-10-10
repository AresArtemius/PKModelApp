import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/account_profile_service.dart';
import '../../core/content_safety_filter.dart';
import '../../core/storage_image_variant.dart';
import '../../core/supabase_provider.dart';
import '../../ui/brand/ui_constants.dart';
import '../profile/profile_media_storage.dart';
import '../profile/profile_media_upload_queue.dart' show kProfileMediaBucket;
import '../profile/profile_media_web_native_picker_stub.dart'
    if (dart.library.html) '../profile/profile_media_web_native_picker_web.dart';
import 'feed_service.dart';

/// Step 46: writing a post at the top of the feed — text, up to
/// [PostComposer.maxPhotos] photos, visibility. Collapsed to one line until
/// focused, like a Telegram channel composer.
class PostComposer extends ConsumerStatefulWidget {
  const PostComposer({super.key, this.onPublished});

  final VoidCallback? onPublished;

  static const maxPhotos = 10;
  static const maxLength = 4000;

  @override
  ConsumerState<PostComposer> createState() => _PostComposerState();
}

class _PickedPhoto {
  _PickedPhoto({required this.file, required this.bytes});

  final XFile file;
  final Uint8List bytes;
}

class _PostComposerState extends ConsumerState<PostComposer> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();

  final List<_PickedPhoto> _photos = [];
  String _visibility = 'public';
  bool _expanded = false;
  bool _busy = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus && !_expanded) setState(() => _expanded = true);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canPublish =>
      !_busy && (_text.text.trim().isNotEmpty || _photos.isNotEmpty);

  Future<void> _pickPhotos() async {
    if (_busy) return;
    setState(() => _error = null);
    try {
      final list = kIsWeb && ProfileMediaWebNativePicker.isSupported
          ? await ProfileMediaWebNativePicker.pickPhotos()
          : await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1800);
      if (list.isEmpty || !mounted) return;
      final room = PostComposer.maxPhotos - _photos.length;
      final picked = <_PickedPhoto>[];
      for (final f in list.take(room)) {
        picked.add(_PickedPhoto(file: f, bytes: await f.readAsBytes()));
      }
      if (!mounted) return;
      setState(() {
        _photos.addAll(picked);
        _expanded = true;
        if (list.length > room) {
          _error = _ru
              ? 'Не больше ${PostComposer.maxPhotos} фото в одном посте'
              : 'Up to ${PostComposer.maxPhotos} photos per post';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = _ru ? 'Не удалось выбрать фото' : 'Could not pick photos',
      );
    }
  }

  bool get _ru => Localizations.localeOf(context).languageCode == 'ru';

  Future<({int width, int height})?> _dimensions(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = (width: frame.image.width, height: frame.image.height);
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  Future<void> _publish() async {
    final ru = _ru;
    final body = _text.text.trim();
    if (body.length > PostComposer.maxLength) {
      setState(
        () => _error = ru
            ? 'Слишком длинный текст (до ${PostComposer.maxLength} символов)'
            : 'Text is too long (up to ${PostComposer.maxLength} characters)',
      );
      return;
    }
    if (ContentSafetyFilter.hasBlockedText(body)) {
      setState(
        () => _error = ContentSafetyFilter.message(
          isRussian: ru,
          fieldLabel: ru ? 'Текст поста' : 'Post text',
        ),
      );
      return;
    }
    final sb = ref.read(supabaseProvider);
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;

    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
    });
    try {
      final storage = ProfileMediaStorage(sb);
      final uploaded = <Map<String, dynamic>>[];
      final stamp = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < _photos.length; i++) {
        final p = _photos[i];
        final dims = await _dimensions(p.bytes);
        final url = await storage.uploadPhoto(
          bucket: kProfileMediaBucket,
          uid: uid,
          file: p.file,
          pathSeed: 'post_${stamp}_$i',
          onProgress: (v) {
            if (!mounted) return;
            setState(() => _progress = (i + v) / _photos.length);
          },
        );
        uploaded.add({
          'position': i,
          'media_type': 'image',
          'url': url,
          if (dims != null) 'width': dims.width,
          if (dims != null) 'height': dims.height,
        });
        if (mounted) setState(() => _progress = (i + 1) / _photos.length);
      }

      final inserted = await sb
          .from('posts')
          .insert({
            'author_id': uid,
            'kind': uploaded.isEmpty ? 'text' : 'media',
            'body': body,
            'visibility': _visibility,
          })
          .select('id')
          .single();
      final postId = (inserted['id'] ?? '').toString();
      if (uploaded.isNotEmpty && postId.isNotEmpty) {
        await sb.from('post_media').insert([
          for (final m in uploaded) {...m, 'post_id': postId},
        ]);
      }

      if (!mounted) return;
      setState(() {
        _text.clear();
        _photos.clear();
        _expanded = false;
        _busy = false;
        _progress = 0;
      });
      _focus.unfocus();
      await ref.read(feedControllerProvider('home').notifier).refresh();
      widget.onPublished?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ru
            ? 'Не удалось опубликовать. Попробуйте ещё раз.'
            : 'Could not publish. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = _ru;
    final me = ref.watch(accountOwnerProfileProvider).asData?.value;
    final avatar = me?.avatarUrl.trim() ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Tokens.s16,
        Tokens.s12,
        Tokens.s16,
        Tokens.s12,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MeAvatar(url: avatar),
              const SizedBox(width: Tokens.s12),
              Expanded(
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  enabled: !_busy,
                  minLines: _expanded ? 3 : 1,
                  maxLines: 12,
                  maxLength: _expanded ? PostComposer.maxLength : null,
                  onChanged: (_) => setState(() {}),
                  style: AppText.body,
                  decoration: InputDecoration(
                    hintText: ru ? 'Что нового?' : "What's new?",
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    counterStyle: AppText.caption,
                  ),
                ),
              ),
            ],
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: Tokens.s8),
            _PhotoStrip(
              photos: _photos,
              enabled: !_busy,
              onRemove: (i) => setState(() => _photos.removeAt(i)),
              onAdd: _photos.length < PostComposer.maxPhotos ? _pickPhotos : null,
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: Tokens.s8),
            ClipRRect(
              borderRadius: BorderRadius.circular(Tokens.radiusPill),
              child: LinearProgressIndicator(
                value: _photos.isEmpty ? null : _progress,
                minHeight: 3,
                color: Tokens.text,
                backgroundColor: Tokens.surfaceAlt,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: Tokens.s8),
            Text(_error!, style: AppText.small.copyWith(color: Tokens.danger)),
          ],
          if (_expanded || _photos.isNotEmpty) ...[
            const SizedBox(height: Tokens.s8),
            Row(
              children: [
                Tooltip(
                  message: ru ? 'Добавить фото' : 'Add photos',
                  child: IconButton(
                    onPressed:
                        _busy || _photos.length >= PostComposer.maxPhotos
                        ? null
                        : _pickPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    color: Tokens.textSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: Tokens.s4),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'public',
                      icon: const Icon(Icons.public_rounded, size: 16),
                      label: Text(ru ? 'Все' : 'Everyone'),
                    ),
                    ButtonSegment(
                      value: 'followers',
                      icon: const Icon(Icons.people_outline_rounded, size: 16),
                      label: Text(ru ? 'Подписчики' : 'Followers'),
                    ),
                  ],
                  selected: {_visibility},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  onSelectionChanged: _busy
                      ? null
                      : (v) => setState(() => _visibility = v.first),
                ),
                const Spacer(),
                if (!_busy && _text.text.isEmpty && _photos.isEmpty)
                  TextButton(
                    onPressed: () {
                      _focus.unfocus();
                      setState(() => _expanded = false);
                    },
                    child: Text(ru ? 'Отмена' : 'Cancel'),
                  ),
                const SizedBox(width: Tokens.s4),
                FilledButton(
                  onPressed: _canPublish ? _publish : null,
                  child: Text(
                    _busy
                        ? (ru ? 'Публикуем…' : 'Publishing…')
                        : (ru ? 'Опубликовать' : 'Publish'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photos,
    required this.enabled,
    required this.onRemove,
    required this.onAdd,
  });

  final List<_PickedPhoto> photos;
  final bool enabled;
  final ValueChanged<int> onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    const size = 88.0;
    return SizedBox(
      height: size,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < photos.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: Tokens.s8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Tokens.radiusSm),
                    child: Image.memory(
                      photos[i].bytes,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      cacheWidth: (size * 2).round(),
                    ),
                  ),
                  if (enabled)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => onRemove(i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (onAdd != null)
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(Tokens.radiusSm),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  border: Border.all(color: Tokens.borderStrong),
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
                child: const Icon(Icons.add_rounded, color: Tokens.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _MeAvatar extends StatelessWidget {
  const _MeAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 40,
        height: 40,
        child: url.isEmpty
            ? const ColoredBox(
                color: Tokens.surfaceAlt,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: Tokens.textTertiary,
                ),
              )
            : CachedNetworkImage(
                imageUrl: storageImageVariant(url, width: 80),
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
              ),
      ),
    );
  }
}
