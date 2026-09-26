import 'package:flutter_test/flutter_test.dart';
import 'package:weathergpt_mobile/core/constants/backend_config.dart';

void main() {
  test('dart-define wins over bundled config', () {
    expect(resolveBackendUrl(
      dartDefineUrl: ' https://weather.example.com/ ',
      dotenvUrl: 'https://other.example.com',
    ), 'https://weather.example.com');
  });
  test('quoted env URL is normalized', () {
    expect(resolveBackendUrl(dotenvUrl: '"https://weather.example.com/"'),
        'https://weather.example.com');
  });
  test('missing config never silently connects to the sibling deployment', () {
    expect(resolveBackendUrl(dartDefineUrl: '', dotenvUrl: ' '), kEmulatorBackendUrl);
  });
}
