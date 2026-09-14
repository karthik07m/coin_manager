import 'dart:convert';

import 'package:coin_manager/models/account.dart';
import 'package:coin_manager/models/category.dart';
import 'package:coin_manager/services/ai_assistant_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The monthly AI allowance is charged to the anonymous user behind the token,
// so these pin down when the app creates a user and when it must not.
void main() {
  const functionUrl = 'https://example.supabase.co/functions/v1/finance-ai';
  final categories = [
    Category(id: 1, name: 'Food', icon: 'food.png', isExpense: true),
  ];
  final accounts = [
    Account(
      id: 1,
      name: 'Cash',
      icon: 'wallet',
      color: '#4CAF50',
      isDefault: true,
      createdOn: DateTime(2026),
      modifiedOn: DateTime(2026),
    ),
  ];
  const ok = '{"intent":"unsupported","confidence":0,"message":"ok"}';
  String session(String access, String refresh) => jsonEncode(
      {'access_token': access, 'refresh_token': refresh, 'expires_in': 3600});

  Future<void> ask(AiAssistantService service) => service.parseMessage(
        functionUrl: functionUrl,
        message: 'chai two hundred',
        currencyCode: 'INR',
        currencySymbol: '₹',
        categories: categories,
        accounts: accounts,
      );

  test('signs up once, then reuses the saved token', () async {
    SharedPreferences.setMockInitialValues({});
    var signups = 0;
    final bearers = <String?>[];
    final client = MockClient((req) async {
      if (req.url.path == '/auth/v1/signup') {
        signups++;
        return http.Response(session('a1', 'r1'), 200);
      }
      expect(req.headers['apikey'], isNotEmpty);
      bearers.add(req.headers['Authorization']);
      return http.Response(ok, 200);
    });
    final service = AiAssistantService(client: client);

    await ask(service);
    await ask(service);

    expect(signups, 1);
    expect(bearers, ['Bearer a1', 'Bearer a1']);
  });

  test('a 401 refreshes the session and retries once', () async {
    SharedPreferences.setMockInitialValues({
      'ai_session_access_token': 'a1',
      'ai_session_refresh_token': 'r1',
      'ai_session_expires_at': 4102444800, // 2100: looks valid locally
    });
    final bearers = <String?>[];
    final client = MockClient((req) async {
      if (req.url.path == '/auth/v1/signup') fail('must not create a user');
      if (req.url.path == '/auth/v1/token') {
        expect(jsonDecode(req.body)['refresh_token'], 'r1');
        return http.Response(session('a2', 'r2'), 200);
      }
      bearers.add(req.headers['Authorization']);
      return req.headers['Authorization'] == 'Bearer a1'
          ? http.Response('{"msg":"expired"}', 401)
          : http.Response(ok, 200);
    });

    await ask(AiAssistantService(client: client));

    expect(bearers, ['Bearer a1', 'Bearer a2']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ai_session_refresh_token'), 'r2');
  });

  test('a server error during refresh does not mint a new user', () async {
    SharedPreferences.setMockInitialValues({
      'ai_session_access_token': 'old',
      'ai_session_refresh_token': 'r1',
      'ai_session_expires_at': 0, // expired
    });
    var signups = 0;
    final client = MockClient((req) async {
      if (req.url.path == '/auth/v1/signup') signups++;
      if (req.url.path == '/auth/v1/token') return http.Response('', 503);
      return http.Response(ok, 200);
    });

    await expectLater(
        ask(AiAssistantService(client: client)), throwsA(isA<AiAssistantException>()));
    expect(signups, 0);
  });

  test('a rejected refresh token starts a new anonymous session', () async {
    SharedPreferences.setMockInitialValues({
      'ai_session_refresh_token': 'revoked',
      'ai_session_expires_at': 0,
    });
    final bearers = <String?>[];
    final client = MockClient((req) async {
      if (req.url.path == '/auth/v1/token') {
        return http.Response('{"error_code":"refresh_token_not_found"}', 400);
      }
      if (req.url.path == '/auth/v1/signup') {
        return http.Response(session('fresh', 'rf'), 200);
      }
      bearers.add(req.headers['Authorization']);
      return http.Response(ok, 200);
    });

    await ask(AiAssistantService(client: client));

    expect(bearers, ['Bearer fresh']);
  });
}
