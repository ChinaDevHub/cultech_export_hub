import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// App-wide speech recogniser (the plugin is a singleton).
///
/// Dictation is appended to whichever [TextEditingController] started it, so
/// the text field always stays editable and works as the fallback. When
/// recognition is unavailable or permission is denied, [hint] is set once and
/// the user simply types.
class VoiceController extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();

  bool _initTried = false;
  bool _available = false;
  TextEditingController? _target;
  String _prefix = '';
  String? hint;

  static const _locale = 'az_AZ';

  bool get available => _available;

  bool isListeningTo(TextEditingController c) => _target == c && _stt.isListening;

  bool get isListening => _target != null;

  Future<bool> _ensureInit() async {
    if (_initTried) return _available;
    _initTried = true;
    try {
      _available = await _stt.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: false,
      );
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  Future<void> toggle(TextEditingController target) async {
    if (_target == target) {
      await stop();
      return;
    }
    if (_target != null) await stop();

    if (!await _ensureInit()) {
      hint = 'Səs tanıma bu cihazda işləmir — zəhmət olmasa yazın.';
      notifyListeners();
      return;
    }

    _target = target;
    _prefix = target.text.trimRight();
    hint = null;
    notifyListeners();
    try {
      await _stt.listen(
        onResult: (r) {
          final t = _target;
          if (t == null) return;
          final words = r.recognizedWords.trim();
          final text = [_prefix, words].where((s) => s.isNotEmpty).join(' ');
          t.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        },
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(minutes: 3),
          pauseFor: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      debugPrint('speech listen failed: $e');
      _target = null;
      hint = 'Səsi tanımaq alınmadı — zəhmət olmasa yazın.';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
    _target = null;
    notifyListeners();
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
      if (_target != null) {
        _target = null;
        notifyListeners();
      }
    }
  }

  void _onError(SpeechRecognitionError e) {
    _target = null;
    if (e.permanent) {
      hint = e.errorMsg.contains('permission')
          ? 'Mikrofona icazə verilməyib — mətni yazın.'
          : 'Səsi eşitmədik. Yenidən basın və ya mətni yazın.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }
}

final voiceProvider = Provider<VoiceController>((ref) {
  final c = VoiceController();
  ref.onDispose(c.dispose);
  return c;
});
