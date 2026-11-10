import 'package:web/web.dart' as web;

String? platformPageMeta(String name) =>
    web.document.querySelector('meta[name="$name"]')?.getAttribute('content');
