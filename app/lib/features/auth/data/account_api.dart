import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';

/// Client for the LuzHire Vercel API (privileged account operations).
class AccountApi {
  AccountApi(this._config, [http.Client? client])
    : _http = client ?? http.Client();
  final AppConfig _config;
  final http.Client _http;

  /// Sets the role claim and creates the profile (POST /api/auth/bootstrap).
  /// Returns true when the ID token must be refreshed to pick up new claims.
  Future<bool> bootstrap({
    required String idToken,
    required AppRole role,
    String? displayName,
  }) async {
    final http.Response res;
    try {
      res = await _http.post(
        _config.api('/api/auth/bootstrap'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'role': role.dbValue,
          if (displayName != null && displayName.trim().isNotEmpty)
            'displayName': displayName.trim(),
        }),
      );
    } catch (_) {
      throw const AppFailure(
        'Check your internet connection and try again.',
        code: 'api/network',
      );
    }
    final body = _decode(res.body);
    if (res.statusCode != 200) {
      final error = body['error'];
      final message = error is Map ? error['message'] as String? : null;
      throw AppFailure(
        message ?? 'Could not finish setting up your account. Try again.',
        code: 'api/${res.statusCode}',
      );
    }
    return body['refreshToken'] == true;
  }

  static Map<String, dynamic> _decode(String raw) {
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : const {};
    } catch (_) {
      return const {};
    }
  }
}
