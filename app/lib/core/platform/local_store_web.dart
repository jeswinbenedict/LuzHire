import 'package:web/web.dart' as web;

import 'local_store.dart';

LocalStore platformLocalStore() => _WebLocalStore();

class _WebLocalStore implements LocalStore {
  @override
  String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null; // Storage blocked (private mode, site data off).
    }
  }

  @override
  void write(String key, String? value) {
    try {
      if (value == null) {
        web.window.localStorage.removeItem(key);
      } else {
        web.window.localStorage.setItem(key, value);
      }
    } catch (_) {
      // Session then lasts until the tab closes; nothing else to do.
    }
  }
}
