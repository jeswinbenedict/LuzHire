import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web: waits for `window.luzFirebaseReady` from web/firebase-sdk.js. If it
/// is missing or failed (e.g. gstatic unreachable), Firebase reports its
/// own error when it starts.
Future<void> waitForFirebaseSdk() async {
  final ready = globalContext.getProperty<JSPromise<JSAny?>?>(
    'luzFirebaseReady'.toJS,
  );
  if (ready == null) return;
  try {
    await ready.toDart;
  } catch (_) {
    // Handled by Firebase.initializeApp.
  }
}
