import 'package:flutter_test/flutter_test.dart';
import 'package:flowtrack/core/config/app_environment.dart';

void main() {
  group('AppEnvironment parsing tests', () {
    test('default parses as production', () {
      expect(AppEnvironment.parse(''), AppMode.production);
    });

    test('application mode defaults to production without a dart define', () {
      expect(AppEnvironment.mode, AppMode.production);
    });

    test('production parses as production', () {
      expect(AppEnvironment.parse('production'), AppMode.production);
      expect(AppEnvironment.parse('PRODUCTION '), AppMode.production);
    });

    test('demo parses as demo', () {
      expect(AppEnvironment.parse('demo'), AppMode.demo);
      expect(AppEnvironment.parse(' DEMO'), AppMode.demo);
      expect(AppEnvironment.parse('DeMo'), AppMode.demo);
    });

    test('invalid or unsupported values default to production', () {
      expect(AppEnvironment.parse('staging'), AppMode.production);
      expect(AppEnvironment.parse('development'), AppMode.production);
      expect(AppEnvironment.parse('invalid_value'), AppMode.production);
    });
  });
}
