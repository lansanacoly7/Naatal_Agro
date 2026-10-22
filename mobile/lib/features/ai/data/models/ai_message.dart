import 'dart:typed_data';

/// Données d'action métier (Phase 5 : proposition ou résultat d'une opération).
///
/// Une *proposition* (`actionType` renseigné) évolue : `pending_confirmation` puis `executed`, `failed`,
/// `cancelled`, `expired` ou `superseded`. Le *résultat* d'une proposition est un message distinct
/// (sans `actionType`) qui porte l'état final et la réponse du serveur.
class AiActionData {
  final String status;
  final String? actionType;
  final Map<String, dynamic> parameters;
  final String? summary;
  final List<String> warnings;
  final Map<String, dynamic>? result;

  const AiActionData({
    required this.status,
    this.actionType,
    this.parameters = const {},
    this.summary,
    this.warnings = const [],
    this.result,
  });

  bool get isProposal => actionType != null;
  bool get isPending => status == 'pending_confirmation';
  bool get isExecuted => status == 'executed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isExpired => status == 'expired';
  bool get isSuperseded => status == 'superseded';

  /// Identifiant du rappel créé, reporté ou annulé par cette opération (sert à resynchroniser les alarmes).
  String? get reminderId {
    final data = result?['data'];
    return data is Map ? data['notification_id']?.toString() : null;
  }

  AiActionData copyWith({String? status}) => AiActionData(
        status: status ?? this.status,
        actionType: actionType,
        parameters: parameters,
        summary: summary,
        warnings: warnings,
        result: result,
      );

  factory AiActionData.fromJson(Map<String, dynamic> json) => AiActionData(
        status: (json['status'] ?? '').toString(),
        actionType: json['action_type']?.toString(),
        parameters: json['parameters'] is Map ? Map<String, dynamic>.from(json['parameters'] as Map) : const {},
        summary: json['summary']?.toString(),
        warnings: ((json['warnings'] as List<dynamic>?) ?? const []).map((e) => e.toString()).toList(),
        result: json['result'] is Map ? Map<String, dynamic>.from(json['result'] as Map) : null,
      );
}

/// Source citée par l'assistant (fiche agronomique : titre, éditeur, lien).
class AiSource {
  final int? number;
  final String title;
  final String publisher;
  final String url;

  const AiSource({this.number, required this.title, this.publisher = '', this.url = ''});

  factory AiSource.fromJson(Map<String, dynamic> json) => AiSource(
        number: json['number'] is int ? json['number'] as int : int.tryParse('${json['number']}'),
        title: (json['title'] ?? '').toString(),
        publisher: (json['publisher'] ?? '').toString(),
        url: (json['url'] ?? '').toString(),
      );
}

/// Réponse du serveur : texte, origine (`database` = fiches vérifiées, `general` = conseil non sourcé) et sources.
class AiAnswer {
  final String text;
  final String origin;
  final List<AiSource> sources;

  /// Questions de relance proposées par l'assistant.
  final List<String> suggestions;
  final AiActionData? actionData;
  final String? conversationId;

  /// Identifiant de l'interaction côté serveur : sert à confirmer ou annuler une proposition.
  final String? interactionId;

  const AiAnswer({
    required this.text,
    required this.origin,
    this.sources = const [],
    this.suggestions = const [],
    this.actionData,
    this.conversationId,
    this.interactionId,
  });

  factory AiAnswer.fromJson(Map<String, dynamic> json) => AiAnswer(
        interactionId: json['id']?.toString(),
        text: (json['response'] ?? '').toString(),
        origin: (json['origin'] ?? 'general').toString(),
        sources: ((json['sources'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AiSource.fromJson)
            .toList(),
        suggestions: ((json['suggestions'] as List<dynamic>?) ?? const []).map((e) => e.toString()).toList(),
        actionData: json['action_data'] is Map && (json['action_data'] as Map).isNotEmpty
            ? AiActionData.fromJson(Map<String, dynamic>.from(json['action_data'] as Map))
            : null,
        conversationId: (json['conversation_id'] ?? json['conversation'])?.toString(),
      );
}

class AiMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  /// Photo envoyée avec la question (octets : fonctionne sur mobile comme dans le navigateur).
  final Uint8List? imageBytes;

  /// `database` (fiches vérifiées) ou `general` ; vide pour les messages de l'utilisateur.
  final String origin;
  final List<AiSource> sources;
  final List<String> suggestions;
  final AiActionData? actionData;
  final bool isError;

  /// Identifiant serveur de la réponse (absent pour les messages de l'utilisateur et les erreurs locales).
  final String? interactionId;

  const AiMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageBytes,
    this.origin = '',
    this.sources = const [],
    this.suggestions = const [],
    this.actionData,
    this.isError = false,
    this.interactionId,
  });

  bool get isVerified => !isUser && origin == 'database';

  /// Message d'assistant construit à partir d'une réponse du serveur.
  factory AiMessage.fromAnswer(AiAnswer answer, {required DateTime timestamp}) => AiMessage(
        text: answer.text,
        isUser: false,
        timestamp: timestamp,
        origin: answer.origin,
        sources: answer.sources,
        suggestions: answer.suggestions,
        actionData: answer.actionData,
        interactionId: answer.interactionId,
      );

  AiMessage copyWith({AiActionData? actionData}) => AiMessage(
        text: text,
        isUser: isUser,
        timestamp: timestamp,
        imageBytes: imageBytes,
        origin: origin,
        sources: sources,
        suggestions: suggestions,
        actionData: actionData ?? this.actionData,
        isError: isError,
        interactionId: interactionId,
      );
}

/// Résumé d'une conversation pour la liste d'historique
class AiConversationSummary {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final String? lastMessageQuery;
  final String? lastMessageResponse;

  const AiConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    this.lastMessageQuery,
    this.lastMessageResponse,
  });

  factory AiConversationSummary.fromJson(Map<String, dynamic> json) {
    final last = json['last_message'] is Map ? Map<String, dynamic>.from(json['last_message'] as Map) : null;
    return AiConversationSummary(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Nouvelle discussion').toString(),
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${json['updated_at']}') ?? DateTime.now(),
      messageCount: json['message_count'] is int
          ? json['message_count'] as int
          : int.tryParse('${json['message_count']}') ?? 0,
      lastMessageQuery: last?['query']?.toString(),
      lastMessageResponse: last?['response']?.toString(),
    );
  }
}

