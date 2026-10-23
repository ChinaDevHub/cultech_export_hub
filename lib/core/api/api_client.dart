import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../mock/mock_core.dart';
import '../mock/mock_server.dart';
import 'json.dart';

/// Error surfaced to the UI. [message] is the backend's `{error}` text when
/// available; network failures carry [isNetwork] so the UI can show a
/// friendly, localised message instead.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.isNetwork = false});

  final String? message;
  final int? status;
  final bool isNetwork;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => message ?? 'ApiException($status)';
}

/// Thin wrapper over Dio: base URL, bearer token, `{error}` mapping.
class ApiClient {
  ApiClient({
    required String? Function() token,
    required void Function() onUnauthorized,
    String? Function()? actAs,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: AppConfig.apiBase,
           connectTimeout: const Duration(seconds: 12),
           receiveTimeout: const Duration(seconds: 90),
           sendTimeout: const Duration(seconds: 90),
           responseType: ResponseType.json,
         ),
       ) {
    if (AppConfig.useMock) _useMock(dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = token();
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          // Coordinators work "as" one of their artisans on /artisan/* calls.
          final act = actAs?.call();
          if (act != null && act.isNotEmpty && options.path.startsWith('/artisan/')) {
            options.headers['x-act-as'] = act;
          }
          handler.next(options);
        },
        onError: (e, handler) {
          final hadToken = e.requestOptions.headers['Authorization'] != null;
          if (e.response?.statusCode == 401 && hadToken) onUnauthorized();
          handler.next(e);
        },
      ),
    );
  }

  final Dio dio;

  /// Offline mode: every request is answered by the in-app mock backend.
  static void _useMock(Dio dio) => dio.httpClientAdapter = MockAdapter(MockServer.router);

  Future<dynamic> get(String path, {Map<String, Object?>? query}) =>
      _send(() => dio.get(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, [Object? data]) =>
      _send(() => dio.post(path, data: data ?? const <String, dynamic>{}));

  Future<dynamic> delete(String path) => _send(() => dio.delete(path));

  /// Authenticated binary download (exports, CSV).
  Future<List<int>> download(String path, {Map<String, Object?>? query}) async {
    final data = await _send(
      () => dio.get<List<int>>(
        path,
        queryParameters: _clean(query),
        options: Options(responseType: ResponseType.bytes),
      ),
    );
    return (data as List).cast<int>();
  }

  Future<dynamic> put(String path, [Object? data]) =>
      _send(() => dio.put(path, data: data ?? const <String, dynamic>{}));

  Future<dynamic> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      return res.data;
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  static Map<String, Object?>? _clean(Map<String, Object?>? q) {
    if (q == null) return null;
    return Map.fromEntries(
      q.entries.where((e) => e.value != null && !(e.value is String && e.value == '')),
    );
  }

  static ApiException _map(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException(null, isNetwork: true);
    }
    final data = res.data;
    String? msg;
    if (data is Map) msg = str(data['error']) ?? str(data['message']);
    if (msg == null && data is String && data.length < 200) msg = data;
    return ApiException(msg, status: res.statusCode);
  }

  /// Builds a multipart file from a picked image (works on mobile and web).
  static Future<MultipartFile> imageFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final name = file.name.isNotEmpty ? file.name : 'photo.jpg';
    return MultipartFile.fromBytes(
      bytes,
      filename: name,
      contentType: DioMediaType.parse(_mime(name, file.mimeType)),
    );
  }

  /// Multipart file from raw bytes (file_picker results, generated files).
  static MultipartFile bytesFile(List<int> bytes, String filename, {String? mime}) =>
      MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(mime ?? _mime(filename, null)),
      );

  static String _mime(String name, String? given) {
    if (given != null && given.startsWith('image/')) return given;
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'mp4' || 'm4v' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'svg' => 'image/svg+xml',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
  }
}

/// Resolves backend media paths (`/uploads/x.jpg`, `/seed/x.svg`) to URLs.
String? mediaUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('data:') ||
      path.startsWith('blob:')) {
    return path;
  }
  return '${AppConfig.baseUrl}${path.startsWith('/') ? '' : '/'}$path';
}

bool isSvgPath(String? path) {
  if (path == null) return false;
  final clean = path.split('?').first.toLowerCase();
  return clean.endsWith('.svg') || path.startsWith('data:image/svg');
}
