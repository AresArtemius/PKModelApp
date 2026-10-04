import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Network photo cropped to its box so that the focal point (a face, −1…1
/// like [Alignment]) stays centred whenever the picture allows it.
///
/// A plain `BoxFit.cover` with `alignment: Alignment(focalX, focalY)` only
/// shifts the crop window by the focal fraction, so for small squares cut
/// out of a portrait the face lands near the edge. Here the real image
/// size is resolved first and the alignment is derived from it.
class FocalImage extends StatefulWidget {
  const FocalImage({
    super.key,
    required this.url,
    this.focalX = 0,
    this.focalY = -0.6,
    this.memCacheWidth,
    this.placeholderColor = Tokens.surfaceAlt,
    this.errorChild,
  });

  final String url;
  final double focalX;
  final double focalY;
  final int? memCacheWidth;
  final Color placeholderColor;
  final Widget? errorChild;

  @override
  State<FocalImage> createState() => _FocalImageState();
}

class _FocalImageState extends State<FocalImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;
  ImageProvider? _provider;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant FocalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.memCacheWidth != widget.memCacheWidth) {
      _imageSize = null;
      _resolve();
    }
  }

  void _resolve() {
    _detach();
    final url = widget.url.trim();
    if (url.isEmpty) {
      _provider = null;
      return;
    }
    final provider = CachedNetworkImageProvider(
      url,
      maxWidth: widget.memCacheWidth,
    );
    _provider = provider;
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        final size = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        if (!mounted) return;
        if (_imageSize != size) setState(() => _imageSize = size);
      },
      onError: (_, _) {},
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void _detach() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  /// Alignment that centres the focal point inside a [box] of the given
  /// size when the image is scaled to cover it.
  Alignment _alignmentFor(Size box) {
    final image = _imageSize;
    if (image == null || image.isEmpty || box.isEmpty) {
      return Alignment(
        widget.focalX.clamp(-1.0, 1.0),
        widget.focalY.clamp(-1.0, 1.0),
      );
    }
    final scale = (box.width / image.width > box.height / image.height)
        ? box.width / image.width
        : box.height / image.height;
    final scaledW = image.width * scale;
    final scaledH = image.height * scale;

    double along(double focal, double scaled, double visible) {
      final overflow = scaled - visible;
      if (overflow <= 0.5) return 0;
      // Focal position in the scaled image, in pixels from the start.
      final point = (focal.clamp(-1.0, 1.0) + 1) / 2 * scaled;
      // Window start that puts the point in the middle, clamped to the
      // image bounds, then expressed as -1..1 alignment.
      final start = (point - visible / 2).clamp(0.0, overflow);
      return (start / overflow) * 2 - 1;
    }

    return Alignment(
      along(widget.focalX, scaledW, box.width),
      along(widget.focalY, scaledH, box.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) {
      return ColoredBox(
        color: widget.placeholderColor,
        child: widget.errorChild,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 0,
          constraints.hasBoundedHeight ? constraints.maxHeight : 0,
        );
        return Image(
          image: provider,
          fit: BoxFit.cover,
          alignment: _alignmentFor(box),
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSync) {
            if (frame != null || wasSync) return child;
            return ColoredBox(color: widget.placeholderColor);
          },
          errorBuilder: (_, _, _) => ColoredBox(
            color: widget.placeholderColor,
            child: widget.errorChild,
          ),
        );
      },
    );
  }
}
