// Loads the Firebase JS SDK from this file instead of letting FlutterFire
// inject inline <script> elements, so the Content-Security-Policy can forbid
// inline scripts. FlutterFire skips its own loading once window.firebase_core
// exists; lib/core/config/firebase_sdk_loader_web.dart waits for
// window.luzFirebaseReady before Firebase.initializeApp.
//
// Keep in sync (app/test/firebase_sdk_test.dart enforces both):
// - the version: FlutterFire's supportedFirebaseJsSdkVersion
// - one module per Firebase plugin in pubspec.yaml (window.firebase_<name>)
(function () {
  var version = '13.0.0';
  var base = 'https://www.gstatic.com/firebasejs/' + version + '/';
  window.luzFirebaseReady = (async function () {
    // firebase-app.js first: every other bundle imports it, and parallel
    // first loads race in WebKit (flutterfire#18436).
    var core = await import(base + 'firebase-app.js');
    var modules = await Promise.all([
      import(base + 'firebase-auth.js'),
      import(base + 'firebase-messaging.js'),
    ]);
    window.firebase_auth = modules[0];
    window.firebase_messaging = modules[1];
    window.firebase_core = core; // last: FlutterFire checks this one
  })();
})();
