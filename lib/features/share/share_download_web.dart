import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:share_plus/share_plus.dart';

/// Mengunduh tiap gambar lewat anchor `download` bernama [XFile.name]. `true` kalau semuanya sudah diklik.
/// Tanpa `package:web` (bukan dependensi langsung): hanya JS interop mentah.
Future<bool> downloadShareFiles(List<XFile> files) async {
  try {
    final document = globalContext['document'] as JSObject;
    final url = globalContext['URL'] as JSObject;
    final blobType = globalContext['Blob'] as JSFunction;
    for (final (i, file) in files.indexed) {
      final bytes = await file.readAsBytes();
      final blob = blobType.callAsConstructor<JSObject>(
        [bytes.toJS].toJS,
        {'type': file.mimeType ?? 'image/png'}.jsify(),
      );
      final href = url.callMethod<JSString>('createObjectURL'.toJS, blob);
      final anchor = document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
      anchor['href'] = href;
      anchor['download'] = file.name.toJS;
      (document['body'] as JSObject).callMethod<JSAny?>('appendChild'.toJS, anchor);
      anchor.callMethod<JSAny?>('click'.toJS);
      anchor.callMethod<JSAny?>('remove'.toJS);
      // Jeda sebelum unduhan kedua supaya browser tidak menganggapnya satu ledakan; URL dilepas sesudahnya.
      if (i < files.length - 1) await Future<void>.delayed(const Duration(milliseconds: 250));
      url.callMethod<JSAny?>('revokeObjectURL'.toJS, href);
    }
    return true;
  } catch (_) {
    return false;
  }
}
