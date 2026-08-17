abstract final class ZenqivoConfig {
  static const appName = 'ZENQIVO Player';
  static const version = '0.14.0';
  static const buildNumber = '14';
  static const userAgent = 'ZENQIVO-Player/$version';

  static const apiBaseUrl = String.fromEnvironment(
    'ZENQIVO_API_URL',
    defaultValue: 'http://10.0.2.2:8787',
  );
}
