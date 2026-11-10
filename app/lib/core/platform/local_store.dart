// A tiny string store that survives page reloads: localStorage on the web
// (separate per origin, so each demo port keeps its own session), memory
// elsewhere. Used by the offline demo's local sign-in.
import 'local_store_stub.dart'
    if (dart.library.js_interop) 'local_store_web.dart'
    as platform;

abstract class LocalStore {
  String? read(String key);
  void write(String key, String? value);
}

/// Tests may replace it.
LocalStore localStore = platform.platformLocalStore();

class MemoryLocalStore implements LocalStore {
  final _values = <String, String>{};
  @override
  String? read(String key) => _values[key];
  @override
  void write(String key, String? value) =>
      value == null ? _values.remove(key) : _values[key] = value;
}
