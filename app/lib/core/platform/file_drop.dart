// Files dragged from the desktop onto the page (Flutter web has no drop
// events of its own). Web only; elsewhere [fileDropListener] is null.
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'file_drop_stub.dart'
    if (dart.library.js_interop) 'file_drop_web.dart'
    as platform;

/// Stops listening.
typedef CancelFileDrops = void Function();

/// Calls [onDragOver] with the pointer position (logical pixels from the top
/// left of the page) while files are dragged over the page, and with null
/// when they leave or are dropped; [onDrop] gets the first dropped file.
typedef FileDropListener = CancelFileDrops Function({
  required void Function(Offset? position) onDragOver,
  required void Function(Offset position, String name, Uint8List bytes) onDrop,
});

/// Null where dropping files is not supported. Tests may replace it.
FileDropListener? fileDropListener = platform.platformFileDropListener;
