import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/firestore_service.dart';
import '../theme.dart';
import 'auth_gate.dart';

/// Erster Start auf einem Handy: Familie neu anlegen oder per Code beitreten.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kasem Lese App')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Image.asset('assets/kasem.png', height: 200),
            const SizedBox(height: 16),
            const Text(
              'Willkommen! 👋',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Damit Punkte und Rekorde auf allen Handys gleich sind, '
              'gehört jedes Handy zu einer Familie.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 72,
              child: FilledButton.icon(
                icon: const Text('🏠', style: TextStyle(fontSize: 26)),
                label: const Text('Neue Familie anlegen',
                    style: TextStyle(fontSize: 20)),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _CreateFamilyScreen(uid: uid))),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Für das erste Handy der Familie',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              height: 72,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: KasemColors.sky),
                icon: const Text('🔑', style: TextStyle(fontSize: 26)),
                label: const Text('Mit Familien-Code beitreten',
                    style: TextStyle(fontSize: 20)),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => _JoinFamilyScreen(uid: uid))),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Den Code findest du auf dem ersten Handy im Elternbereich 🔒 → Familie',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Anlegen

class _CreateFamilyScreen extends StatefulWidget {
  const _CreateFamilyScreen({required this.uid});
  final String uid;

  @override
  State<_CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<_CreateFamilyScreen> {
  final _name = TextEditingController(text: 'Kasem');
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Bitte den Namen des Kindes eingeben');
      return;
    }
    if (_pin.text.length < 4) {
      setState(() => _error = 'Die Eltern-PIN braucht mindestens 4 Ziffern');
      return;
    }
    if (_pin.text != _pin2.text) {
      setState(() => _error = 'Die PINs stimmen nicht überein');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await DeviceService(widget.uid)
          .createFamily(pin: _pin.text, firstChildName: _name.text);
      if (!mounted) return;
      final display = '${code.substring(0, 3)}-${code.substring(3)}';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Familie angelegt! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Euer Familien-Code:'),
              const SizedBox(height: 8),
              SelectableText(display,
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 4)),
              const SizedBox(height: 8),
              const Text(
                'Gib diesen Code auf jedem weiteren Handy ein. '
                'Du findest ihn jederzeit im Elternbereich.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: display)),
              child: const Text('Kopieren'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Los geht’s'),
            ),
          ],
        ),
      );
      if (mounted) AuthGate.restart(context);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Fehler: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: AppBar(title: const Text('Neue Familie')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name des (ersten) Kindes',
              helperText: 'Weitere Kinder kannst du später im Elternbereich hinzufügen',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Eltern-PIN festlegen',
              helperText: 'Schützt den Elternbereich – gilt auf allen Handys',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin2,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'PIN wiederholen',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 20),
          SizedBox(
            height: 60,
            child: FilledButton(
              onPressed: _busy ? null : _create,
              child: _busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Familie anlegen', style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Beitreten

class _JoinFamilyScreen extends StatefulWidget {
  const _JoinFamilyScreen({required this.uid});
  final String uid;

  @override
  State<_JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<_JoinFamilyScreen> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final err = await DeviceService(widget.uid).joinFamily(_code.text);
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _busy = false;
          _error = err;
        });
        return;
      }
      AuthGate.restart(context);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Fehler: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Familie beitreten')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('🔑', textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          const Text(
            'Gib den Familien-Code vom ersten Handy ein:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.characters,
            maxLength: 7,
            style: const TextStyle(
                fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 4),
            decoration: const InputDecoration(
              hintText: 'ABC-123',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _join(),
          ),
          if (_error != null)
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16)),
          const SizedBox(height: 20),
          SizedBox(
            height: 60,
            child: FilledButton(
              onPressed: _busy ? null : _join,
              child: _busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Beitreten', style: TextStyle(fontSize: 20)),
            ),
          ),
        ],
      ),
    );
  }
}
