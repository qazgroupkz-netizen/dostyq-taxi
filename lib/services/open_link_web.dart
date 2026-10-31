import 'package:web/web.dart' as web;

bool openLink(String url) {
  web.window.open(url, '_blank');
  return true;
}
