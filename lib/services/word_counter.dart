import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/models.dart';

/// Hört über das Mikrofon zu und zählt erkannte Wörter.
///
/// Android beendet die Spracherkennung nach Pausen oder Fehlern von selbst.
/// Darum:
///  * ein **Wächter** prüft jede halbe Sekunde, ob noch zugehört wird, und
///    startet die Erkennung sofort neu, falls nicht,
///  * jeder Abschnitt bekommt eine Nummer, damit verspätete Ergebnisse eines
///    alten Abschnitts nicht doppelt gezählt werden.
class WordCounter extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();

  bool _available = false;
  bool _running = false;
  bool _starting = false;
  String? _localeId;

  int _segment = 0; // Nummer des aktuellen Abschnitts
  int _committedWords = 0; // Wörter aus abgeschlossenen Abschnitten
  int _currentWords = 0; // Wörter im laufenden Abschnitt
  String _committedText = '';
  String _currentText = '';
  DateTime _lastStart = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _watchdog;
  String? lastError;

  int get wordCount => _committedWords + _currentWords;
  String get lastText => '$_committedText $_currentText'.trim();
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
    _committedWords = 0;
    _currentWords = 0;
    _committedText = '';
    _currentText = '';
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
    _closeSegment();
    notifyListeners();
    return wordCount;
  }

  /// Wächter: läuft die Runde, hört aber niemand zu → neu starten.
  void _ensureListening() {
    if (!_running || _starting || _speech.isListening) return;
    // Nicht öfter als alle 700 ms neu starten (sonst "error_busy").
    if (DateTime.now().difference(_lastStart) <
        const Duration(milliseconds: 700)) {
      return;
    }
    _closeSegment();
    _listen();
  }

  Future<void> _listen() async {
    if (!_running || !_available || _starting) return;
    _starting = true;
    _lastStart = DateTime.now();
    final segment = ++_segment;
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
    // Verspätetes Ergebnis eines schon abgeschlossenen Abschnitts → ignorieren.
    if (segment != _segment) return;
    _currentWords = countWords(result.recognizedWords);
    _currentText = result.recognizedWords;
    if (result.finalResult) _closeSegment();
    notifyListeners();
  }

  /// Übernimmt den laufenden Abschnitt in die Summe (genau einmal).
  void _closeSegment() {
    if (_currentWords > 0) {
      _committedWords += _currentWords;
      _committedText = '$_committedText $_currentText'.trim();
    }
    _currentWords = 0;
    _currentText = '';
    _segment++; // alles, was jetzt noch vom alten Abschnitt kommt, zählt nicht
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      if (_running) _closeSegment();
    }
    notifyListeners();
  }

  void _onError(SpeechRecognitionError error) {
    // Bei Lesepausen kommen "error_no_match"/"error_speech_timeout" – normal.
    lastError = error.errorMsg;
    if (_running) _closeSegment();
    notifyListeners();
  }

  /// Zählt Wörter in einem Text (Satzzeichen werden ignoriert).
  static int countWords(String text) {
    final cleaned =
        text.replaceAll(RegExp(r'[.,!?;:"()\[\]{}«»„“”…\-–—]'), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .length;
  }

  @override
  void dispose() {
    _running = false;
    _watchdog?.cancel();
    _speech.cancel();
    super.dispose();
  }
}
