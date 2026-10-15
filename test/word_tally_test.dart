import 'package:flutter_test/flutter_test.dart';
import 'package:lese_app/services/word_tally.dart';

/// Simuliert Teilergebnisse der Spracherkennung (wachsender Text).
void speak(WordTally t, String sentence, {bool finalAtEnd = false}) {
  final words = sentence.split(' ');
  for (var i = 1; i <= words.length; i++) {
    t.addResult(words.take(i).join(' '),
        isFinal: finalAtEnd && i == words.length, segment: t.segment);
  }
}

void main() {
  test('Fall aus dem Screenshot: neuer Satz ohne Bescheid → nichts geht verloren', () {
    final t = WordTally()..reset();
    speak(t, 'hallo ich bin Kassel hallo ich bin Kassel ich bin 35'); // 11 Wörter
    expect(t.total, 11);
    // Erkennung beginnt intern neu – Teilergebnis enthält nur noch den neuen Satz
    speak(t, 'warum zählst du von Anfang immer'); // 6 Wörter
    expect(t.total, 17);
    expect(t.text, contains('hallo ich bin Kassel'));
    expect(t.text, contains('warum zählst du'));
  });

  test('Verlängerung desselben Satzes wird nicht doppelt gezählt', () {
    final t = WordTally()..reset();
    t.addResult('der Hund', isFinal: false, segment: t.segment);
    t.addResult('der Hund läuft', isFinal: false, segment: t.segment);
    t.addResult('der Hund läuft schnell', isFinal: true, segment: t.segment);
    expect(t.total, 4);
  });

  test('Korrektur des ersten Wortes bleibt derselbe Satz', () {
    final t = WordTally()..reset();
    t.addResult('Halo ich bin', isFinal: false, segment: t.segment);
    t.addResult('Hallo ich bin Kasem', isFinal: false, segment: t.segment);
    expect(t.total, 4);
  });

  test('Erkennung wird von Android beendet und neu gestartet', () {
    final t = WordTally()..reset();
    speak(t, 'es war einmal ein kleiner Drache');
    t.closeSegment(); // Status "done"
    speak(t, 'der wohnte in einer Höhle', finalAtEnd: true);
    expect(t.total, 11);
  });

  test('Verspätetes Endergebnis mit mehr Wörtern wird nachgetragen, nicht doppelt', () {
    final t = WordTally()..reset();
    final s = t.segment;
    t.addResult('es war einmal', isFinal: false, segment: s);
    t.closeSegment(); // Status kommt vor dem Endergebnis
    t.addResult('es war einmal ein Drache', isFinal: true, segment: s);
    expect(t.total, 5);
    t.addResult('es war einmal ein Drache', isFinal: true, segment: s);
    expect(t.total, 5);
  });

  test('Zahl wird nie kleiner, auch wenn die Erkennung Wörter zusammenfasst', () {
    final t = WordTally()..reset();
    t.addResult('Fuß ball spielen wir gern', isFinal: false, segment: t.segment);
    expect(t.total, 5);
    t.addResult('Fußball spielen wir gern', isFinal: false, segment: t.segment);
    expect(t.total, 5);
  });

  test('Neuer Satz, der mit einem schon gesagten Wort beginnt', () {
    final t = WordTally()..reset();
    speak(t, 'der Hund läuft schnell über die Wiese'); // 7
    t.addResult('der', isFinal: false, segment: t.segment); // Neustart
    t.addResult('der Ball', isFinal: false, segment: t.segment);
    expect(t.total, 9);
  });

  test('Leeres Teilergebnis löscht nichts', () {
    final t = WordTally()..reset();
    speak(t, 'eins zwei drei');
    t.addResult('', isFinal: false, segment: t.segment);
    expect(t.total, 3);
  });

  test('Satzzeichen zählen nicht als Wörter', () {
    expect(WordTally.splitWords('Hallo, ich bin – Kasem!').length, 4);
  });
}
