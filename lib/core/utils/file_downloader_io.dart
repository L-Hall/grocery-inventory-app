import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveTextFile({
  required String filename,
  required String content,
  String mimeType = 'text/plain',
}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');

  await file.writeAsString(content);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType, name: filename)],
    text: 'Exported from Grocery App',
  );
}
