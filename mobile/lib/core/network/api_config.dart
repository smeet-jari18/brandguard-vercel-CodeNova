/// Public endpoint selection only. Never add credentials to this file.
///
/// For a deployed native build, pass the actual HTTPS endpoint via API_BASE.
/// Web stays same-origin so the optional local browser demo still works.
/// Without an override native uses the device loopback for local development.
class ApiConfig {
  ApiConfig._();

  static const localBaseUrl = 'http://127.0.0.1:8000';

  static String resolveBaseUrl({
    String configuredBase = '',
    required bool isWeb,
    String? webOrigin,
  }) {
    final configured = configuredBase.trim().replaceFirst(RegExp(r'/+$'), '');
    final selected = configured.isNotEmpty
        ? configured
        : isWeb
        ? (webOrigin ?? '')
        : localBaseUrl;
    final uri = Uri.tryParse(selected);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const ApiConfigurationException();
    }
    return selected.replaceFirst(RegExp(r'/+$'), '');
  }
}

class ApiConfigurationException implements Exception {
  const ApiConfigurationException();

  @override
  String toString() =>
      'The server address is invalid. Rebuild with a valid API_BASE URL.';
}
