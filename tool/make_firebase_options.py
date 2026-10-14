"""Erzeugt lib/firebase_options.dart aus google-services.json (ersetzt `flutterfire configure`).

Aufruf:  python3 tool/make_firebase_options.py google-services.json lib/firebase_options.dart
"""
import json
import sys

src, dst = sys.argv[1], sys.argv[2]
data = json.load(open(src, encoding="utf-8"))
info = data["project_info"]
client = data["client"][0]

opts = {
    "apiKey": client["api_key"][0]["current_key"],
    "appId": client["client_info"]["mobilesdk_app_id"],
    "messagingSenderId": info["project_number"],
    "projectId": info["project_id"],
    "storageBucket": info.get("storage_bucket", ""),
}

lines = "\n".join(f"    {k}: '{v}'," for k, v in opts.items())
dart = f"""// Automatisch erzeugt aus google-services.json – nicht von Hand ändern.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {{
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
{lines}
  );
}}
"""
open(dst, "w", encoding="utf-8").write(dart)
print(f"OK: {dst} für Projekt {opts['projectId']} "
      f"(Paket {client['client_info']['android_client_info']['package_name']})")
