// Waits for web/firebase-sdk.js (the Firebase JS SDK loaded without inline
// scripts) before Firebase starts. Nothing to wait for on Android and iOS.
export 'firebase_sdk_loader_stub.dart'
    if (dart.library.js_interop) 'firebase_sdk_loader_web.dart';
