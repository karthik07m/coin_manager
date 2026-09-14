import 'dart:convert';

/// Optional suggestions and reporting choices, independent of account currency.
class RegionalPreferences {
  final bool indiaTemplates;
  final int financialYearStartMonth;
  final bool indiaSetupHandled;

  const RegionalPreferences({
    this.indiaTemplates = false,
    this.financialYearStartMonth = 1,
    this.indiaSetupHandled = false,
  }) : assert(financialYearStartMonth >= 1 && financialYearStartMonth <= 12);

  RegionalPreferences copyWith({
    bool? indiaTemplates,
    int? financialYearStartMonth,
    bool? indiaSetupHandled,
  }) =>
      RegionalPreferences(
        indiaTemplates: indiaTemplates ?? this.indiaTemplates,
        financialYearStartMonth:
            financialYearStartMonth ?? this.financialYearStartMonth,
        indiaSetupHandled: indiaSetupHandled ?? this.indiaSetupHandled,
      );

  String encode() => jsonEncode({
        'indiaTemplates': indiaTemplates,
        'financialYearStartMonth': financialYearStartMonth,
        'indiaSetupHandled': indiaSetupHandled,
      });

  factory RegionalPreferences.decode(String? source) {
    if (source == null) return const RegionalPreferences();
    try {
      final data = jsonDecode(source);
      if (data is! Map) return const RegionalPreferences();
      final month = data['financialYearStartMonth'];
      return RegionalPreferences(
        indiaTemplates: data['indiaTemplates'] == true,
        financialYearStartMonth:
            month is int && month >= 1 && month <= 12 ? month : 1,
        indiaSetupHandled: data['indiaSetupHandled'] == true,
      );
    } on FormatException {
      return const RegionalPreferences();
    }
  }
}
