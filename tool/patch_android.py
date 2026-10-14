"""Passt das von `flutter create` erzeugte Android-Projekt an:
 - minSdk 23 (Firebase)
 - applicationId = Paketname aus google-services.json
 - festen Signaturschlüssel (android_setup/kasem-release.jks) für Release-Builds,
   damit neue Versionen als Update installiert werden können.

Aufruf (im Projektordner):  python3 tool/patch_android.py
"""
import json
import pathlib
import re

pkg = json.load(open("google-services.json"))["client"][0]["client_info"][
    "android_client_info"]["package_name"]

kts = pathlib.Path("android/app/build.gradle.kts")
groovy = pathlib.Path("android/app/build.gradle")

if kts.exists():
    s = kts.read_text()
    s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", s)
    s = re.sub(r'applicationId\s*=\s*"[^"]+"', f'applicationId = "{pkg}"', s)
    if "keystoreProperties" not in s:
        s = ("import java.util.Properties\nimport java.io.FileInputStream\n\n" + s)
        s = s.replace("android {", """val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("../android_setup/key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {""", 1)
        s = re.sub(r"(\n\s*)buildTypes\s*\{", r"""\1signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
\1buildTypes {""", s, count=1)
        s = s.replace('signingConfig = signingConfigs.getByName("debug")',
                      'signingConfig = signingConfigs.getByName("release")')
    kts.write_text(s)
    target = kts
elif groovy.exists():
    s = groovy.read_text()
    s = re.sub(r"minSdk(Version)?\s*=?\s*flutter\.minSdkVersion", "minSdk = 23", s)
    s = re.sub(r'applicationId\s*=?\s*"[^"]+"', f'applicationId = "{pkg}"', s)
    if "keystoreProperties" not in s:
        s = s.replace("android {", """def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('../android_setup/key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {""", 1)
        s = re.sub(r"(\n\s*)buildTypes\s*\{", r"""\1signingConfigs {
        release {
            keyAlias = keystoreProperties['keyAlias']
            keyPassword = keystoreProperties['keyPassword']
            storeFile = file(keystoreProperties['storeFile'])
            storePassword = keystoreProperties['storePassword']
        }
    }
\1buildTypes {""", s, count=1)
        s = s.replace("signingConfig = signingConfigs.debug",
                      "signingConfig = signingConfigs.release")
        s = s.replace("signingConfig signingConfigs.debug",
                      "signingConfig signingConfigs.release")
    groovy.write_text(s)
    target = groovy
else:
    raise SystemExit("build.gradle nicht gefunden")

text = target.read_text()
for needle in ("minSdk = 23", f'"{pkg}"', "signingConfigs.getByName(\"release\")"
               if target is kts else "signingConfigs.release"):
    if needle not in text:
        raise SystemExit(f"Anpassung fehlgeschlagen: {needle!r} fehlt in {target}")
print(f"OK: {target} – Paket {pkg}, minSdk 23, eigener Signaturschlüssel")
