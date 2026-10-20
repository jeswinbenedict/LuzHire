import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Sends crashes from release builds to POST /api/telemetry/error (an
/// admin-only log, see the admin overview). No user ids, emails or query
/// strings are sent; each distinct error is sent once per session and at
/// most [maxPerSession] in total.
class ErrorReporter {
  ErrorReporter(
    this._config, {
    http.Client? client,
    bool? enabled,
    String? Function()? currentRoute,
  }) : _http = client ?? http.Client(),
       _enabled = enabled ?? _defaultEnabled(_config),
       _route = currentRoute ?? _webRoute;

  final AppConfig _config;
  final http.Client _http;
  final bool _enabled;
  final String? Function() _route;
  final _sent = <String>{};

  static const maxPerSession = 10;
  static const release = String.fromEnvironment('APP_RELEASE');

  // Mobile builds need an absolute API_BASE_URL to reach the server.
  static bool _defaultEnabled(AppConfig c) =>
      kReleaseMode && (kIsWeb || c.apiBaseUrl.isNotEmpty);

  static String? _webRoute() => kIsWeb ? Uri.base.path : null;

  static String get _source {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  Future<void> report(Object error, StackTrace? stack) async {
    if (!_enabled || _sent.length >= maxPerSession) return;
    final message = error.toString().split('\n').first.trim();
    if (message.isEmpty || !_sent.add(message)) return;
    final route = _route();
    try {
      await _http
          .post(
            _config.api('/api/telemetry/error'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'source': _source,
              'message': message,
              if (stack != null) 'detail': stack.toString(),
              'route': ?route,
              if (release.isNotEmpty) 'release': release,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Reporting is best effort and must never throw.
    }
  }

  /// Routes framework and uncaught errors here (keeps the default output).
  void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      unawaited(report(details.exception, details.stack));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(report(error, stack));
      return false;
    };
  }
}
