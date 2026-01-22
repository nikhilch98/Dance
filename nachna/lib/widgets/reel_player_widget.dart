import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../models/reel.dart';
import '../utils/responsive_utils.dart';

/// Widget that displays a Reel video using native video playback.
/// Clean, full-screen display without controls - tap to play/pause.
class ReelPlayerWidget extends StatefulWidget {
  final Reel reel;
  final VoidCallback? onLoadComplete;
  final VoidCallback? onLoadError;
  final bool autoPlay;

  const ReelPlayerWidget({
    super.key,
    required this.reel,
    this.onLoadComplete,
    this.onLoadError,
    this.autoPlay = true,
  });

  @override
  State<ReelPlayerWidget> createState() => _ReelPlayerWidgetState();
}

class _ReelPlayerWidgetState extends State<ReelPlayerWidget> {
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _showPlayIcon = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    if (!widget.reel.hasVideo || widget.reel.videoUrl == null) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Video not available';
        _isLoading = false;
      });
      widget.onLoadError?.call();
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final videoUrl = widget.reel.videoUrl!;
      
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: {'Accept': 'video/mp4'},
      );

      await _videoController!.initialize();
      
      if (!mounted) return;

      // Set looping and auto-play
      _videoController!.setLooping(true);
      if (widget.autoPlay) {
        _videoController!.play();
      }

      setState(() {
        _isLoading = false;
      });

      widget.onLoadComplete?.call();
    } catch (e) {
      print('Video initialization error: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load video';
        _isLoading = false;
      });
      widget.onLoadError?.call();
    }
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _showPlayIcon = true;
      } else {
        _videoController!.play();
        _showPlayIcon = false;
      }
    });
    
    // Auto-hide play icon after delay
    if (!_videoController!.value.isPlaying) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_videoController!.value.isPlaying) {
          setState(() => _showPlayIcon = false);
        }
      });
    }
  }

  Future<void> _openInInstagram() async {
    try {
      final uri = Uri.parse(widget.reel.instagramUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Silently fail
    }
  }

  void _retry() {
    _videoController?.dispose();
    _videoController = null;
    setState(() {
      _hasError = false;
      _isLoading = true;
      _errorMessage = null;
    });
    _initializePlayer();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorState();
    }

    if (_isLoading || _videoController == null || !_videoController!.value.isInitialized) {
      return _buildLoadingState();
    }

    return _buildVideoPlayer();
  }

  Widget _buildVideoPlayer() {
    final videoAspect = _videoController!.value.aspectRatio;
    
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video - centered and fitted
            Center(
              child: AspectRatio(
                aspectRatio: videoAspect,
                child: VideoPlayer(_videoController!),
              ),
            ),
            
            // Play/Pause indicator (shown on tap)
            if (_showPlayIcon || !_videoController!.value.isPlaying)
              Center(
                child: AnimatedOpacity(
                  opacity: _showPlayIcon ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: ResponsiveUtils.iconLarge(context) * 1.8,
                    height: ResponsiveUtils.iconLarge(context) * 1.8,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _videoController!.value.isPlaying 
                          ? Icons.pause_rounded 
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: ResponsiveUtils.iconLarge(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: ResponsiveUtils.iconLarge(context) * 1.3,
              height: ResponsiveUtils.iconLarge(context) * 1.3,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFE1306C), Color(0xFFC13584)],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(ResponsiveUtils.spacingSmall(context)),
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.white.withOpacity(0.5),
              size: ResponsiveUtils.iconLarge(context) * 1.2,
            ),
            SizedBox(height: ResponsiveUtils.spacingMedium(context)),
            Text(
              _errorMessage ?? 'Unable to load video',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: ResponsiveUtils.body2(context),
              ),
            ),
            SizedBox(height: ResponsiveUtils.spacingLarge(context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionChip(
                  icon: Icons.refresh_rounded,
                  label: 'Retry',
                  onTap: _retry,
                ),
                SizedBox(width: ResponsiveUtils.spacingSmall(context)),
                _buildActionChip(
                  icon: Icons.camera_alt_rounded,
                  label: 'Instagram',
                  onTap: _openInInstagram,
                  isPrimary: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.spacingMedium(context),
          vertical: ResponsiveUtils.spacingSmall(context),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ResponsiveUtils.spacingLarge(context)),
          gradient: isPrimary 
              ? const LinearGradient(colors: [Color(0xFFE1306C), Color(0xFFC13584)])
              : null,
          color: isPrimary ? null : Colors.white.withOpacity(0.15),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: ResponsiveUtils.iconSmall(context)),
            SizedBox(width: ResponsiveUtils.spacingXSmall(context)),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveUtils.caption(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
