import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import 'home_screen.dart';
import 'setup_screen.dart';

/// Meldet das Handy an und prüft, ob es schon zu einer Familie gehört.
///  * ja   → Startbildschirm der Familie
///  * nein → Familie anlegen oder mit Code beitreten
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  /// Zurück zum Anfang (z. B. nach „Handy von Familie abmelden“).
  static void restart(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<(String uid, String? code)> _future = _load();

  Future<(String, String?)> _load() async {
    final auth = FirebaseAuth.instance;
    // Warten, bis Firebase die gespeicherte Anmeldung wiederhergestellt hat –
    // sonst würde jedes Mal ein neues (anonymes) Konto angelegt.
    User? user = auth.currentUser ??
        await auth
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
    user ??= (await auth.signInAnonymously()).user!;
    final code = await DeviceService(user.uid).resolveFamilyCode();
    return (user.uid, code);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String, String?)>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Verbindung zu Firebase fehlgeschlagen.\n'
                      'Ist das Handy online?\n\n${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _future = _load()),
                      child: const Text('Nochmal versuchen'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final (uid, code) = snap.data!;
        if (code == null) return SetupScreen(uid: uid);
        return HomeScreen(service: FamilyService(uid: uid, code: code));
      },
    );
  }
}
