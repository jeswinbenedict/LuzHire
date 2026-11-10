// Reads a <meta name="..." content="..."> from the hosting page. The offline
// demo server injects one to tell each port which module it is.
import 'page_meta_stub.dart'
    if (dart.library.js_interop) 'page_meta_web.dart'
    as platform;

String? pageMeta(String name) => platform.platformPageMeta(name);
