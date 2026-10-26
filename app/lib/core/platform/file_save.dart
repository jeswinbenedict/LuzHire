// Saves a generated file (e.g. an interview's .ics) to the user's device.
// Web only for now: Android and iOS keep their own "add to calendar" path.
import 'dart:typed_data';

import 'file_save_stub.dart'
    if (dart.library.js_interop) 'file_save_web.dart'
    as platform;

typedef FileSaver = Future<void> Function(
  String fileName,
  String mimeType,
  Uint8List bytes,
);

/// Null where saving files is not supported. Tests may replace it.
FileSaver? fileSaver = platform.platformFileSaver;
