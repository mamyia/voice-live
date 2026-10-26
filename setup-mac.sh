#!/usr/bin/env bash
# Serwer mowy (speech-to-speech) na MacBooku M1 — wszystko w jednym katalogu:
# klon speech-to-speech + mac.yaml w środku (sekrety NIE trafiają do tego skryptu).
#
# Użycie:
#   bash setup-mac.sh              # instalacja + szkielet mac.yaml (pauza na wpisanie sekretów)
#   bash setup-mac.sh start        # tylko uruchomienie serwera
#   VOICE=F3 bash setup-mac.sh     # inny głos (F1-F5, M1-M5, domyślnie F3)
#   SPEED=1.15 bash setup-mac.sh   # zmiana tempapeech (domyslnie 1.16)
set -euo pipefail

S2S="${S2S:-$HOME/speech-to-speech}"
VOICE="${VOICE:-F3}"
SPEED="${SPEED:-1.16}"
BRANCH="main"
REPO_URL="https://github.com/huggingface/speech-to-speech"
MAC_YAML_TEMPLATE="https://raw.githubusercontent.com/mamyia/voice-live/$BRANCH/config/mac.supertonic.F3.yaml"

command -v uv >/dev/null 2>&1 || { echo "Brak uv. Zainstaluj: brew install uv"; exit 1; }
if ! command -v git >/dev/null 2>&1; then echo "Brak git (zabudowany Apple developer tools)."; exit 1; fi

if [ ! -d "$S2S/.git" ]; then
  echo "==> Klonuję speech-to-speech do $S2S"
  git clone --depth 1 "$REPO_URL" "$S2S"
else
  echo "==> $S2S już istnieje"
fi
cd "$S2S"

if [ ! -d ".venv" ]; then
  echo "==> Tworzę venv (Python 3.12)"
  uv venv --python 3.12 .venv
fi
source .venv/bin/activate

echo "==> Instaluję speech-to-speech + Supertonic"
uv pip install -e .
uv pip install supertonic

# --- mac.yaml ---------------------------------------------------------------
if [ ! -f mac.yaml ]; then
  echo "==> Pobieram szablon mac.yaml (voice=$VOICE, speed=$SPEED)"
  curl -fsSL "$MAC_YAML_TEMPLATE" -o mac.yaml
  # podmiana głosu i tempa na wybrane
  sed -i '' "s/supertonic_tts_voice: F[0-9]/supertonic_tts_voice: $VOICE/" mac.yaml
  sed -i '' "s/supertonic_tts_speed: [0-9.]*/supertonic_tts_speed: $SPEED/" mac.yaml
  # mac.yaml jest przy okazji ignorowany (nie commitujemy sekretów)
  grep -q '^mac\.yaml$' .gitignore 2>/dev/null || echo "mac.yaml" >> .gitignore

  echo
  echo "    UWAGA: w $S2S/mac.yaml wpisz teraz adres i klucz z Conduita"
  echo "    (Settings → Voice → Private voice → 'Your speech server speaks too')."
  echo "    Znajdziesz je pod znacznikami 'ADRES_Z_CONDUITA' i 'KLUCZ_Z_CONDUITA'."
  echo
  read -r -p "Naciśnij Enter, gdy już to wpiszesz..."
else
  echo "==> mac.yaml już istnieje, nie ruszam (sekrety są w środku)"
fi

# --- walidacja -----------------------------------------------------------
echo "==> Walidacja mac.yaml"
python - <<'PY' || true
from speech_to_speech.config import load_config, validate_config, resolve_config, ConfigurationError
try:
    d = load_config("mac.yaml")
    validate_config(d)
    resolve_config(d, names=["mac"])
    print("    OK, config poprawny")
except ConfigurationError as e:
    print("    ConfigurationError:", e)
PY

# --- start ----------------------------------------------------------------
echo "==> Startuję serwer (pierwszy raz pobiera modele, port 8765 otworzy się po kilku minutach)"
echo "    Log:  tail -f $S2S/server.log"
#    Kontrola z Hermesa: 'curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
#      -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
#      http://10.250.0.3:8765/v1/realtime | head -1'  – powinno dać 'HTTP/1.1 101'.
exec speech-to-speech serve -f mac.yaml --name mac 2>&1 | tee server.log
