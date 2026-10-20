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
    final body = await _post('/api/auth/bootstrap', idToken, {
      'role': role.dbValue,
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
    }, fallback: 'Could not finish setting up your account. Try again.');
    return body['refreshToken'] == true;
  }

  /// Becomes an admin if the caller's verified email is on the owner's
  /// ADMIN_EMAILS list (POST /api/auth/claim-admin).
  Future<void> claimAdmin({required String idToken}) => _post(
    '/api/auth/claim-admin',
    idToken,
    const {},
    fallback: 'Could not claim admin access. Try again.',
  );

  /// Admin: changes [uid]'s role; they are signed out everywhere.
  Future<void> changeRole({
    required String idToken,
    required String uid,
    required AppRole role,
  }) => _post('/api/admin/users/${Uri.encodeComponent(uid)}/role', idToken, {
    'role': role.dbValue,
  }, fallback: 'Could not change the role. Try again.');

  /// Admin: suspends or reactivates [uid] (Firebase sign-in and database
  /// writes follow).
  Future<void> setStatus({
    required String idToken,
    required String uid,
    required AccountStatus status,
  }) => _post('/api/admin/users/${Uri.encodeComponent(uid)}/status', idToken, {
    'status': status.dbValue,
  }, fallback: 'Could not update the account. Try again.');

  Future<Map<String, dynamic>> _post(
    String path,
    String idToken,
    Map<String, dynamic> payload, {
    required String fallback,
  }) async {
    final http.Response res;
    try {
      res = await _http.post(
        _config.api(path),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
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
      throw AppFailure(message ?? fallback, code: 'api/${res.statusCode}');
    }
    return body;
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
