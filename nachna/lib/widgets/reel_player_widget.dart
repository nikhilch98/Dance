import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/reel.dart';

/// Widget that displays a Reel video using native video playback.
/// Videos are loaded from the GridFS-backed API.
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
  ChewieController? _chewieController;
  
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _videoController?.dispose();
  }

  Future<void> _initializePlayer() async {
    if (!widget.reel.hasVideo || widget.reel.videoUrl == null) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Video not available yet';
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
        httpHeaders: {
          'Accept': 'video/mp4',
        },
      );

      await _videoController!.initialize();

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: widget.autoPlay,
        looping: true,
        showControls: true,
        showControlsOnInitialize: false,
        aspectRatio: _videoController!.value.aspectRatio,
        placeholder: _buildLoadingState(),
        errorBuilder: (context, errorMessage) {
          return _buildErrorStateWidget('Video playback error');
        },
        customControls: const CupertinoControls(
          backgroundColor: Color(0x99000000),
          iconColor: Colors.white,
        ),
      );

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
    _disposeControllers();
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

    if (_isLoading || _chewieController == null) {
      return _buildLoadingState();
    }

    return _buildNativePlayer();
  }

  Widget _buildNativePlayer() {
    return Stack(
      children: [
        // Native video player - full screen
        Container(
          color: const Color(0xFF0A0A0F),
          child: Center(
            child: AspectRatio(
              aspectRatio: _videoController?.value.aspectRatio ?? 9 / 16,
              child: Chewie(controller: _chewieController!),
            ),
          ),
        ),
        
        // Loading overlay
        if (_isLoading)
          _buildLoadingState(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: const Color(0xFF0A0A0F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loading indicator with gradient
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.all(15),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading video...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return _buildErrorStateWidget(_errorMessage ?? 'Unable to load video');
  }

  Widget _buildErrorStateWidget(String message) {
    return Container(
      color: const Color(0xFF0A0A0F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.15),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _retry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF9C27B0)],
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _openInInstagram,
              child: const Text(
                'View on Instagram',
                style: TextStyle(
                  color: Color(0xFF00D4FF),
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF00D4FF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
