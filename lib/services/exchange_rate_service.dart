import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Fetches and caches live foreign-exchange rates so account balances in
/// different currencies can be converted to the user's base currency.
///
/// Uses open.er-api.com (free, no API key, 160+ currencies). Rates for a base
/// are cached in SharedPreferences and refreshed at most once every 6 hours.
class ExchangeRateService {
  static final ExchangeRateService _instance = ExchangeRateService._internal();
  factory ExchangeRateService() => _instance;
  ExchangeRateService._internal();

  static const Duration _maxAge = Duration(hours: 6);

  // base -> { currencyCode: rate } (1 base = rate * currency)
  final Map<String, Map<String, double>> _memory = {};

  /// Synchronous access to already-loaded rates for [base], or null.
  Map<String, double>? cachedRatesFor(String base) => _memory[base];

  /// Returns rates for [base], from memory/disk if fresh, otherwise fetched.
  /// Never throws — returns an empty map on failure (callers then treat
  /// conversion as 1:1).
  Future<Map<String, double>> getRates(String base) async {
    if (_memory.containsKey(base)) return _memory[base]!;

    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString('fx_rates_$base');
    final cachedAt = prefs.getInt('fx_rates_at_$base') ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - cachedAt;

    if (cachedJson != null && age < _maxAge.inMilliseconds) {
      final map = _decode(cachedJson);
      if (map.isNotEmpty) {
        _memory[base] = map;
        return map;
      }
    }

    final fetched = await _fetch(base);
    if (fetched.isNotEmpty) {
      _memory[base] = fetched;
      await prefs.setString('fx_rates_$base', jsonEncode(fetched));
      await prefs.setInt(
          'fx_rates_at_$base', DateTime.now().millisecondsSinceEpoch);
      return fetched;
    }

    // Fetch failed: fall back to any stale cache we have.
    if (cachedJson != null) {
      final map = _decode(cachedJson);
      if (map.isNotEmpty) {
        _memory[base] = map;
        return map;
      }
    }
    return const {};
  }

  Future<Map<String, double>> _fetch(String base) async {
    try {
      final uri = Uri.parse('https://open.er-api.com/v6/latest/$base');
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const {};
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['result'] != 'success') return const {};
      final rates = body['rates'] as Map<String, dynamic>?;
      if (rates == null) return const {};
      return rates.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (e) {
      debugPrint('ExchangeRateService fetch failed: $e');
      return const {};
    }
  }

  Map<String, double> _decode(String json) {
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return const {};
    }
  }

  /// Converts [amount] in [from] currency into [base] using [rates]
  /// (keyed base -> currency). Returns [amount] unchanged if no rate is known.
  static double toBase(
    double amount,
    String from,
    String base,
    Map<String, double> rates,
  ) {
    if (from.isEmpty || from == base) return amount;
    final r = rates[from];
    if (r == null || r == 0) return amount;
    return amount / r;
  }
}
