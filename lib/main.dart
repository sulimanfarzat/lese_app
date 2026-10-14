import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart'; // erzeugt aus google-services.json
import 'screens/auth_gate.dart';
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
