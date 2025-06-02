import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/reaction_provider.dart';
import '../models/reaction.dart';

class ArtistReactionButtons extends StatelessWidget {
  final String artistId;
  final bool isCompact;
  final Color? primaryColor;

  const ArtistReactionButtons({
    Key? key,
    required this.artistId,
    this.isCompact = false,
    this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ReactionProvider>(
      builder: (context, reactionProvider, child) {
        final isLiked = reactionProvider.isArtistLiked(artistId);
        final isNotified = reactionProvider.isArtistNotified(artistId);
        final effectiveColor = primaryColor ?? const Color(0xFFFF006E);

        if (isCompact) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCompactButton(
                context,
                icon: Icons.favorite,
                isActive: isLiked,
                color: effectiveColor,
                onTap: () => _handleReaction(context, reactionProvider, ReactionType.LIKE),
              ),
              const SizedBox(width: 8),
              _buildCompactButton(
                context,
                icon: Icons.notifications,
                isActive: isNotified,
                color: const Color(0xFF8338EC),
                onTap: () => _handleReaction(context, reactionProvider, ReactionType.NOTIFY),
              ),
            ],
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildReactionButton(
                    context,
                    icon: Icons.favorite,
                    label: 'Like',
                    isActive: isLiked,
                    color: effectiveColor,
                    onTap: () => _handleReaction(context, reactionProvider, ReactionType.LIKE),
                  ),
                  Container(
                    height: 40,
                    width: 1,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  _buildReactionButton(
                    context,
                    icon: Icons.notifications,
                    label: 'Notify',
                    isActive: isNotified,
                    color: const Color(0xFF8338EC),
                    onTap: () => _handleReaction(context, reactionProvider, ReactionType.NOTIFY),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReactionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? color : Colors.white.withOpacity(0.6),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactButton(
    BuildContext context, {
    required IconData icon,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isActive 
            ? color.withOpacity(0.2) 
            : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: isActive 
              ? color.withOpacity(0.5) 
              : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? color : Colors.white.withOpacity(0.6),
          size: 16,
        ),
      ),
    );
  }

  void _handleReaction(BuildContext context, ReactionProvider reactionProvider, ReactionType reactionType) async {
    try {
      await reactionProvider.toggleArtistReaction(artistId, reactionType);
      
      if (reactionProvider.error != null) {
        _showErrorSnackBar(context, reactionProvider.error!);
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Failed to update reaction');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
} 