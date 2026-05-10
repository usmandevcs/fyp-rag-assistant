import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> downloadSummaryMarkdown({
  required String markdown,
  String fileName = 'vesper_summary.txt',
}) async {
  Directory? targetDirectory;

  if (Platform.isAndroid || Platform.isIOS || Platform.isFuchsia) {
    targetDirectory = await getApplicationDocumentsDirectory();
  } else {
    targetDirectory = await getDownloadsDirectory();
    targetDirectory ??= await getApplicationDocumentsDirectory();
  }

  final file = File('${targetDirectory.path}/$fileName');
  await file.writeAsString(markdown);
  return file.path;
}
