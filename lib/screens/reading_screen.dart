import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/word_counter.dart';
import 'result_screen.dart';

/// Ablauf: Vorbereitung → Countdown 3-2-1 → 60 Sekunden lesen → speichern.
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key, required this.service, required this.language});

  final FirestoreService service;
  final ReadingLanguage language;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

enum _Phase { preparing, ready, countdown, reading, saving, error }

class _ReadingScreenState extends State<ReadingScreen> {
  static const int durationSeconds = 60;

  final WordCounter _counter = WordCounter();
  _Phase _phase = _Phase.preparing;
  String? _error;
  int _countdown = 3;
  int _secondsLeft = durationSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _counter.addListener(_onCounterChanged);
    _prepare();
  }

  void _onCounterChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _prepare() async {
    final err = await _counter.init(widget.language);
    if (!mounted) return;
    setState(() {
      _error = err;
      _phase = err == null ? _Phase.ready : _Phase.error;
    });
  }

  void _startCountdown() {
    setState(() {
      _phase = _Phase.countdown;
      _countdown = 3;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        _startReading();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _startReading() async {
    setState(() {
      _phase = _Phase.reading;
      _secondsLeft = durationSeconds;
    });
    await _counter.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        _finish();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _finish() async {
    setState(() => _phase = _Phase.saving);
    // Kurz warten, damit das letzte Ergebnis der Erkennung noch ankommt.
    await Future.delayed(const Duration(milliseconds: 600));
    final words = await _counter.stop();
    try {
      final result = await widget.service
          .saveSession(words: words, language: widget.language);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ResultScreen(result: result),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = 'Speichern fehlgeschlagen ($words Wörter): $e';
      });
    }
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await _counter.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _counter.removeListener(_onCounterChanged);
    _counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = widget.language == ReadingLanguage.arabic;
    return PopScope(
      canPop: _phase != _Phase.reading && _phase != _Phase.saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.language.flag} Lesen'),
          automaticallyImplyLeading: _phase != _Phase.reading,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: switch (_phase) {
              _Phase.preparing =>
                const Center(child: CircularProgressIndicator()),
              _Phase.error => _ErrorView(message: _error ?? 'Unbekannter Fehler'),
              _Phase.ready => _ReadyView(onStart: _startCountdown),
              _Phase.countdown => Center(
                  child: Text('$_countdown',
                      style: const TextStyle(
                          fontSize: 160, fontWeight: FontWeight.bold)),
                ),
              _Phase.saving => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Zeit ist um! Ich zähle…', style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
              _Phase.reading => _ReadingView(
                  secondsLeft: _secondsLeft,
                  total: durationSeconds,
                  words: _counter.wordCount,
                  lastText: _counter.lastText,
                  listening: _counter.isListening,
                  rtl: rtl,
                  onCancel: _cancel,
                ),
            },
          ),
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('📖', textAlign: TextAlign.center, style: TextStyle(fontSize: 72)),
        const SizedBox(height: 16),
        const Text(
          'Nimm dein Buch und lies laut und deutlich vor.\n'
          'Du hast genau 1 Minute!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 40),
        SizedBox(
          height: 80,
          child: FilledButton(
            onPressed: onStart,
            child: const Text('Los geht’s!', style: TextStyle(fontSize: 26)),
          ),
        ),
      ],
    );
  }
}

class _ReadingView extends StatelessWidget {
  const _ReadingView({
    required this.secondsLeft,
    required this.total,
    required this.words,
    required this.lastText,
    required this.listening,
    required this.rtl,
    required this.onCancel,
  });

  final int secondsLeft;
  final int total;
  final int words;
  final String lastText;
  final bool listening;
  final bool rtl;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: secondsLeft / total,
                strokeWidth: 12,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
              Center(
                child: Text('$secondsLeft',
                    style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('Gelesene Wörter', style: TextStyle(fontSize: 20)),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.25, end: 1),
          duration: const Duration(milliseconds: 250),
          key: ValueKey(words),
          builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
          child: Text('$words',
              style: TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(listening ? Icons.mic : Icons.mic_none,
                color: listening ? Colors.red : Colors.grey),
            const SizedBox(width: 6),
            Text(listening ? 'Ich höre zu…' : 'Mikrofon startet neu…'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                lastText,
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
        TextButton(onPressed: onCancel, child: const Text('Abbrechen')),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zurück'),
          ),
        ],
      ),
    );
  }
}
