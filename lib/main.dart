import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart'; // wird von `flutterfire configure` erzeugt
import 'screens/home_screen.dart';
import 'services/firestore_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LeseApp());
}

class LeseApp extends StatelessWidget {
  const LeseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasem Lese App',
      debugShowCheckedModeBanner: false,
      theme: kasemTheme(),
      home: const AuthGate(),
    );
  }
}

/// Meldet das Gerät anonym bei Firebase an und legt das Profil an.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<FirestoreService> _future = _signIn();

  Future<FirestoreService> _signIn() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
    final service = FirestoreService(user.uid);
    await service.ensureProfile();
    return service;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirestoreService>(
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
                      'Verbindung zu Firebase fehlgeschlagen.\n${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _future = _signIn()),
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
        return HomeScreen(service: snap.data!);
      },
    );
  }
}
