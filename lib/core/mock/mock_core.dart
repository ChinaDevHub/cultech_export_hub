import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'mock_db.dart';

/// Thrown by handlers → becomes `{ "error": message }` with [status].
class MockError implements Exception {
  MockError(this.status, this.message);

  factory MockError.badRequest([String m = 'Invalid request']) => MockError(400, m);
  factory MockError.unauthorized([String m = 'Please sign in']) => MockError(401, m);
  factory MockError.forbidden([String m = 'Not allowed']) => MockError(403, m);
  factory MockError.notFound([String m = 'Not found']) => MockError(404, m);

  final int status;
  final String message;
}

/// A file received in a multipart request (already read into memory).
class MockFile {
  MockFile({required this.field, required this.filename, required this.bytes, this.contentType});

  final String field;
  final String filename;
  final Uint8List bytes;
  final String? contentType;

  bool get isImage => (contentType ?? '').startsWith('image/');
  bool get isVideo => (contentType ?? '').startsWith('video/');
}

/// Return this from a handler to send raw bytes (CSV / JSON exports).
class MockBytes {
  MockBytes(this.bytes, {this.contentType = 'application/octet-stream'});

  final List<int> bytes;
  final String contentType;
}

/// One incoming request, decoded.
class MockRequest {
  MockRequest({
    required this.method,
    required this.path,
    required this.params,
    required this.query,
    required this.body,
    required this.files,
    required this.headers,
  });

  final String method;

  /// Path without the `/api` prefix, e.g. `/products/p1`.
  final String path;

  /// `:id` style path parameters.
  final Map<String, String> params;
  final Map<String, String> query;

  /// JSON body, or the text fields of a multipart body.
  final Map<String, dynamic> body;
  final List<MockFile> files;
  final Map<String, String> headers;

  String? get bearer {
    final h = headers['authorization'];
    if (h == null || !h.toLowerCase().startsWith('bearer ')) return null;
    return h.substring(7).trim();
  }

  /// The signed-in user record (see [MockDb.users]) or null.
  Map<String, dynamic>? get user => MockDb.instance.userForToken(bearer);

  Map<String, dynamic> requireUser([List<String>? roles]) {
    final u = user;
    if (u == null) throw MockError.unauthorized();
    if (roles != null && !roles.contains(u['role'])) throw MockError.forbidden();
    return u;
  }

  /// For `/artisan/*`: the artisan record the call is about — the artisan
  /// themself, or (coordinators) the artisan named by `x-act-as`.
  Map<String, dynamic> requireArtisan() {
    final u = requireUser(['artisan', 'coordinator']);
    final db = MockDb.instance;
    if (u['role'] == 'artisan') {
      final a = db.artisanById('${u['artisanId'] ?? u['id']}');
      if (a == null) throw MockError.notFound('Artisan not found');
      return a;
    }
    final id = headers['x-act-as'];
    final a = id == null ? null : db.artisanById(id);
    if (a == null) throw MockError.badRequest('Choose an artisan to work for');
    if (a['coordinatorId'] != u['id']) throw MockError.forbidden('Not your artisan');
    return a;
  }

  // ── tolerant body readers ──
  String? str(String key) {
    final v = body[key];
    if (v == null) return null;
    final s = '$v'.trim();
    return s.isEmpty ? null : s;
  }

  double? number(String key) {
    final v = body[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  int? integer(String key) => number(key)?.round();

  bool? flag(String key) {
    final v = body[key];
    if (v is bool) return v;
    if (v is String) return v == 'true' || v == '1';
    if (v is num) return v != 0;
    return null;
  }

  List<dynamic> list(String key) {
    final v = body[key] ?? body['$key[]'];
    if (v is List) return v;
    return v == null ? const [] : [v];
  }

  /// Files uploaded under [field] (`images` and `images[]` are the same).
  List<MockFile> filesOf(String field) =>
      files.where((f) => f.field == field || f.field == '$field[]').toList();

  MockFile? file(String field) {
    final l = filesOf(field);
    return l.isEmpty ? null : l.first;
  }
}

typedef MockHandler = FutureOr<Object?> Function(MockRequest req);

class _Route {
  _Route(this.method, this.pattern, this.handler, this.latency)
    : segments = pattern.split('/').where((s) => s.isNotEmpty).toList();

  final String method;
  final String pattern;
  final List<String> segments;
  final MockHandler handler;
  final int latency;

  Map<String, String>? match(String method, List<String> parts) {
    if (method != this.method || parts.length != segments.length) return null;
    final params = <String, String>{};
    for (var i = 0; i < parts.length; i++) {
      final s = segments[i];
      if (s.startsWith(':')) {
        params[s.substring(1)] = Uri.decodeComponent(parts[i]);
      } else if (s != parts[i]) {
        return null;
      }
    }
    return params;
  }
}

/// Minimal path router. Register specific routes before generic ones.
class MockRouter {
  final _routes = <_Route>[];

  /// [ms] simulates network latency (AI steps use a few seconds).
  void get(String p, MockHandler h, {int ms = 180}) => _routes.add(_Route('GET', p, h, ms));
  void post(String p, MockHandler h, {int ms = 260}) => _routes.add(_Route('POST', p, h, ms));
  void put(String p, MockHandler h, {int ms = 260}) => _routes.add(_Route('PUT', p, h, ms));
  void delete(String p, MockHandler h, {int ms = 200}) => _routes.add(_Route('DELETE', p, h, ms));

  /// Finds the route and decodes the request; null when nothing matches.
  (_Route, Map<String, String>)? find(String method, String path) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    for (final r in _routes) {
      final p = r.match(method, parts);
      if (p != null) return (r, p);
    }
    return null;
  }
}

/// Dio adapter that answers every request from the in-app [MockRouter] —
/// the whole app runs offline with no backend.
class MockAdapter implements HttpClientAdapter {
  MockAdapter(this.router);

  final MockRouter router;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var path = options.uri.path;
    if (path.startsWith('/api')) path = path.substring(4);
    if (path.isEmpty) path = '/';

    final headers = <String, String>{
      for (final e in options.headers.entries) e.key.toLowerCase(): '${e.value}',
    };

    final raw = requestStream == null ? Uint8List(0) : await _readAll(requestStream);
    final decoded = _decodeBody(raw, headers['content-type'] ?? '');
    final route = router.find(options.method.toUpperCase(), path);
    if (route == null) {
      return _json(404, {'error': 'Not found: ${options.method} $path'});
    }
    final (r, params) = route;
    final req = MockRequest(
      method: options.method.toUpperCase(),
      path: path,
      params: params,
      query: {for (final e in options.uri.queryParameters.entries) e.key: e.value},
      body: decoded.fields,
      files: decoded.files,
      headers: headers,
    );

    await Future<void>.delayed(Duration(milliseconds: r.latency));
    try {
      final result = await r.handler(req);
      if (result is MockBytes) {
        return ResponseBody.fromBytes(
          result.bytes,
          200,
          headers: {
            Headers.contentTypeHeader: [result.contentType],
          },
        );
      }
      return _json(200, result ?? {'ok': true});
    } on MockError catch (e) {
      return _json(e.status, {'error': e.message});
    } catch (e, st) {
      // A bug in a handler must never crash the app: surface as a 500.
      // ignore: avoid_print
      print('MockAdapter error on ${options.method} $path: $e\n$st');
      return _json(500, {'error': 'Mock server error: $e'});
    }
  }

  ResponseBody _json(int status, Object? data) => ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}

  static Future<Uint8List> _readAll(Stream<Uint8List> s) async {
    final b = BytesBuilder(copy: false);
    await for (final c in s) {
      b.add(c);
    }
    return b.takeBytes();
  }

  static ({Map<String, dynamic> fields, List<MockFile> files}) _decodeBody(
    Uint8List raw,
    String contentType,
  ) {
    if (raw.isEmpty) return (fields: <String, dynamic>{}, files: <MockFile>[]);
    final ct = contentType.toLowerCase();
    if (ct.startsWith('multipart/form-data')) {
      final m = RegExp(
        'boundary=(?:"([^"]+)"|([^;]+))',
        caseSensitive: false,
      ).firstMatch(contentType);
      final boundary = m?.group(1) ?? m?.group(2);
      if (boundary == null) return (fields: <String, dynamic>{}, files: <MockFile>[]);
      return _parseMultipart(raw, boundary.trim());
    }
    try {
      final j = jsonDecode(utf8.decode(raw));
      if (j is Map) {
        return (fields: j.map((k, v) => MapEntry('$k', v)), files: <MockFile>[]);
      }
    } catch (_) {}
    return (fields: <String, dynamic>{}, files: <MockFile>[]);
  }

  static int _indexOf(Uint8List data, List<int> pattern, int start) {
    final n = pattern.length;
    outer:
    for (var i = start; i <= data.length - n; i++) {
      for (var j = 0; j < n; j++) {
        if (data[i + j] != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  static ({Map<String, dynamic> fields, List<MockFile> files}) _parseMultipart(
    Uint8List data,
    String boundary,
  ) {
    final fields = <String, dynamic>{};
    final files = <MockFile>[];
    final delim = ascii.encode('--$boundary');
    final headerEnd = ascii.encode('\r\n\r\n');
    var pos = _indexOf(data, delim, 0);
    while (pos != -1) {
      final partStart = pos + delim.length;
      // "--" right after the boundary marks the end.
      if (partStart + 1 < data.length && data[partStart] == 0x2d && data[partStart + 1] == 0x2d) {
        break;
      }
      final next = _indexOf(data, delim, partStart);
      if (next == -1) break;
      // Part = \r\n headers \r\n\r\n body \r\n
      final hStart = partStart + 2;
      final hEnd = _indexOf(data, headerEnd, hStart);
      if (hEnd != -1 && hEnd < next) {
        final head = latin1.decode(data.sublist(hStart, hEnd));
        final bodyBytes = data.sublist(hEnd + 4, next - 2 < hEnd + 4 ? hEnd + 4 : next - 2);
        final name = RegExp('name="([^"]*)"', caseSensitive: false).firstMatch(head)?.group(1);
        final filename = RegExp(
          'filename="([^"]*)"',
          caseSensitive: false,
        ).firstMatch(head)?.group(1);
        final ctype = RegExp(
          r'content-type:\s*([^\r\n]+)',
          caseSensitive: false,
        ).firstMatch(head)?.group(1)?.trim();
        if (name != null) {
          if (filename != null) {
            files.add(
              MockFile(
                field: name,
                filename: filename,
                bytes: Uint8List.fromList(bodyBytes),
                contentType: ctype,
              ),
            );
          } else {
            final value = utf8.decode(bodyBytes, allowMalformed: true);
            final key = name.endsWith('[]') ? name.substring(0, name.length - 2) : name;
            final existing = fields[key];
            if (existing == null) {
              fields[key] = value;
            } else if (existing is List) {
              existing.add(value);
            } else {
              fields[key] = [existing, value];
            }
          }
        }
      }
      pos = next;
    }
    return (fields: fields, files: files);
  }
}
