import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/models.dart';
import 'word_tally.dart';

/// Hört über das Mikrofon zu und zählt erkannte Wörter.
///
///  * Ein **Wächter** prüft jede halbe Sekunde, ob noch zugehört wird, und
///    startet die Erkennung sofort neu, falls Android sie beendet hat.
///  * Die eigentliche Zählung macht [WordTally]: Sie erkennt, wenn die
///    Erkennung intern einen neuen Satz beginnt, und verliert dabei keine
///    Wörter. Die angezeigte Zahl wird nie kleiner.
class WordCounter extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  final WordTally _tally = WordTally();

  bool _available = false;
  bool _running = false;
  bool _starting = false;
  String? _localeId;
  DateTime _lastStart = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _watchdog;
  String? lastError;

  int get wordCount => _tally.total;
  String get lastText => _tally.text;
  bool get isListening => _speech.isListening;

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
    final match = locales
        .where((l) => l.localeId.toLowerCase().startsWith(language.code));
    if (match.isEmpty) {
      return 'Die Sprache "${language.label}" ist für die Spracherkennung '
          'nicht installiert. Bitte in den Android-Einstellungen unter '
          '„Google → Spracheingabe → Sprachen“ hinzufügen.';
    }
    const preferred = ['de_DE', 'de-DE'];
    _localeId = match
        .firstWhere((l) => preferred.contains(l.localeId),
            orElse: () => match.first)
        .localeId;
    return null;
  }

  Future<void> start() async {
    _tally.reset();
    lastError = null;
    _running = true;
    notifyListeners();
    _watchdog?.cancel();
    _watchdog = Timer.periodic(
        const Duration(milliseconds: 500), (_) => _ensureListening());
    await _listen();
  }

  Future<int> stop() async {
    _running = false;
    _watchdog?.cancel();
    _watchdog = null;
    await _speech.stop();
    // Kurz auf das letzte Ergebnis warten, dann abschließen.
    await Future.delayed(const Duration(milliseconds: 400));
    _tally.closeSegment();
    notifyListeners();
    return _tally.total;
  }

  /// Wächter: läuft die Runde, hört aber niemand zu → neu starten.
  void _ensureListening() {
    if (!_running || _starting || _speech.isListening) return;
    // Nicht öfter als alle 700 ms neu starten (sonst "error_busy").
    if (DateTime.now().difference(_lastStart) <
        const Duration(milliseconds: 700)) {
      return;
    }
    _tally.closeSegment();
    _listen();
  }

  Future<void> _listen() async {
    if (!_running || !_available || _starting) return;
    _starting = true;
    _lastStart = DateTime.now();
    final segment = _tally.segment;
    try {
      if (_speech.isListening) await _speech.cancel();
      await _speech.listen(
        onResult: (r) => _onResult(r, segment),
        localeId: _localeId,
        listenFor: const Duration(seconds: 70),
        pauseFor: const Duration(seconds: 10),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
        ),
      );
    } catch (e) {
      lastError = '$e';
    } finally {
      _starting = false;
    }
  }

  void _onResult(SpeechRecognitionResult result, int segment) {
    _tally.addResult(result.recognizedWords,
        isFinal: result.finalResult, segment: segment);
    notifyListeners();
  }

  void _onStatus(String status) {
    if ((status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) &&
        _running) {
      _tally.closeSegment();
    }
    notifyListeners();
  }

  void _onError(SpeechRecognitionError error) {
    // Bei Lesepausen kommen "error_no_match"/"error_speech_timeout" – normal.
    lastError = error.errorMsg;
    if (_running) _tally.closeSegment();
    notifyListeners();
  }

  /// Zählt Wörter in einem Text (Satzzeichen werden ignoriert).
  static int countWords(String text) => WordTally.splitWords(text).length;

  @override
  void dispose() {
    _running = false;
    _watchdog?.cancel();
    _speech.cancel();
    super.dispose();
  }
}
