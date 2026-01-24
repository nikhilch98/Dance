import 'package:flutter/foundation.dart';
import '../models/reaction.dart';
import '../services/reaction_service.dart';

class ReactionProvider with ChangeNotifier {
  final ReactionService _reactionService = ReactionService();
  
  // User's reactions
  UserReactionsResponse? _userReactions;
  UserReactionsResponse? get userReactions => _userReactions;
  
  // Active reactions cache (reaction_id -> ReactionResponse)
  final Map<String, ReactionResponse> _activeReactions = {};
  
  // Loading states
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  // Error state
  String? _error;
  String? get error => _error;

  /// Set authentication token
  void setAuthToken(String token) {
    _reactionService.setAuthToken(token);
  }

  /// Load user's reactions
  Future<void> loadUserReactions() async {
    if (_isLoading) return; // Prevent duplicate calls
    
    _setLoading(true);
    _setError(null);
    
    try {
      _userReactions = await _reactionService.getUserReactions();
      
      // Clear and rebuild active reactions cache from user reactions
      _activeReactions.clear();
      
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Create or toggle a reaction for an artist
  Future<ReactionResponse?> toggleArtistReaction(String artistId, ReactionType reactionType) async {
    _setError(null);
    
    try {
      // Check if user already has this reaction by checking the simplified lists
      bool hasReaction = false;
      if (reactionType == ReactionType.LIKE) {
        hasReaction = isArtistLiked(artistId);
      } else if (reactionType == ReactionType.NOTIFY) {
        hasReaction = isArtistNotified(artistId);
      }
      
      if (hasReaction) {
        // Remove existing reaction - we need to find and delete it
        await removeReactionByEntity(artistId, reactionType);
        return null;
      } else {
        // Create new reaction
        final request = ReactionRequest(
          entityId: artistId,
          entityType: EntityType.ARTIST,
          reaction: reactionType,
        );
        
        final response = await _reactionService.createReaction(request);
        
        // Update cache
        _activeReactions[response.id] = response;
        
        // Refresh user reactions
        await loadUserReactions();
        
        return response;
      }
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Remove a reaction by entity and reaction type (for unlike/unfollow)
  Future<bool> removeReactionByEntity(String artistId, ReactionType reactionType) async {
    _setError(null);
    
    try {
      // Use the new API endpoint that deletes by entity and reaction type
      final success = await _reactionService.deleteReactionByEntity(
        artistId, 
        EntityType.ARTIST, 
        reactionType
      );
      
      if (success) {
        // Refresh user reactions to update the UI
        await loadUserReactions();
      }
      
      return success;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Remove a reaction by ID (kept for backward compatibility)
  Future<bool> removeReaction(String reactionId) async {
    _setError(null);
    
    try {
      final request = ReactionDeleteRequest(reactionId: reactionId);
      final success = await _reactionService.deleteReaction(request);
      
      if (success) {
        // Remove from cache
        _activeReactions.remove(reactionId);
        
        // Refresh user reactions
        await loadUserReactions();
      }
      
      return success;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  /// Get reaction statistics for an artist
  Future<ReactionStatsResponse?> getArtistStats(String artistId) async {
    try {
      return await _reactionService.getReactionStats(artistId, EntityType.ARTIST);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Check if user has liked an artist
  bool isArtistLiked(String artistId) {
    if (artistId.isEmpty) return false;
    final likedArtists = _userReactions?.likedArtists;
    if (likedArtists == null) return false;
    return likedArtists.contains(artistId);
  }

  /// Check if user has notifications enabled for an artist
  bool isArtistNotified(String artistId) {
    if (artistId.isEmpty) return false;
    final notifiedArtists = _userReactions?.notifiedArtists;
    if (notifiedArtists == null) return false;
    return notifiedArtists.contains(artistId);
  }

  /// Get the existing reaction ID for an artist and reaction type
  String? _getExistingReactionId(String artistId, ReactionType reactionType) {
    if (artistId.isEmpty) return null;
    for (final reaction in _activeReactions.values) {
      // ReactionResponse fields are non-nullable (required in constructor)
      if (reaction.entityId == artistId &&
          reaction.reaction == reactionType &&
          reaction.entityType == EntityType.ARTIST &&
          !reaction.isDeleted) {
        return reaction.id;
      }
    }
    return null;
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error state
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error state
  void clearError() {
    _setError(null);
  }
} 