import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/account.dart';
import '../models/ai_intent.dart';
import '../models/category.dart';

class AiAssistantService {
  final http.Client _client;

  AiAssistantService({http.Client? client}) : _client = client ?? http.Client();

  Future<AiIntent> parseMessage({
    required String functionUrl,
    required String message,
    required String currencyCode,
    required String currencySymbol,
    required List<Category> categories,
    required List<Account> accounts,
  }) async {
    if (functionUrl.trim().isEmpty) {
      throw AiAssistantException('Add your Supabase AI Function URL first.');
    }

    final uri = _resolveFunctionUri(functionUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw AiAssistantException('The Supabase AI Function URL is invalid.');
    }

    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'mode': 'parse',
        'locale': 'en-US',
        'timezone': DateTime.now().timeZoneName,
        'currencyCode': currencyCode,
        'currencySymbol': currencySymbol,
        'categories': categories
            .where((category) => category.id != null)
            .map((category) => {
                  'id': category.id,
                  'name': category.name,
                  'isExpense': category.isExpense,
                })
            .toList(),
        'accounts': accounts
            .where((account) => account.id != null)
            .map((account) => {
                  'id': account.id,
                  'name': account.name,
                  'isDefault': account.isDefault,
                })
            .toList(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiAssistantException(
        'AI request failed (${response.statusCode}). Try again later.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw AiAssistantException('AI returned an invalid response.');
    }

    try {
      return AiIntent.fromJson(decoded);
    } on FormatException catch (error) {
      throw AiAssistantException(error.message);
    }
  }

  Uri? _resolveFunctionUri(String functionUrl) {
    final trimmed = functionUrl.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return null;

    if (uri.host.endsWith('.supabase.co') &&
        !uri.path.contains('/functions/v1/')) {
      return uri.replace(path: '/functions/v1/finance-ai');
    }

    return uri;
  }
}

class AiAssistantException implements Exception {
  final String message;

  AiAssistantException(this.message);

  @override
  String toString() => message;
}
