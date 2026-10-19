import '../../features/auth/domain/auth_state.dart';
import '../data/enums.dart';

/// Pages for signed-out users only.
const _guestOnly = {'/sign-in', '/sign-up', '/forgot-password'};
const loadingPath = '/auth/loading';
const verifyPath = '/verify-email';
const chooseRolePath = '/choose-role';
const noAccessPath = '/no-access';

/// Roles allowed in each protected area (null = public).
Set<AppRole>? requiredRoles(String path) {
  bool under(String p) => path == p || path.startsWith('$p/');
  if (under('/me')) return {AppRole.candidate};
  if (under('/employer')) return {AppRole.employer, AppRole.admin};
  if (under('/admin')) return {AppRole.admin};
  if (under('/account')) return AppRole.values.toSet();
  return null;
}

String homeFor(AppRole role) => switch (role) {
  AppRole.candidate => '/me',
  AppRole.employer => '/employer',
  AppRole.admin => '/admin',
};

/// Only same-app paths are allowed as a return target (no open redirects).
String? safeReturnPath(String? from) {
  if (from == null || from.isEmpty) return null;
  if (!from.startsWith('/') || from.startsWith('//') || from.contains('\\')) {
    return null;
  }
  final path = Uri.parse(from).path;
  if (_guestOnly.contains(path) ||
      path == loadingPath ||
      path == verifyPath ||
      path == chooseRolePath) {
    return null;
  }
  return from;
}

String _withFrom(String target, Uri uri) =>
    Uri(path: target, queryParameters: {'from': uri.toString()}).toString();

/// go_router redirect: where should [uri] go for this [auth] state?
/// Returns null to stay.
String? authRedirect(AuthState auth, Uri uri) {
  final path = uri.path;
  final roles = requiredRoles(path);
  final from = safeReturnPath(uri.queryParameters['from']);

  // Waiting screen while Firebase restores the session.
  if (path == loadingPath) {
    if (auth is AuthLoading) return null;
    final target = from ?? '/';
    return authRedirect(auth, Uri.parse(target)) ?? target;
  }

  switch (auth) {
    case AuthLoading():
      return roles == null ? null : _withFrom(loadingPath, uri);

    case SignedOut():
      if (roles != null) return _withFrom('/sign-in', uri);
      if (path == verifyPath || path == chooseRolePath) return '/sign-in';
      return null;

    case NeedsRole():
      if (path == chooseRolePath) return null;
      if (roles != null || _guestOnly.contains(path) || path == verifyPath) {
        return _withFrom(chooseRolePath, uri);
      }
      return null;

    case NeedsEmailVerification():
      if (path == verifyPath) return null;
      if (roles != null ||
          _guestOnly.contains(path) ||
          path == chooseRolePath) {
        return from == null
            ? verifyPath
            : Uri(path: verifyPath, queryParameters: {'from': from}).toString();
      }
      return null;

    case SignedIn(:final role):
      if (_guestOnly.contains(path) ||
          path == verifyPath ||
          path == chooseRolePath) {
        final target = from;
        if (target != null &&
            (requiredRoles(Uri.parse(target).path)?.contains(role) ?? true)) {
          return target;
        }
        return homeFor(role);
      }
      if (roles != null && !roles.contains(role)) return noAccessPath;
      return null;
  }
}
