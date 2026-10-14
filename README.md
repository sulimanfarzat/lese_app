# Lese-Trainer 📖

Flutter-App für Android: Das Kind liest 1 Minute laut vor, die App zählt die
Wörter per Spracherkennung (Deutsch oder Arabisch), speichert jede Runde in
Firebase und schaltet Geschenke frei.

## Funktionen

- **1-Minuten-Lesen** mit Countdown 3-2-1, großem Live-Wortzähler und Timer
- **Spracherkennung** Deutsch 🇩🇪 und Arabisch (RTL-Anzeige), startet nach Lesepausen automatisch neu
- **Firebase-Speicherung**: jede Runde als Record (`words`, `points`, `language`, `isRecord`, `createdAt`)
- **Punkte**: 1 Punkt pro Wort, +20 Bonus bei neuem Rekord
- **Zwei Geschenk-Arten** (von den Eltern festgelegt):
  - ⭐ *Punkte-Geschenk* – kostet Punkte, die beim Übergeben abgezogen werden
  - 🏆 *Rekord-Geschenk* – einmalig, sobald X Wörter in 1 Minute erreicht sind
- **Elternbereich mit PIN**: Geschenke anlegen/übergeben, Verlauf mit Durchschnitt, Fehlmessungen löschen, Name ändern

## Einrichtung (ca. 15 Minuten)

Voraussetzungen: Flutter SDK (≥ 3.22), Android Studio, ein Google-Konto.

```bash
# 1. Android-Gerüst erzeugen (im Ordner lese_app)
flutter create --platforms=android --org io.farzat .

# 2. Manifest ersetzen
cp android_setup/AndroidManifest.xml android/app/src/main/AndroidManifest.xml

# 3. Pakete laden
flutter pub get
```

**4. minSdk setzen** – in `android/app/build.gradle` (bzw. `build.gradle.kts`):
```
minSdk = 23
```

**5. Firebase-Projekt anlegen** auf <https://console.firebase.google.com>:
- *Authentication* → Anmeldemethode **Anonym** aktivieren
- *Firestore Database* → Datenbank erstellen (Region `europe-west3` Frankfurt)
- *Firestore → Regeln* → Inhalt von `firestore.rules` einfügen und veröffentlichen

**6. App mit Firebase verbinden**
```bash
dart pub global activate flutterfire_cli
flutterfire configure      # Projekt wählen, Plattform: android
```
Das erzeugt `lib/firebase_options.dart` und `android/app/google-services.json`.

**7. Starten**
```bash
flutter run          # Handy per USB, USB-Debugging an
flutter build apk    # fertige APK unter build/app/outputs/flutter-apk/
```

## Auf dem Handy des Kindes

- Beim ersten Lesen Mikrofon-Zugriff erlauben.
- **Arabisch** muss in der Spracherkennung installiert sein:
  Einstellungen → Google → Spracheingabe (bzw. „Google Sprachdienste“) → Sprachen → Arabisch hinzufügen.
  Für Offline-Nutzung zusätzlich das Offline-Sprachpaket laden.
- Beim ersten Öffnen des Elternbereichs (🔒 oben rechts) wird die PIN festgelegt.

## Datenstruktur in Firestore

```
users/{uid}
  childName, pointsTotal, pointsSpent, bestWpm, pinHash, language
  sessions/{id}   words, points, language, isRecord, durationSeconds, createdAt
  rewards/{id}    title, emoji, type (points|record), threshold, redeemed, redeemedAt
```

## Hinweise

- Die Spracherkennung zählt die Wörter, die sie *versteht*. Bei Kindern mit
  noch stockendem Lesen kann der Wert etwas niedriger sein als die tatsächlich
  gelesenen Wörter – Fehlmessungen lassen sich im Verlauf löschen.
- Der Login ist anonym und an die App-Installation gebunden. Wird die App
  deinstalliert, ist ein neues Profil nötig (die alten Daten bleiben in der
  Firebase-Konsole sichtbar).
