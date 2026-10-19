/// `/jobs?q=x`, or just `/jobs` when there are no parameters (a bare
/// `Uri(queryParameters: {})` would leave a dangling `?`).
String pathWithQuery(String path, Map<String, String> params) =>
    Uri(path: path, queryParameters: params.isEmpty ? null : params).toString();
