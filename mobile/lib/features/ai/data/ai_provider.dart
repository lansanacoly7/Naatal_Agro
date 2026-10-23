import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_provider.dart';
import '../../reminders/data/reminder_sync.dart';
import 'models/ai_message.dart';

/// Échec de la voix, avec un message que l'on peut montrer tel quel à l'utilisateur.
class VoiceException implements Exception {
  final String message;
  const VoiceException(this.message);

  @override
  String toString() => message;
}

class AiRepository {
  final ApiClient _apiClient;

  AiRepository(this._apiClient);

  Future<AiAnswer> askQuestion(
    String query, {
    String? imageBase64,
    List<AiMessage> history = const [],
    String? conversationId,
    String? language,
  }) async {
    final Map<String, dynamic> data = {
      'query': query,
      'context': 'general',
      if (language != null && language.isNotEmpty) 'language': language,
      // Mémoire de la conversation : les 20 derniers échanges pour un suivi continu et complet
      'history': [
        for (final m in history.where((m) => !m.isError && m.text.trim().isNotEmpty).toList().reversed.take(20).toList().reversed)
          {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
      ],
    };
    if (imageBase64 != null) {
      data['image_base64'] = imageBase64;
    }
    if (conversationId != null && conversationId.isNotEmpty) {
      data['conversation_id'] = conversationId;
    }

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
      messages.add(AiMessage.fromAnswer(AiAnswer.fromJson(json), timestamp: createdAt));
    }
    return messages;
  }

  /// Liste des conversations sauvegardées de l'utilisateur.
  Future<List<AiConversationSummary>> fetchConversations() async {
    final response = await _apiClient.get(AppConstants.aiConversationsEndpoint);
    final body = response.data;
    final List<dynamic> items = body is List ? body : (body is Map ? (body['results'] as List<dynamic>? ?? const []) : const []);

    return items
        .whereType<Map<String, dynamic>>()
        .map(AiConversationSummary.fromJson)
        .toList();
  }

  /// Charge tous les messages d'une conversation spécifique.
  Future<List<AiMessage>> fetchConversationMessages(String conversationId) async {
    final response = await _apiClient.get(AppConstants.aiConversationEndpoint(conversationId));
    if (response.data is! Map) return const [];
    final json = Map<String, dynamic>.from(response.data as Map);
    final interactions = (json['interactions'] as List<dynamic>? ?? const []);

    final messages = <AiMessage>[];
    for (final item in interactions) {
      if (item is! Map) continue;
      final mJson = Map<String, dynamic>.from(item);
      final createdAt = DateTime.tryParse('${mJson['created_at']}') ?? DateTime.now();
      messages.add(AiMessage(
        text: (mJson['query'] ?? '').toString(),
        isUser: true,
        timestamp: createdAt,
      ));
      messages.add(AiMessage.fromAnswer(AiAnswer.fromJson(mJson), timestamp: createdAt));
    }
    return messages;
  }

  /// Supprime une conversation.
  Future<void> deleteConversation(String conversationId) async {
    await _apiClient.delete(AppConstants.aiConversationEndpoint(conversationId));
  }

  /// Renomme une conversation existante.
  Future<AiConversationSummary> renameConversation(String conversationId, String newTitle) async {
    final response = await _apiClient.patch(
      AppConstants.aiConversationEndpoint(conversationId),
      data: {'title': newTitle},
    );
    if (response.data is Map) {
      return AiConversationSummary.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    throw Exception('Échec du renommage de la discussion.');
  }

  /// Transcrit un enregistrement audio en texte (la lecture à voix haute, elle, se fait sur l'appareil).
  ///
  /// Lève une [VoiceException] dont le message est affichable tel quel (enregistrement trop court, rien d'audible,
  /// service indisponible…).
  Future<String> transcribeAudio(Uint8List audioBytes) async {
    try {
      final response = await _apiClient.post(
        AppConstants.aiTranscribeEndpoint,
        data: {'audio_base64': base64Encode(audioBytes)},
      );
      if (response.data is Map && response.data['text'] != null) {
        return response.data['text'].toString();
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map ? data['error']?.toString() : null;
      throw VoiceException(message ?? 'Impossible de joindre le service de transcription. Vérifiez votre connexion ou écrivez votre message.');
    }
    throw const VoiceException('La transcription a échoué. Réessayez ou écrivez votre message.');
  }

  /// Confirme ou annule une proposition d'opération déjà faite par l'assistant.
  ///
  /// Seul l'identifiant de la proposition est envoyé : le serveur exécute les paramètres qu'il a lui-même
  /// enregistrés. L'appel est idempotent : le renvoyer (double appui, reprise après coupure réseau) ne
  /// peut pas enregistrer l'opération deux fois.
  Future<AiAnswer> resolveProposal(String interactionId, {required bool confirm}) async {
    final response = await _apiClient.post(
      AppConstants.aiResolveActionEndpoint,
      data: {
        'interaction_id': interactionId,
        'decision': confirm ? 'confirm' : 'cancel',
      },
      queueWhenOffline: false,
    );
    if ((response.statusCode == 200 || response.statusCode == 201) && response.data is Map) {
      return AiAnswer.fromJson(Map<String, dynamic>.from(response.data as Map));
    }
    throw Exception('Échec de validation de l\'opération.');
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
  final String? currentConversationId;
  final String? currentConversationTitle;
  final List<AiConversationSummary> conversations;
  final bool isLoadingConversations;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingHistory = false,
    this.currentConversationId,
    this.currentConversationTitle,
    this.conversations = const [],
    this.isLoadingConversations = false,
  });

  ChatState copyWith({
    List<AiMessage>? messages,
    bool? isLoading,
    bool? isLoadingHistory,
    String? currentConversationId,
    bool clearConversationId = false,
    String? currentConversationTitle,
    bool clearConversationTitle = false,
    List<AiConversationSummary>? conversations,
    bool? isLoadingConversations,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
        currentConversationId: clearConversationId ? null : (currentConversationId ?? this.currentConversationId),
        currentConversationTitle:
            clearConversationTitle ? null : (currentConversationTitle ?? this.currentConversationTitle),
        conversations: conversations ?? this.conversations,
        isLoadingConversations: isLoadingConversations ?? this.isLoadingConversations,
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final AiRepository _repository;

  /// Appelé quand l'assistant vient de créer, reporter ou annuler un rappel : les alarmes de l'appareil
  /// doivent alors être resynchronisées avec le serveur.
  final void Function()? _onReminderChanged;

  ChatNotifier(this._repository, {void Function()? onReminderChanged})
      : _onReminderChanged = onReminderChanged,
        super(const ChatState(isLoadingHistory: true)) {
    initChatSession();
  }

  /// Initialise la session : charge les conversations existantes et restaure la plus récente.
  Future<void> initChatSession() async {
    try {
      state = state.copyWith(isLoadingConversations: true, isLoadingHistory: true);
      final convs = await _repository.fetchConversations();
      if (!mounted) return;

      if (convs.isNotEmpty) {
        final latest = convs.first;
        final messages = await _repository.fetchConversationMessages(latest.id);
        if (!mounted) return;
        state = state.copyWith(
          conversations: convs,
          currentConversationId: latest.id,
          currentConversationTitle: latest.title,
          messages: messages,
          isLoadingConversations: false,
          isLoadingHistory: false,
        );
      } else {
        state = state.copyWith(
          conversations: const [],
          clearConversationId: true,
          currentConversationTitle: 'Nouvelle discussion',
          messages: const [],
          isLoadingConversations: false,
          isLoadingHistory: false,
        );
      }
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingConversations: false,
        isLoadingHistory: false,
        currentConversationTitle: 'Nouvelle discussion',
      );
    }
  }

  /// Charge la liste de toutes les conversations de l'utilisateur.
  Future<void> loadConversations() async {
    try {
      state = state.copyWith(isLoadingConversations: true);
      final list = await _repository.fetchConversations();
      if (!mounted) return;
      state = state.copyWith(
        conversations: list,
        isLoadingConversations: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoadingConversations: false);
    }
  }

  /// Bascule sur une conversation existante.
  Future<void> selectConversation(String conversationId) async {
    try {
      final summary = state.conversations.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => AiConversationSummary(
          id: conversationId,
          title: 'Discussion',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          messageCount: 0,
        ),
      );

      state = state.copyWith(
        isLoading: true,
        currentConversationId: conversationId,
        currentConversationTitle: summary.title,
      );
      final messages = await _repository.fetchConversationMessages(conversationId);
      if (!mounted) return;
      state = state.copyWith(
        messages: messages,
        isLoading: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
      _addError('Impossible de charger cette discussion.');
    }
  }

  /// Renomme une conversation.
  Future<bool> renameConversation(String conversationId, String newTitle) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) return false;
    try {
      final updated = await _repository.renameConversation(conversationId, trimmed);
      final updatedList = state.conversations.map((c) => c.id == conversationId ? updated : c).toList();
      state = state.copyWith(
        conversations: updatedList,
        currentConversationTitle:
            state.currentConversationId == conversationId ? updated.title : state.currentConversationTitle,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Démarre une nouvelle conversation propre.
  void startNewConversation() {
    state = state.copyWith(
      messages: const [],
      clearConversationId: true,
      currentConversationTitle: 'Nouvelle discussion',
      isLoading: false,
    );
  }

  /// Supprime une conversation.
  Future<bool> deleteConversation(String conversationId) async {
    try {
      await _repository.deleteConversation(conversationId);
      final updated = state.conversations.where((c) => c.id != conversationId).toList();
      final isCurrent = state.currentConversationId == conversationId;
      state = state.copyWith(
        conversations: updated,
        messages: isCurrent ? const [] : state.messages,
        clearConversationId: isCurrent,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendMessage(String text, {String? imageBase64, Uint8List? imageBytes, String? language}) async {
    if (state.isLoading) return;
    if (text.trim().isEmpty && imageBase64 == null) return;

    final effectiveText = text.trim().isEmpty && imageBase64 != null
        ? 'Photo de ma plante transmise pour analyse'
        : text;

    final previousMessages = state.messages;
    state = state.copyWith(
      messages: [
        ...state.messages,
        AiMessage(text: effectiveText, isUser: true, timestamp: DateTime.now(), imageBytes: imageBytes),
      ],
      isLoading: true,
    );

    try {
      final answer = await _repository.askQuestion(
        effectiveText,
        imageBase64: imageBase64,
        history: previousMessages,
        conversationId: state.currentConversationId,
        language: language,
      );
      if (!mounted) return;

      final newConvId = answer.conversationId ?? state.currentConversationId;

      state = state.copyWith(
        messages: [
          ...state.messages,
          AiMessage.fromAnswer(answer, timestamp: DateTime.now()),
        ],
        currentConversationId: newConvId,
        isLoading: false,
      );

      _notifyIfReminderChanged(answer);
      // Rafraîchir la liste des conversations en arrière-plan
      loadConversations();
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

  /// Confirme ou annule une proposition d'opération (boutons de la carte d'action).
  ///
  /// La carte de la proposition prend l'état renvoyé par le serveur (exécutée, annulée, expirée…) ; en cas de
  /// coupure réseau elle reste confirmable, et rappuyer est sans risque car le serveur n'enregistre qu'une fois.
  Future<void> resolveProposal(AiMessage proposal, {required bool confirm}) async {
    final interactionId = proposal.interactionId;
    if (state.isLoading || interactionId == null) return;

    state = state.copyWith(
      messages: [
        ...state.messages,
        AiMessage(text: confirm ? 'Oui, je confirme' : 'Non, j\'annule', isUser: true, timestamp: DateTime.now()),
      ],
      isLoading: true,
    );

    try {
      final answer = await _repository.resolveProposal(interactionId, confirm: confirm);
      if (!mounted) return;
      final finalStatus = answer.actionData?.status;
      state = state.copyWith(
        messages: [
          for (final m in state.messages)
            if (m.interactionId == interactionId && m.actionData != null && finalStatus != null)
              m.copyWith(actionData: m.actionData!.copyWith(status: finalStatus))
            else
              m,
          AiMessage.fromAnswer(answer, timestamp: DateTime.now()),
        ],
        isLoading: false,
      );
      _notifyIfReminderChanged(answer);
      loadConversations();
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final serverMessage = data is Map ? data['error']?.toString() : null;
      _addError(
        (status == 404 || status == 409) && serverMessage != null && serverMessage.isNotEmpty
            ? serverMessage
            : status == 429
                ? 'Trop de demandes en peu de temps. Réessayez dans un instant.'
                : 'Connexion interrompue : l\'opération n\'a peut-être pas été traitée. '
                    'Appuyez de nouveau sur « Confirmer » : elle ne sera enregistrée qu\'une seule fois.',
      );
    } catch (_) {
      if (!mounted) return;
      _addError('La validation n\'a pas pu aboutir. Réessayez dans un instant.');
    }
  }

  void _notifyIfReminderChanged(AiAnswer answer) {
    final action = answer.actionData;
    if (action != null && action.isExecuted && !action.isProposal && action.reminderId != null) {
      _onReminderChanged?.call();
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
    startNewConversation();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repository = ref.watch(aiRepositoryProvider);
  // Une conversation par compte : elle est recréée à chaque connexion ou déconnexion
  ref.watch(authStateProvider);
  return ChatNotifier(repository, onReminderChanged: () => ref.read(reminderSyncProvider).syncQuietly());
});

// NAATAL_IA_IMPROVEMENT : Provider pour la langue
final aiLanguageProvider = StateProvider<String>((ref) => 'Fr');
