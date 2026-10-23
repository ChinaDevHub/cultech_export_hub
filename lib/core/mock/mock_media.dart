import 'dart:typed_data';

import 'mock_core.dart';

/// Offline media for the mock backend.
///
/// * `/seed/*.svg` and `/demo/*.svg` are illustrations drawn in code.
/// * `/uploads/*` are files the user picked while the mock is active; they
///   live in memory only.
abstract final class MockMedia {
  static final Map<String, Uint8List> _uploads = {};
  static final Map<String, String> _uploadTypes = {};
  static int _n = 0;

  /// Whether [path] is served by the mock (seed art or an in-memory upload).
  static bool handles(String? path) {
    if (path == null) return false;
    return path.startsWith('/seed/') ||
        path.startsWith('/demo/') ||
        (path.startsWith('/uploads/') && _uploads.containsKey(path));
  }

  static bool isUpload(String path) => _uploads.containsKey(path);

  static Uint8List? uploadBytes(String path) => _uploads[path];

  static String? uploadType(String path) => _uploadTypes[path];

  /// Stores an uploaded file and returns its `/uploads/…` path.
  static String store(MockFile f) {
    final dot = f.filename.lastIndexOf('.');
    final ext = dot >= 0 ? f.filename.substring(dot).toLowerCase() : '.jpg';
    final path = '/uploads/u${++_n}$ext';
    _uploads[path] = f.bytes;
    _uploadTypes[path] = f.contentType ?? 'image/jpeg';
    return path;
  }

  /// SVG source for a `/seed/*` or `/demo/*` path (falls back to a neutral
  /// tile so a typo never leaves a blank card).
  static String svg(String path) {
    final name = path.split('/').last.split('?').first;
    final b = _art[name];
    return b == null ? _tile('#EFE9DE', '') : b();
  }

  /// Every seed image path (handy for pickers / seeding).
  static List<String> get seedPaths => [
    for (final k in _art.keys.where((k) => k != 'room.svg')) '/seed/$k',
  ];

  static String _wrap(String bg, String body, {String vb = '0 0 400 400'}) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$vb"><rect width="100%" height="100%" fill="$bg"/>$body</svg>';

  static String _tile(String bg, String body) => _wrap(bg, body);

  static const _shadow =
      '<ellipse cx="200" cy="356" rx="96" ry="13" fill="#1B1A17" opacity=".08"/>';

  static final Map<String, String Function()> _art = {
    // Ceramics — blue glazed vase.
    'vase.svg': () => _wrap(
      '#E8E2D6',
      '$_shadow'
          '<path d="M164 64h72v40c0 26 64 52 64 128 0 66-35 108-100 108s-100-42-100-108c0-76 64-102 64-128z" fill="#F7F4EE" stroke="#2F6FB3" stroke-width="7"/>'
          '<path d="M118 204h164M108 246h184" stroke="#2F6FB3" stroke-width="11" stroke-linecap="round"/>'
          '<path d="M150 292c20 12 80 12 100 0" fill="none" stroke="#2F6FB3" stroke-width="6" stroke-linecap="round"/>'
          '<circle cx="200" cy="162" r="14" fill="none" stroke="#2F6FB3" stroke-width="5"/>',
    ),
    // Ceramics — terracotta jug.
    'jug-terracotta.svg': () => _wrap(
      '#F0E6D8',
      '$_shadow'
          '<path d="M170 78h60l8 36c46 22 62 66 62 112 0 58-40 100-100 100s-100-42-100-100c0-46 16-90 62-112z" fill="#C9744A" />'
          '<path d="M290 168c44-6 56 56 4 70" fill="none" stroke="#B0603B" stroke-width="16" stroke-linecap="round"/>'
          '<path d="M108 238h184M112 270h176" stroke="#8E4A2A" stroke-width="7" stroke-linecap="round"/>'
          '<path d="M164 78h72" stroke="#8E4A2A" stroke-width="9" stroke-linecap="round"/>',
    ),
    // Carpet — red medallion.
    'carpet-red.svg': () => _wrap(
      '#EFE7DA',
      '<rect x="76" y="36" width="248" height="328" rx="4" fill="#8A1C2B"/>'
          '<rect x="96" y="56" width="208" height="288" fill="none" stroke="#E9C46A" stroke-width="8"/>'
          '<rect x="110" y="70" width="180" height="260" fill="none" stroke="#E9C46A" stroke-width="2" stroke-dasharray="6 5"/>'
          '<path d="M200 112l62 88-62 88-62-88z" fill="#264653"/>'
          '<path d="M200 156l28 44-28 44-28-44z" fill="#E9C46A"/>'
          '<path d="M200 184l10 16-10 16-10-16z" fill="#8A1C2B"/>'
          '<g fill="#E9C46A"><circle cx="140" cy="96" r="6"/><circle cx="260" cy="96" r="6"/><circle cx="140" cy="304" r="6"/><circle cx="260" cy="304" r="6"/></g>'
          '<g stroke="#E9C46A" stroke-width="3"><path d="M96 36v-14M120 36v-14M144 36v-14M168 36v-14M192 36v-14M216 36v-14M240 36v-14M264 36v-14M288 36v-14M312 36v-14"/>'
          '<path d="M96 364v14M120 364v14M144 364v14M168 364v14M192 364v14M216 364v14M240 364v14M264 364v14M288 364v14M312 364v14"/></g>',
    ),
    // Carpet — navy / ivory geometric.
    'carpet-navy.svg': () => _wrap(
      '#EDE8DD',
      '<rect x="70" y="40" width="260" height="320" rx="4" fill="#1F3A5F"/>'
          '<rect x="90" y="60" width="220" height="280" fill="none" stroke="#F4EFE3" stroke-width="7"/>'
          '<g fill="#F4EFE3"><path d="M200 100l38 50-38 50-38-50z"/><path d="M200 200l38 50-38 50-38-50z"/></g>'
          '<g fill="#B5293E"><path d="M200 120l18 30-18 30-18-30z"/><path d="M200 220l18 30-18 30-18-30z"/></g>'
          '<g fill="#D9A232"><circle cx="124" cy="120" r="8"/><circle cx="276" cy="120" r="8"/><circle cx="124" cy="280" r="8"/><circle cx="276" cy="280" r="8"/><circle cx="124" cy="200" r="8"/><circle cx="276" cy="200" r="8"/></g>',
    ),
    // Copper work — hammered jug.
    'copper-jug.svg': () => _wrap(
      '#EDE6DA',
      '$_shadow'
          '<path d="M164 70h72l-6 48c52 24 76 66 76 116 0 60-44 104-106 104s-106-44-106-104c0-50 24-92 76-116z" fill="#B87333"/>'
          '<path d="M306 170c52-4 60 60 4 74" fill="none" stroke="#A0622A" stroke-width="16" stroke-linecap="round"/>'
          '<rect x="158" y="56" width="84" height="22" rx="8" fill="#A0622A"/>'
          '<path d="M112 234h176M120 272h160" stroke="#E0A96D" stroke-width="6" stroke-linecap="round"/>'
          '<g fill="#E0A96D" opacity=".7"><circle cx="160" cy="176" r="5"/><circle cx="196" cy="162" r="5"/><circle cx="232" cy="176" r="5"/><circle cx="178" cy="204" r="5"/><circle cx="216" cy="204" r="5"/></g>',
    ),
    // Copper work — engraved tray.
    'copper-tray.svg': () => _wrap(
      '#EEE7DB',
      '<ellipse cx="200" cy="214" rx="150" ry="126" fill="#A96A2E"/>'
          '<ellipse cx="200" cy="214" rx="132" ry="108" fill="#C98441"/>'
          '<ellipse cx="200" cy="214" rx="104" ry="82" fill="none" stroke="#7A4A1E" stroke-width="3" stroke-dasharray="7 5"/>'
          '<path d="M200 150l30 64-30 64-30-64z" fill="none" stroke="#7A4A1E" stroke-width="4"/>'
          '<path d="M140 214h120" stroke="#7A4A1E" stroke-width="4"/>'
          '<g fill="#7A4A1E"><circle cx="200" cy="214" r="9"/><circle cx="104" cy="214" r="5"/><circle cx="296" cy="214" r="5"/></g>',
    ),
    // Kelaghayi — silk scarf with buta motifs.
    'kelaghayi.svg': () => _wrap(
      '#F1ECE3',
      '<path d="M70 70c60-20 200-20 260 0l-14 260c-60 22-172 22-232 0z" fill="#4A1942"/>'
          '<path d="M96 96c50-14 158-14 208 0l-10 208c-50 16-138 16-188 0z" fill="none" stroke="#F1C40F" stroke-width="4"/>'
          '<g fill="#F1C40F"><path d="M200 130c-30 0-30 52 0 66 30-14 30-66 0-66z"/><path d="M150 214c-20 0-20 36 0 46 20-10 20-46 0-46z" opacity=".85"/><path d="M250 214c-20 0-20 36 0 46 20-10 20-46 0-46z" opacity=".85"/></g>'
          '<g fill="#E8A5C8"><circle cx="124" cy="120" r="7"/><circle cx="276" cy="120" r="7"/><circle cx="124" cy="290" r="7"/><circle cx="276" cy="290" r="7"/></g>',
    ),
    // Wood carving — ship.
    'ship.svg': () => _wrap(
      '#EEE8DD',
      '$_shadow'
          '<path d="M78 262h244l-32 54H110z" fill="#7B4A2A"/>'
          '<path d="M200 70v192" stroke="#5C3A1E" stroke-width="9"/>'
          '<path d="M200 82l90 150H200z" fill="#D9B48F" stroke="#7B4A2A" stroke-width="4"/>'
          '<path d="M200 106l-66 126h66z" fill="#E6C9A6" stroke="#7B4A2A" stroke-width="4"/>'
          '<path d="M96 276h208" stroke="#C9A173" stroke-width="5" stroke-linecap="round"/>'
          '<path d="M200 70l30 10-30 10z" fill="#B5293E"/>',
    ),
    // Wood carving — carved box.
    'box-carved.svg': () => _wrap(
      '#F0E9DC',
      '$_shadow'
          '<rect x="92" y="150" width="216" height="176" rx="12" fill="#8B5A33"/>'
          '<path d="M80 150h240l-14-52H94z" fill="#A3703F"/>'
          '<rect x="112" y="176" width="176" height="124" rx="6" fill="none" stroke="#D9B48F" stroke-width="4"/>'
          '<path d="M200 190l34 50-34 50-34-50z" fill="none" stroke="#D9B48F" stroke-width="5"/>'
          '<circle cx="200" cy="240" r="9" fill="#D9B48F"/>',
    ),
    // Demo room for "See it in your room".
    'room.svg': () => _wrap(
      '#EDE6D8',
      '<rect y="0" width="1200" height="560" fill="#EAE2D2"/>'
          '<rect y="560" width="1200" height="240" fill="#B58B5E"/>'
          '<path d="M0 560h1200" stroke="#9D7449" stroke-width="6"/>'
          '<g stroke="#A47B50" stroke-width="2" opacity=".6"><path d="M0 620h1200M0 690h1200M0 760h1200"/><path d="M180 560l-90 240M420 560l-60 240M660 560l-20 240M900 560l30 240M1120 560l80 240"/></g>'
          '<rect x="140" y="110" width="250" height="300" rx="8" fill="#CFE3EC" stroke="#F8F4EC" stroke-width="16"/>'
          '<path d="M265 110v300M140 260h250" stroke="#F8F4EC" stroke-width="10"/>'
          '<rect x="560" y="360" width="520" height="190" rx="26" fill="#6E7F75"/>'
          '<rect x="540" y="400" width="60" height="150" rx="24" fill="#5E6E65"/>'
          '<rect x="1040" y="400" width="60" height="150" rx="24" fill="#5E6E65"/>'
          '<rect x="590" y="330" width="460" height="86" rx="30" fill="#7D8F84"/>'
          '<rect x="600" y="560" width="440" height="14" rx="7" fill="#1B1A17" opacity=".08"/>'
          '<rect x="500" y="170" width="120" height="14" fill="#8C6A47"/><rect x="520" y="130" width="22" height="40" rx="4" fill="#C98441"/><rect x="560" y="140" width="26" height="30" rx="4" fill="#4A6D8C"/>',
      vb: '0 0 1200 800',
    ),
  };
}
