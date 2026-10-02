import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Shimmering placeholder block. Compose several into a page skeleton so a
/// loading screen already has the shape of the content it waits for.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = Tokens.radiusSm,
    this.aspectRatio,
  });

  final double? width;
  final double? height;
  final double radius;

  /// When set, the box keeps this ratio instead of a fixed [height].
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: Tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const SizedBox.expand(),
    );
    return aspectRatio != null
        ? AspectRatio(aspectRatio: aspectRatio!, child: box)
        : SizedBox(width: width, height: height, child: box);
  }
}

/// Adds the shimmer sweep to a composed skeleton (one animation per page).
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _Shimmer(child: child);
}

/// A line of «text».
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.width, this.height = 12});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(width: width, height: height, radius: height / 2);
  }
}

/// Catalogue grid skeleton: 3:4 cards with two text lines.
class SkeletonCardGrid extends StatelessWidget {
  const SkeletonCardGrid({
    super.key,
    required this.columns,
    this.rows = 2,
    this.gap = 12,
  });

  final int columns;
  final int rows;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Skeleton(
          child: Wrap(
            spacing: gap,
            runSpacing: gap + 12,
            children: [
              for (var i = 0; i < columns * rows; i++)
                SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonBox(
                        aspectRatio: 3 / 4,
                        radius: Tokens.radiusMd,
                      ),
                      const SizedBox(height: 10),
                      SkeletonLine(width: width * 0.6, height: 13),
                      const SizedBox(height: 7),
                      SkeletonLine(width: width * 0.45, height: 11),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// List skeleton: avatar + two lines, repeated.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.rows = 6,
    this.leadingSize = 48,
    this.padding = EdgeInsets.zero,
  });

  final int rows;
  final double leadingSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, _) => Row(
          children: [
            SkeletonBox(
              width: leadingSize,
              height: leadingSize,
              radius: leadingSize / 2,
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLine(width: 180, height: 13),
                  SizedBox(height: 8),
                  SkeletonLine(width: 260, height: 11),
                ],
              ),
            ),
          ],
      ),
      ),
    );
  }
}

/// Soft left-to-right highlight sweeping over the child, 1.4 s per cycle.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});

  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1 + 3 * t - 1, 0),
            end: Alignment(-1 + 3 * t + 1, 0),
            colors: const [
              Color(0x00FFFFFF),
              Color(0x99FFFFFF),
              Color(0x00FFFFFF),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
