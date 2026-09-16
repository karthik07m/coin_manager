import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/account.dart';
import '../models/ai_intent.dart';
import '../models/category.dart';

class AiAssistantService {
  /// Supabase's public anon key, sent as the project `apikey`. Not a secret
  /// (it ships in the binary like the URL); the per-user session below is
  /// what the function actually checks.
  static const _anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZycGdhYXBrYW5peGJxdXJ4cXd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIyNTc0MjUsImV4cCI6MjA5NzgzMzQyNX0.Fe7c8FlF7gmzrQ3X-18XfMl9pGJDWPxXIu25w0n8MiU',
  );

  final http.Client _client;

  /// AI requests left in this month's allowance, as of the last cloud call.
  /// Null until the cloud has answered once, or when talking to a deployment
  /// that predates the field.
  int? lastCreditsRemaining;

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

    final body = jsonEncode({
      'message': message,
      'mode': 'parse',
      'locale': 'en-US',
      'timezone': DateTime.now().timeZoneName,
      'now': _localNow(),
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
    });

    var response = await _post(uri, body, await _accessToken(uri));
    if (response.statusCode == 401) {
      // Token revoked or expired early: refresh once and retry.
      response = await _post(
          uri, body, await _accessToken(uri, forceRefresh: true));
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiAssistantException(
        'AI request failed (${response.statusCode}). Try again later.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw AiAssistantException('AI returned an invalid response.');
    }

    final remaining = decoded['creditsRemaining'];
    if (remaining is num) lastCreditsRemaining = remaining.toInt();

    try {
      return AiIntent.fromJson(decoded);
    } on FormatException catch (error) {
      throw AiAssistantException(error.message);
    }
  }

  // Per-install anonymous Supabase user. The function charges the monthly
  // AI allowance to this user's id, which (unlike a device id) can't be
  // forged. The tokens only unlock this install's AI quota, so plain
  // SharedPreferences is enough.
  static const _prefsAccess = 'ai_session_access_token';
  static const _prefsRefresh = 'ai_session_refresh_token';
  static const _prefsExpiry = 'ai_session_expires_at';

  Future<http.Response> _post(Uri uri, String body, String accessToken) {
    return _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'apikey': _anonKey,
      },
      body: body,
    );
  }

  Future<String> _accessToken(Uri functionUri, {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_prefsAccess);
    final refresh = prefs.getString(_prefsRefresh);
    final expiresAt = prefs.getInt(_prefsExpiry) ?? 0;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (!forceRefresh && access != null && nowSec < expiresAt - 60) {
      return access;
    }

    final auth = '${functionUri.scheme}://${functionUri.authority}/auth/v1';
    const headers = {'Content-Type': 'application/json', 'apikey': _anonKey};

    if (refresh != null) {
      final res = await _client.post(
        Uri.parse('$auth/token?grant_type=refresh_token'),
        headers: headers,
        body: jsonEncode({'refresh_token': refresh}),
      );
      if (res.statusCode == 200) return _saveSession(prefs, res.body);
      // Only a rejected refresh token starts over. A server or network error
      // must not mint a fresh user, or retries would reset the allowance.
      if (res.statusCode != 400 && res.statusCode != 401 && res.statusCode != 403) {
        throw AiAssistantException(
            'AI sign-in failed (${res.statusCode}). Try again later.');
      }
    }

    final res = await _client.post(Uri.parse('$auth/signup'),
        headers: headers, body: '{}');
    if (res.statusCode != 200) {
      throw AiAssistantException(
          'Could not start an AI session (${res.statusCode}). Try again later.');
    }
    return _saveSession(prefs, res.body);
  }

  Future<String> _saveSession(SharedPreferences prefs, String body) async {
    final session = jsonDecode(body) as Map<String, dynamic>;
    final access = session['access_token'] as String;
    final expiresAt = (session['expires_at'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000 +
            ((session['expires_in'] as num?)?.toInt() ?? 3600);
    await prefs.setString(_prefsAccess, access);
    await prefs.setString(_prefsRefresh, session['refresh_token'] as String);
    await prefs.setInt(_prefsExpiry, expiresAt);
    return access;
  }

  /// The phone's wall-clock time with its UTC offset, e.g.
  /// 2026-09-13T21:08:00-04:00. The function resolves "today" / "this
  /// morning" against this; its own clock is UTC, which is already tomorrow
  /// for evening users west of Greenwich.
  static String _localNow() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '${now.toIso8601String().split('.').first}$sign$hours:$minutes';
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
