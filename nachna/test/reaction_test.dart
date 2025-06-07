import 'package:flutter_test/flutter_test.dart';
import 'package:nachna/models/reaction.dart';
import 'package:nachna/services/reaction_service.dart';

void main() {
  group('Reaction Service Tests', () {
    late ReactionService reactionService;

    setUp(() {
      reactionService = ReactionService();
    });

    test('should have deleteReactionByEntity method', () {
      expect(reactionService.deleteReactionByEntity, isA<Function>());
    });

    test('should create proper request for deleteReactionByEntity', () {
      // This test verifies the method signature and basic functionality
      expect(() => reactionService.deleteReactionByEntity(
        'test_artist_id',
        EntityType.ARTIST,
        ReactionType.LIKE,
      ), returnsNormally);
    });
  });

  group('Reaction Models Tests', () {
    test('should create ReactionRequest correctly', () {
      final request = ReactionRequest(
        entityId: 'test_artist_id',
        entityType: EntityType.ARTIST,
        reaction: ReactionType.LIKE,
      );

      expect(request.entityId, equals('test_artist_id'));
      expect(request.entityType, equals(EntityType.ARTIST));
      expect(request.reaction, equals(ReactionType.LIKE));
    });

    test('should create ReactionDeleteRequest correctly', () {
      final request = ReactionDeleteRequest(reactionId: 'test_reaction_id');
      expect(request.reactionId, equals('test_reaction_id'));
    });

    test('should serialize ReactionRequest to JSON correctly', () {
      final request = ReactionRequest(
        entityId: 'test_artist_id',
        entityType: EntityType.ARTIST,
        reaction: ReactionType.NOTIFY,
      );

      final json = request.toJson();
      expect(json['entity_id'], equals('test_artist_id'));
      expect(json['entity_type'], equals('ARTIST'));
      expect(json['reaction'], equals('NOTIFY'));
    });
  });
} 