import 'package:flutter_test/flutter_test.dart';
import 'package:nataal_agro/features/ai/data/models/ai_message.dart';
import 'package:nataal_agro/features/ai/data/ai_provider.dart';

void main() {
  group('Phase 1 - AiConversationSummary Model', () {
    test('Désérialise fidèlement une conversation avec last_message', () {
      final json = {
        'id': 'd6c70b80-87b4-4b53-8b74-1b3260c6c745',
        'title': 'Traitement Mildiou Niayes',
        'created_at': '2026-10-21T10:00:00Z',
        'updated_at': '2026-10-21T10:30:00Z',
        'message_count': 4,
        'last_message': {
          'id': 'e2f9d8a1-1234-4567-89ab-cdef01234567',
          'query': 'Quel dosage pour le purin de neem ?',
          'response': 'Mélangez 500g de feuilles broyées dans 10 litres d\'eau.',
          'created_at': '2026-10-21T10:30:00Z',
        },
      };

      final conv = AiConversationSummary.fromJson(json);

      expect(conv.id, 'd6c70b80-87b4-4b53-8b74-1b3260c6c745');
      expect(conv.title, 'Traitement Mildiou Niayes');
      expect(conv.messageCount, 4);
      expect(conv.lastMessageQuery, 'Quel dosage pour le purin de neem ?');
      expect(conv.lastMessageResponse, contains('500g de feuilles'));
    });

    test('Gère une conversation neuve sans aucun message', () {
      final json = {
        'id': '00000000-0000-0000-0000-000000000000',
        'title': 'Nouvelle discussion',
        'created_at': '2026-10-21T11:00:00Z',
        'updated_at': '2026-10-21T11:00:00Z',
        'message_count': 0,
        'last_message': null,
      };

      final conv = AiConversationSummary.fromJson(json);

      expect(conv.id, '00000000-0000-0000-0000-000000000000');
      expect(conv.title, 'Nouvelle discussion');
      expect(conv.messageCount, 0);
      expect(conv.lastMessageQuery, isNull);
      expect(conv.lastMessageResponse, isNull);
    });
  });

  group('Phase 1 - ChatState Management', () {
    test('copyWith met à jour le titre et permet de vider l\'identifiant de conversation', () {
      const state = ChatState(
        currentConversationId: 'id-initial',
        currentConversationTitle: 'Titre Initial',
      );

      final nextState = state.copyWith(
        currentConversationTitle: 'Titre Renommé',
      );
      expect(nextState.currentConversationId, 'id-initial');
      expect(nextState.currentConversationTitle, 'Titre Renommé');

      final clearedState = state.copyWith(
        clearConversationId: true,
        clearConversationTitle: true,
      );
      expect(clearedState.currentConversationId, isNull);
      expect(clearedState.currentConversationTitle, isNull);
    });
  });
}
