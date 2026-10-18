import 'package:supabase_flutter/supabase_flutter.dart';

/// A user-presentable error. Repositories throw this instead of raw
/// Postgrest/Storage exceptions (SRS 7.14: meaningful error messages).
class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => 'AppFailure($code): $message';
}

/// Maps database errors to friendly messages. Our triggers already raise
/// readable messages for business rules (SQLSTATE 23514), so those pass through.
AppFailure mapDbError(Object error) {
  if (error is AppFailure) return error;
  if (error is PostgrestException) {
    return switch (error.code) {
      '23505' => AppFailure(
        'This already exists — for example, you have already applied.',
        code: error.code,
      ),
      '23514' => AppFailure(error.message, code: error.code),
      '42501' => AppFailure(
        "You don't have permission to do that.",
        code: error.code,
      ),
      'PGRST301' || '401' => AppFailure(
        'Your session expired. Please sign in again.',
        code: error.code,
      ),
      _ => AppFailure(
        'Something went wrong. Please try again.',
        code: error.code,
      ),
    };
  }
  if (error is StorageException) {
    return AppFailure(
      error.statusCode == '413'
          ? 'That file is too large.'
          : 'Upload failed. Please try again.',
      code: error.statusCode,
    );
  }
  return const AppFailure('Check your internet connection and try again.');
}

/// Runs [action] and converts any failure with [mapDbError].
Future<T> guardDb<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    throw mapDbError(e);
  }
}
