import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A wrapper widget around CachedNetworkImage with shimmer loading effect
/// and gradient fallback for errors. Supports circular and rectangular variants.
class CachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isCircular;
  final double borderRadius;
  final String? fallbackText;
  final List<Color>? fallbackGradientColors;
  final Widget? customPlaceholder;
  final Widget? customErrorWidget;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isCircular = false,
    this.borderRadius = 12,
    this.fallbackText,
    this.fallbackGradientColors,
    this.customPlaceholder,
    this.customErrorWidget,
  });

  /// Creates a circular avatar variant
  factory CachedImage.circular({
    Key? key,
    required String? imageUrl,
    required double size,
    String? fallbackText,
    List<Color>? fallbackGradientColors,
    Widget? customPlaceholder,
    Widget? customErrorWidget,
  }) {
    return CachedImage(
      key: key,
      imageUrl: imageUrl,
      width: size,
      height: size,
      isCircular: true,
      fallbackText: fallbackText,
      fallbackGradientColors: fallbackGradientColors,
      customPlaceholder: customPlaceholder,
      customErrorWidget: customErrorWidget,
    );
  }

  /// Creates a rectangular card image variant
  factory CachedImage.rectangular({
    Key? key,
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    double borderRadius = 12,
    String? fallbackText,
    List<Color>? fallbackGradientColors,
    Widget? customPlaceholder,
    Widget? customErrorWidget,
  }) {
    return CachedImage(
      key: key,
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      isCircular: false,
      borderRadius: borderRadius,
      fallbackText: fallbackText,
      fallbackGradientColors: fallbackGradientColors,
      customPlaceholder: customPlaceholder,
      customErrorWidget: customErrorWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    // If no URL provided, show error widget
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildErrorWidget();
    }

    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => customPlaceholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) =>
          customErrorWidget ?? _buildErrorWidget(),
    );

    if (isCircular) {
      return ClipOval(
        child: SizedBox(
          width: width,
          height: height,
          child: imageWidget,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageWidget,
    );
  }

  Widget _buildPlaceholder() {
    final placeholderWidget = _ShimmerPlaceholder(
      width: width,
      height: height,
      isCircular: isCircular,
      borderRadius: borderRadius,
    );

    return placeholderWidget;
  }

  Widget _buildErrorWidget() {
    final colors = fallbackGradientColors ??
        [
          const Color(0xFF00D4FF),
          const Color(0xFF9C27B0),
        ];

    final content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: isCircular ? null : BorderRadius.circular(borderRadius),
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: fallbackText != null && fallbackText!.isNotEmpty
          ? Center(
              child: Text(
                _getInitials(fallbackText!),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _calculateFontSize(),
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: Colors.white.withOpacity(0.7),
                size: _calculateIconSize(),
              ),
            ),
    );

    if (isCircular) {
      return ClipOval(child: content);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: content,
    );
  }

  String _getInitials(String text) {
    final words = text.trim().split(' ');
    if (words.isEmpty) return '';
    if (words.length == 1) {
      return words[0].isNotEmpty ? words[0][0].toUpperCase() : '';
    }
    return '${words[0][0]}${words[words.length - 1][0]}'.toUpperCase();
  }

  double _calculateFontSize() {
    final size = width ?? height ?? 50;
    return (size * 0.35).clamp(12.0, 32.0);
  }

  double _calculateIconSize() {
    final size = width ?? height ?? 50;
    return (size * 0.4).clamp(16.0, 48.0);
  }
}

/// Shimmer-like loading placeholder with animated gradient
class _ShimmerPlaceholder extends StatefulWidget {
  final double? width;
  final double? height;
  final bool isCircular;
  final double borderRadius;

  const _ShimmerPlaceholder({
    this.width,
    this.height,
    this.isCircular = false,
    this.borderRadius = 12,
  });

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final content = Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.isCircular
                ? null
                : BorderRadius.circular(widget.borderRadius),
            shape: widget.isCircular ? BoxShape.circle : BoxShape.rectangle,
            gradient: LinearGradient(
              begin: Alignment(
                  _animation.value - 1, 0), // Moving gradient for shimmer
              end: Alignment(_animation.value + 1, 0),
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );

        if (widget.isCircular) {
          return ClipOval(child: content);
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: content,
        );
      },
    );
  }
}
