import 'ai_intent.dart';

enum AiMessageRole {
  user,
  assistant,
}

class AiAssistantMessage {
  final AiMessageRole role;
  final String text;
  final DateTime createdAt;
  final AiTransactionDraft? transactionDraft;

  /// Tappable follow-up prompts shown under the newest assistant message.
  final List<String> suggestions;

  const AiAssistantMessage({
    required this.role,
    required this.text,
    required this.createdAt,
    this.transactionDraft,
    this.suggestions = const [],
  });

  factory AiAssistantMessage.user(String text) {
    return AiAssistantMessage(
      role: AiMessageRole.user,
      text: text,
      createdAt: DateTime.now(),
    );
  }

  factory AiAssistantMessage.assistant(
    String text, {
    AiTransactionDraft? transactionDraft,
    List<String> suggestions = const [],
  }) {
    return AiAssistantMessage(
      role: AiMessageRole.assistant,
      text: text,
      createdAt: DateTime.now(),
      transactionDraft: transactionDraft,
      suggestions: suggestions,
    );
  }
}
