// lib/localization.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  late final Map<String, String> _strings;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  Future<bool> load() async {
    final code = locale.languageCode;
    final path = 'assets/l10n/app_$code.arb';
    try {
      final jsonStr = await rootBundle.loadString(path);
      final Map<String, dynamic> data = json.decode(jsonStr);
      _strings = <String, String>{};
      data.forEach((k, v) {
        if (!k.startsWith('@')) {
          _strings[k] = (v ?? '').toString();
        }
      });
      return true;
    } catch (e) {
      // fallback to English
      if (code != 'en') {
        final en = AppLocalizations(const Locale('en'));
        final ok = await en.load();
        if (ok) {
          _strings = en._strings;
          return true;
        }
      }
      _strings = {};
      return false;
    }
  }

  /// Get localized value for key; fallback if provided
  String t(String key, [String? fallback]) => _strings[key] ?? fallback ?? key;

  // ---------------------------
  // AI Checkup + Language keys
  // ---------------------------
  String get ai_health_checkup => t('ai_health_checkup');
  String get select_language => t('select_language');
  String get describe_symptoms => t('describe_symptoms');
  String get speak => t('speak');
  String get stop => t('stop');
  String get analyze => t('analyze');
  String get ai_diagnosis => t('ai_diagnosis');
  String get analyzing => t('analyzing');

  // Languages
  String get english => t('english');
  String get hindi => t('hindi');
  String get kannada => t('kannada');
  String get marathi => t('marathi');

  // Main app labels
  String get dashboard => t('dashboard');
  String get reminders => t('reminders');
  String get profile => t('profile');
  String get settings => t('settings');
  String get smartwatch => t('smartwatch');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'hi', 'mr', 'kn'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
