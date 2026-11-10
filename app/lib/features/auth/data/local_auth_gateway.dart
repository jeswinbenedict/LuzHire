import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/data/enums.dart';
import '../../../core/data/failures.dart';
import '../../../core/platform/local_store.dart';
import '../domain/auth_state.dart';
import 'auth_gateway.dart';

/// Sign-in for the offline demo (AUTH_PROVIDER=local): the demo server's
/// `/local-auth/*` endpoints check the password and return a signed token
/// that the local Supabase accepts, just as the cloud project accepts
/// Firebase tokens. Everything after sign-in (bootstrap, roles, RLS) is the
/// same code path as production.
class LocalAuthGateway implements AuthGateway {
  LocalAuthGateway(this._config, {http.Client? client, LocalStore? store})
    : _http = client ?? http.Client(),
      _store = store ?? localStore {
    _token = _store.read(_key);
    _current = _userFrom(_token);
  }

  /// One per app: Supabase's token callback and the providers share it.
  static LocalAuthGateway? instance;

  static const _key = 'luzhire.localAuth.token';
  static const _offline = AppFailure(
    'Google sign-in needs the internet. Use your email and password.',
    code: 'auth/offline',
  );

  final AppConfig _config;
  final http.Client _http;
  final LocalStore _store;
  final _changes = StreamController<AuthUser?>.broadcast();
  String? _token;
  AuthUser? _current;

  @override
  bool get isConfigured => true;

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> userChanges() async* {
    // Like Firebase: the restored session first, then every change.
    if (_token != null && _expiresSoon(_token!)) await _refreshQuietly();
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> signInWithEmail(String email, String password) async {
    await _session('/local-auth/sign-in', {
      'email': email.trim(),
      'password': password,
    });
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) => _session('/local-auth/sign-up', {
    'email': email.trim(),
    'password': password,
    'displayName': displayName.trim(),
  });

  @override
  Future<void> signInWithGoogle() async => throw _offline;

  /// Local accounts are created confirmed; there is no mail server offline.
  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordReset(String email) async => throw const AppFailure(
    'Password reset needs email, which the offline demo does not have. '
    'Ask the presenter to reset the demo data.',
    code: 'auth/offline',
  );

  @override
  Future<AuthUser?> refresh() async {
    if (_token == null) return null;
    await _session('/local-auth/refresh', const {}, bearer: _token);
    return _current;
  }

  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    if (_token == null) return null;
    if (forceRefresh || _expiresSoon(_token!)) await refresh();
    return _token;
  }

  /// For Supabase: only tokens that already carry `role: authenticated`
  /// (set by /api/auth/bootstrap), like the Firebase path.
  Future<String?> accessToken() async {
    final token = await idToken();
    if (token == null) return null;
    return _claims(token)['role'] == 'authenticated' ? token : null;
  }

  @override
  Future<void> signOut() async => _set(null);

  // ---------------------------------------------------------------- internals
  Future<void> _refreshQuietly() async {
    try {
      await refresh();
    } on AppFailure {
      _set(null);
    }
  }

  Future<void> _session(
    String path,
    Map<String, dynamic> payload, {
    String? bearer,
  }) async {
    final http.Response res;
    try {
      res = await _http.post(
        _config.api(path),
        headers: {
          'Content-Type': 'application/json',
          if (bearer != null) 'Authorization': 'Bearer $bearer',
        },
        body: jsonEncode(payload),
      );
    } catch (_) {
      throw const AppFailure(
        'The local LuzHire server is not running. Start it with npm run demo.',
        code: 'auth/network',
      );
    }
    final body = _decode(res.body);
    final token = body['token'];
    if (res.statusCode != 200 || token is! String) {
      final error = body['error'];
      final code = error is Map ? error['code'] as String? : null;
      if (path == '/local-auth/refresh') _set(null);
      throw mapAuthError((code ?? '').replaceFirst('auth/', ''));
    }
    _set(token);
  }

  void _set(String? token) {
    _token = token;
    _store.write(_key, token);
    _current = _userFrom(token);
    _changes.add(_current);
  }

  static AuthUser? _userFrom(String? token) {
    if (token == null) return null;
    final c = _claims(token);
    final uid = c['sub'];
    if (uid is! String) return null;
    final email = (c['email'] as String?) ?? '';
    final name = (c['name'] as String?)?.trim() ?? '';
    final role = c['app_role'] as String?;
    return AuthUser(
      uid: uid,
      email: email,
      displayName: name.isNotEmpty ? name : email.split('@').first,
      emailVerified: c['email_verified'] == true,
      usesPassword: true,
      appRole: role == null ? null : AppRole.fromDb(role),
    );
  }

  static bool _expiresSoon(String token) {
    final exp = _claims(token)['exp'];
    if (exp is! num) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return exp - now < 60;
  }

  static Map<String, dynamic> _claims(String token) {
    try {
      final part = token.split('.')[1];
      return jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(part))),
      ) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
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
