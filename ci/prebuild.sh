#!/usr/bin/env bash
# Rulat de workflow-urile iOS comune (kappado2000/ci-flutter) înainte de build.
# lib/config/asistent_server.dart e în .gitignore (conține tokenul serverului
# asistentului), deci CI-ul îl recreează din secretele repo-ului.
set -euo pipefail

secret() {
  python3 -c 'import json, os, sys; print(json.loads(os.environ["SECRETS_JSON"]).get(sys.argv[1], ""))' "$1"
}

URL=$(secret MEDRO_ASISTENT_URL)
TOKEN=$(secret MEDRO_ASISTENT_TOKEN)
# Cheia web a proiectului Firebase; goală = aplicația merge fără conturi.
API_KEY=$(secret MEDRO_FIREBASE_API_KEY)
if [ -z "$URL" ] || [ -z "$TOKEN" ]; then
  echo "::error::Lipsesc secretele MEDRO_ASISTENT_URL / MEDRO_ASISTENT_TOKEN"; exit 1
fi

cat > lib/config/asistent_server.dart << DART
const asistentServerUrl = '$URL';
const asistentServerToken = '$TOKEN';
const firebaseApiKey = '$API_KEY';
DART
