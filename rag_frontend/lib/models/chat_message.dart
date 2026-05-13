class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    this.sources,
    this.followUps,
    this.chartData,
    this.isAnimationFinished = false,
  });

  final String role;
  final String text;
  final String? sources;
  final List<String>? followUps;
  final List<dynamic>? chartData;

  /// After the typewriter runs once, this is set so the bubble stays on static markdown.
  bool isAnimationFinished;
}
