import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:web/web.dart' as web;

import 'file_drop.dart';

const FileDropListener platformFileDropListener = _listen;

CancelFileDrops _listen({
  required void Function(Offset? position) onDragOver,
  required void Function(Offset position, String name, Uint8List bytes) onDrop,
}) {
  bool hasFiles(web.DragEvent e) =>
      e.dataTransfer?.types.toDart.any((t) => t.toDart == 'Files') ?? false;
  Offset at(web.DragEvent e) =>
      Offset(e.clientX.toDouble(), e.clientY.toDouble());

  // While listening, the page takes every file drop, so a file dropped next
  // to the target does not replace LuzHire with the file in the tab.
  final over = ((web.DragEvent e) {
    if (!hasFiles(e)) return;
    e.preventDefault();
    e.dataTransfer?.dropEffect = 'copy';
    onDragOver(at(e));
  }).toJS;
  final leave = ((web.DragEvent e) {
    // Leaving the window (not moving between the page's own elements).
    if (e.relatedTarget == null) onDragOver(null);
  }).toJS;
  final drop = ((web.DragEvent e) {
    if (!hasFiles(e)) return;
    e.preventDefault();
    onDragOver(null);
    final file = e.dataTransfer?.files.item(0);
    if (file == null) return;
    final position = at(e);
    file.arrayBuffer().toDart.then(
      (buffer) => onDrop(position, file.name, buffer.toDart.asUint8List()),
    );
  }).toJS;

  web.window
    ..addEventListener('dragover', over)
    ..addEventListener('dragleave', leave)
    ..addEventListener('drop', drop);
  return () => web.window
    ..removeEventListener('dragover', over)
    ..removeEventListener('dragleave', leave)
    ..removeEventListener('drop', drop);
}
