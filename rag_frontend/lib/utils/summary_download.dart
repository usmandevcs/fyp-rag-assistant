import 'package:flutter/foundation.dart';

import 'summary_download_stub.dart'
    if (dart.library.html) 'summary_download_web_wrapper.dart'
    as platform;

Future<String> downloadSummaryMarkdown({
  required String markdown,
  String fileName = 'vesper_summary.txt',
}) async {
  if (kIsWeb) {
    await platform.downloadSummaryMarkdown(
      markdown: markdown,
      fileName: fileName,
    );
    return fileName;
  }

  return platform.downloadSummaryMarkdown(
    markdown: markdown,
    fileName: fileName,
  );
}
