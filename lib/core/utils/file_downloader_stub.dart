import 'dart:async';

Future<void> saveTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/plain',
}) {
  return Future.error(
    UnsupportedError('File downloads are not supported on this platform.'),
  );
}
