import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> downloadSummaryWeb(String content, String filename) async {
  // Convert the Dart string to a JS string, then wrap in a JSArray for the Blob
  final blob = web.Blob(
    [content.toJS].toJS, 
    web.BlobPropertyBag(type: 'text/markdown'),
  );
  
  final url = web.URL.createObjectURL(blob);
  
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
    
  // Append to body, click, and cleanup
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  
  web.URL.revokeObjectURL(url);
}
