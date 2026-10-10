import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_provider.dart';
import 'models/ai_message.dart';

class AiRepository {
  final ApiClient _apiClient;

  AiRepository(this._apiClient);

  Future<AiAnswer> askQuestion(String query, {String? imageBase64, List<AiMessage> history = const []}) async {
    final Map<String, dynamic> data = {
      'query': query,
      'context': 'general',
      // Mémoire de la conversation : les derniers échanges, pour que l'assistant comprenne les suites
      'history': [
        for (final m in history.where((m) => !m.isError && m.text.trim().isNotEmpty).toList().reversed.take(8).toList().reversed)
          {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
      ],
    };
    if (imageBase64 != null) {
      data['image_base64'] = imageBase64;
    }

    // Le serveur peut mettre jusqu'à ~35 s (analyse d'image, réessai si le service IA est saturé) :
    // on attend plus longtemps que le délai standard, et on ne met jamais une question en file hors ligne.
    final response = await _apiClient.post(
      AppConstants.aiAskEndpoint,
      data: data,
      receiveTimeout: const Duration(seconds: 75),
      queueWhenOffline: false,
    );

    if ((response.statusCode == 200 || response.statusCode == 201) && response.data is Map) {
      final answer = AiAnswer.fromJson(Map<String, dynamic>.from(response.data as Map));
      if (answer.text.trim().isNotEmpty) return answer;
    }
    throw Exception('Réponse de l\'assistant indisponible.');
  }

  /// Historique enregistré côté serveur (20 derniers échanges), du plus ancien au plus récent.
  Future<List<AiMessage>> fetchHistory() async {
    final response = await _apiClient.get(AppConstants.aiAskEndpoint);
    final body = response.data;
    final List<dynamic> items = body is List ? body : (body is Map ? (body['results'] as List<dynamic>? ?? const []) : const []);

    final messages = <AiMessage>[];
    for (final raw in items.reversed) {
      if (raw is! Map) continue;
      final json = Map<String, dynamic>.from(raw);
      final createdAt = DateTime.tryParse('${json['created_at']}') ?? DateTime.now();
      messages.add(AiMessage(text: (json['query'] ?? '').toString(), isUser: true, timestamp: createdAt));
      final answer = AiAnswer.fromJson(json);
      messages.add(AiMessage(
        text: answer.text,
        isUser: false,
        timestamp: createdAt,
        origin: answer.origin,
        sources: answer.sources,
        suggestions: answer.suggestions,
      ));
    }
    return messages;
  }
}

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AiRepository(apiClient);
});

class ChatState {
  final List<AiMessage> messages;
  final bool isLoading;
  final bool isLoadingHistory;

  const ChatState({this.messages = const [], this.isLoading = false, this.isLoadingHistory = false});

  ChatState copyWith({List<AiMessage>? messages, bool? isLoading, bool? isLoadingHistory}) => ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final AiRepository _repository;

  ChatNotifier(this._repository) : super(const ChatState(isLoadingHistory: true)) {
    loadHistory();
  }

  /// Recharge les échanges déjà enregistrés : rien n'est perdu en quittant la page ou l'application.
  Future<void> loadHistory() async {
    try {
      final history = await _repository.fetchHistory();
      if (!mounted) return;
      // Si l'utilisateur a déjà écrit pendant le chargement, on garde sa conversation sans dupliquer l'historique
      state = state.copyWith(messages: state.messages.isEmpty ? history : state.messages, isLoadingHistory: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  Future<void> sendMessage(String text, {String? imageBase64, Uint8List? imageBytes}) async {
    if (state.isLoading) return;
    if (text.trim().isEmpty && imageBase64 == null) return;

    final previousMessages = state.messages;
    state = state.copyWith(
      messages: [
        ...state.messages,
        AiMessage(text: text, isUser: true, timestamp: DateTime.now(), imageBytes: imageBytes),
      ],
      isLoading: true,
    );

    try {
      final answer = await _repository.askQuestion(
        text.trim().isEmpty ? 'Analyse cette image.' : text,
        imageBase64: imageBase64,
        history: previousMessages,
      );
      if (!mounted) return;
      state = state.copyWith(
        messages: [
          ...state.messages,
          AiMessage(
            text: answer.text,
            isUser: false,
            timestamp: DateTime.now(),
            origin: answer.origin,
            sources: answer.sources,
            suggestions: answer.suggestions,
          ),
        ],
        isLoading: false,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      final message = status == 429
          ? 'Vous avez atteint la limite de questions par heure. Réessayez un peu plus tard.'
          : e.type == DioExceptionType.receiveTimeout
              ? "L'assistant met trop de temps à répondre (service très sollicité). Réessayez dans un instant."
              : (status != null && status >= 500)
                  ? "Le service de l'assistant est momentanément indisponible. Réessayez dans un instant."
                  : 'Connexion impossible. Vérifiez votre réseau puis réessayez.';
      _addError(message);
    } catch (_) {
      if (!mounted) return;
      _addError('L\'assistant n\'a pas pu répondre. Réessayez dans un instant.');
    }
  }

  void _addError(String message) {
    state = state.copyWith(
      messages: [...state.messages, AiMessage(text: message, isUser: false, timestamp: DateTime.now(), isError: true)],
      isLoading: false,
    );
  }

  /// Vide l'écran. L'historique reste enregistré sur le serveur.
  void clearChat() {
    state = state.copyWith(messages: const [], isLoading: false);
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repository = ref.watch(aiRepositoryProvider);
  // Une conversation par compte : elle est recréée à chaque connexion ou déconnexion
  ref.watch(authStateProvider);
  return ChatNotifier(repository);
});

// NAATAL_IA_IMPROVEMENT : Provider pour la langue
final aiLanguageProvider = StateProvider<String>((ref) => 'Fr');
