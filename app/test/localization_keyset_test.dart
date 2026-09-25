import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _read(String language) => jsonDecode(
    File('assets/translations/$language.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('every locale has the same translation keys as English', () {
    final englishKeys = _read('en').keys.toSet();
    for (final locale in ['hi', 'gu', 'mr', 'ta', 'te', 'kn', 'ml', 'bn']) {
      expect(_read(locale).keys.toSet(), englishKeys, reason: '$locale.json is out of sync');
    }
  });
}
