import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/models.dart';

/// Hört über das Mikrofon zu und zählt erkannte Wörter.
///
/// Android beendet die Spracherkennung nach kurzen Pausen von selbst.
/// Deshalb wird die Erkennung automatisch neu gestartet, solange die Runde
/// läuft, und die Wörter aller Abschnitte werden aufaddiert.
class WordCounter extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();

  bool _available = false;
  bool _running = false;
  String? _localeId;

  int _committedWords = 0; // Wörter aus abgeschlossenen Abschnitten
  int _currentWords = 0; // Wörter im aktuellen Abschnitt
  String _lastText = '';
  String? lastError;

  int get wordCount => _committedWords + _currentWords;
  String get lastText => _lastText;
  bool get isListening => _speech.isListening;

  /// Initialisiert die Erkennung und sucht die passende Sprache.
  /// Gibt eine Fehlermeldung zurück oder null, wenn alles bereit ist.
  Future<String?> init(ReadingLanguage language) async {
    _available = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );
    if (!_available) {
      return 'Spracherkennung ist auf diesem Gerät nicht verfügbar '
          'oder das Mikrofon wurde nicht erlaubt.';
    }

    final locales = await _speech.locales();
    final match = locales.where(
        (l) => l.localeId.toLowerCase().startsWith(language.code));
    if (match.isEmpty) {
      return 'Die Sprache "${language.label}" ist für die Spracherkennung '
          'nicht installiert. Bitte in den Android-Einstellungen unter '
          '„Google → Spracheingabe → Sprachen“ hinzufügen.';
    }
    // Bevorzugte Varianten: de_DE bzw. ar_SA / ar_SY, sonst die erste.
    const preferred = ['de_DE', 'de-DE', 'ar_SY', 'ar-SY', 'ar_SA', 'ar-SA'];
    _localeId = match
        .firstWhere((l) => preferred.contains(l.localeId),
            orElse: () => match.first)
        .localeId;
    return null;
  }

  Future<void> start() async {
    _committedWords = 0;
    _currentWords = 0;
    _lastText = '';
    lastError = null;
    _running = true;
    notifyListeners();
    await _listen();
  }

  Future<int> stop() async {
    _running = false;
    await _speech.stop();
    _commitCurrent();
    notifyListeners();
    return wordCount;
  }

  bool _starting = false;

  Future<void> _listen() async {
    if (!_running || !_available || _speech.isListening || _starting) return;
    _starting = true;
    try {
      await _doListen();
    } catch (e) {
      // z. B. wenn Status- und Fehler-Callback gleichzeitig neu starten wollen
      lastError = '$e';
    } finally {
      _starting = false;
    }
  }

  Future<void> _doListen() async {
    await _speech.listen(
      onResult: _onResult,
      localeId: _localeId,
      listenFor: const Duration(seconds: 70),
      pauseFor: const Duration(seconds: 5),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: false,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    _currentWords = countWords(result.recognizedWords);
    if (result.recognizedWords.isNotEmpty) {
      _lastText = result.recognizedWords;
    }
    if (result.finalResult) _commitCurrent();
    notifyListeners();
  }

  void _commitCurrent() {
    _committedWords += _currentWords;
    _currentWords = 0;
  }

  void _onStatus(String status) {
    // "done" / "notListening": Abschnitt beendet → weiterhören, falls die Runde läuft.
    if ((status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) &&
        _running) {
      _commitCurrent();
      Future.delayed(const Duration(milliseconds: 150), _listen);
    }
    notifyListeners();
  }

  void _onError(SpeechRecognitionError error) {
    // "error_no_match" / "error_speech_timeout" kommen bei Lesepausen vor – einfach weiter.
    lastError = error.errorMsg;
    if (_running) {
      _commitCurrent();
      Future.delayed(const Duration(milliseconds: 300), _listen);
    }
    notifyListeners();
  }

  /// Zählt Wörter in deutschem oder arabischem Text.
  /// Satzzeichen (inkl. arabischer ، ؛ ؟) werden ignoriert.
  static int countWords(String text) {
    final cleaned = text.replaceAll(
        RegExp(r'[.,!?;:"()\[\]{}«»„“”…\-–—،؛؟]'), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .length;
  }

  @override
  void dispose() {
    _running = false;
    _speech.cancel();
    super.dispose();
  }
}
