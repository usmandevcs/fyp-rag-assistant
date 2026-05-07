import 'summary_download_web.dart' as web_impl;

Future<String> downloadSummaryMarkdown({
  required String markdown,
  String fileName = 'vesper_summary.md',
}) async {
  await web_impl.downloadSummaryWeb(markdown, fileName);
  return fileName;
}
