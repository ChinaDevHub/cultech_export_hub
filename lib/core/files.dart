import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import 'api/api_client.dart';

/// A file the user picked (works on mobile, desktop and web).
class PickedBytes {
  const PickedBytes(this.name, this.bytes);

  final String name;
  final Uint8List bytes;

  MultipartFile toMultipart() => ApiClient.bytesFile(bytes, name);
}

/// Opens the system file picker (logo / video uploads). Null when cancelled.
Future<PickedBytes?> pickFileBytes({FileType type = FileType.image}) async {
  try {
    final files = await FilePicker.pickFiles(type: type);
    if (files.isEmpty) return null;
    final f = files.first;
    return PickedBytes(f.name, await f.readAsBytes());
  } catch (_) {
    return null;
  }
}

/// Saves downloaded bytes (exports, CSV) via the system save dialog / browser
/// download. Returns false when the user cancelled or saving failed.
Future<bool> saveBytes(
  String fileName,
  List<int> bytes, {
  String mime = 'application/octet-stream',
}) async {
  try {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: mime,
    );
    return uri != null;
  } catch (_) {
    return false;
  }
}
