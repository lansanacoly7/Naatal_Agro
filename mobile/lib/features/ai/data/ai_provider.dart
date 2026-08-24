import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../auth/data/auth_provider.dart';
import 'models/ai_message.dart';

class AiRepository {
  final ApiClient _apiClient;

  AiRepository(this._apiClient);

  Future<String> askQuestion(String query, {String? imageBase64}) async {
    final Map<String, dynamic> data = {'query': query, 'context': 'general'};
    if (imageBase64 != null) {
      data['image_base64'] = imageBase64;
    }
    
    final response = await _apiClient.post(
      AppConstants.aiAskEndpoint,
      data: data,
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.data['response'] ?? 'Désolé, je n\'ai pas pu formuler une réponse.';
    } else {
      throw Exception('Erreur lors de la communication avec l\'IA');
    }
  }
}

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AiRepository(apiClient);
});

class ChatNotifier extends StateNotifier<List<AiMessage>> {
  final AiRepository _repository;
  bool isLoading = false;

  ChatNotifier(this._repository) : super([]);

  Future<void> sendMessage(String text, {String? imageBase64, String? imagePath}) async {
    if (text.trim().isEmpty && imageBase64 == null) return;

    // Add user message
    state = [
      ...state,
      AiMessage(text: text, isUser: true, timestamp: DateTime.now(), imagePath: imagePath),
    ];

    isLoading = true;
    
    try {
      final responseText = await _repository.askQuestion(text, imageBase64: imageBase64);
      state = [
        ...state,
        AiMessage(text: responseText, isUser: false, timestamp: DateTime.now()),
      ];
    } catch (e) {
      state = [
        ...state,
        AiMessage(text: 'Erreur de connexion. Veuillez réessayer.', isUser: false, timestamp: DateTime.now()),
      ];
    } finally {
      isLoading = false;
    }
  }

  void clearChat() {
    state = [];
    isLoading = false;
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<AiMessage>>((ref) {
  final repository = ref.watch(aiRepositoryProvider);
  return ChatNotifier(repository);
});

// NAATAL_IA_IMPROVEMENT : Provider pour la langue
final aiLanguageProvider = StateProvider<String>((ref) => 'Fr');

// NAATAL_IA_IMPROVEMENT : Provider pour l'historique
class AiInteraction {
  final String firstMessage;
  final DateTime date;
  AiInteraction({required this.firstMessage, required this.date});
}

final aiInteractionProvider = StateProvider<List<AiInteraction>>((ref) => [
  AiInteraction(firstMessage: 'Comment traiter les pucerons ?', date: DateTime.now().subtract(const Duration(days: 2))),
  AiInteraction(firstMessage: 'Prix du mil  Touba', date: DateTime.now().subtract(const Duration(days: 5))),
]);
