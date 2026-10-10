import 'dart:typed_data';

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

  const AiAnswer({required this.text, required this.origin, this.sources = const [], this.suggestions = const []});

  factory AiAnswer.fromJson(Map<String, dynamic> json) => AiAnswer(
        text: (json['response'] ?? '').toString(),
        origin: (json['origin'] ?? 'general').toString(),
        sources: ((json['sources'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AiSource.fromJson)
            .toList(),
        suggestions: ((json['suggestions'] as List<dynamic>?) ?? const []).map((e) => e.toString()).toList(),
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
  final bool isError;

  const AiMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageBytes,
    this.origin = '',
    this.sources = const [],
    this.suggestions = const [],
    this.isError = false,
  });

  bool get isVerified => !isUser && origin == 'database';
}
