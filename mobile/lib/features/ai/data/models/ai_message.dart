class AiMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imagePath;

  AiMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imagePath,
  });
}
