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
    if (_isLoading) return;
    
    _setLoading(true);
    _setError(null);
    
    try {
      _userReactions = await _reactionService.getUserReactions();
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
      // Check if user already has this reaction
      final existingReactionId = _getExistingReactionId(artistId, reactionType);
      
      if (existingReactionId != null) {
        // Remove existing reaction
        await removeReaction(existingReactionId);
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

  /// Remove a reaction by ID
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
    return _userReactions?.likedArtists.contains(artistId) ?? false;
  }

  /// Check if user is following an artist
  bool isArtistFollowed(String artistId) {
    return _userReactions?.followedArtists.contains(artistId) ?? false;
  }

  /// Get the existing reaction ID for an artist and reaction type
  String? _getExistingReactionId(String artistId, ReactionType reactionType) {
    for (final reaction in _activeReactions.values) {
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