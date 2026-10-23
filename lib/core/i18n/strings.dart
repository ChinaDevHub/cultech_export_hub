import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'dict_buyer2.dart';
import 'dict_core.dart';
import 'dict_phase2.dart';

/// Storefront strings in 7 languages (az default · en · ru · de · tr · fr · ar).
///
/// Usage: `final t = ref.watch(tProvider); t('nav.collection')`
/// Placeholders: `t('card.want', {'n': 4})` replaces `{n}`.
///
/// Strings live in several dictionaries (one per area, so features can be
/// added independently); lookup order is the active language, then English,
/// then the key itself.
class S {
  const S(this.lang);

  final String lang;

  static const _dicts = [coreDict, buyer2Dict, phase2Dict];

  static String? _find(String lang, String key) {
    for (final d in _dicts) {
      final v = d[lang]?[key];
      if (v != null) return v;
    }
    return null;
  }

  String call(String key, [Map<String, Object?> args = const {}]) {
    var s = _find(lang, key) ?? _find('en', key) ?? key;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
    return s;
  }

  bool get isRtl => lang == 'ar';
}

final tProvider = Provider<S>((ref) => S(ref.watch(langProvider)));

const langNames = {
  'az': 'Azərbaycan',
  'en': 'English',
  'ru': 'Русский',
  'de': 'Deutsch',
  'tr': 'Türkçe',
  'fr': 'Français',
  'ar': 'العربية',
};
