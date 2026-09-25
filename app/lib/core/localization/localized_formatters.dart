import 'package:intl/intl.dart';

/// Locale-aware presentation helpers for weather values.
/// Keep raw measurements in providers; format only at the UI boundary.
class LocalizedFormatters {
  const LocalizedFormatters._();

  static String number(num value, String locale) =>
      NumberFormat.decimalPattern(locale).format(value);

  static String temperature(num value, String locale, {String unit = '°'}) =>
      '${number(value, locale)}$unit';

  static String millimetres(num value, String locale) =>
      '${number(value, locale)} mm';

  static String percent(num value, String locale) =>
      NumberFormat.percentPattern(locale).format(value / 100);
}
