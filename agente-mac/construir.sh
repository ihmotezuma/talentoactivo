#!/bin/zsh
# Construye TalentoActivo.app (Mac con chip Apple e Intel) y la deja en ../public/TalentoActivo-Mac.zip
# Uso:  cd agente-mac && ./construir.sh
# Necesita las herramientas de Xcode (xcode-select --install) y el archivo ../.env con las claves.
set -euo pipefail
cd "${0:A:h}"

# La URL y la clave pública de Supabase salen del .env (la clave es pública por diseño).
set -a; source ../.env; set +a
: "${VITE_SUPABASE_URL:?falta VITE_SUPABASE_URL en .env}"
: "${VITE_SUPABASE_ANON_KEY:?falta VITE_SUPABASE_ANON_KEY en .env}"
cat > Fuentes/Config.generado.swift <<SWIFT
// Archivo generado por construir.sh (no se sube a GitHub).
let SUPABASE_URL = "${VITE_SUPABASE_URL}"
let SUPABASE_ANON_KEY = "${VITE_SUPABASE_ANON_KEY}"
let URL_SITIO = "https://talentoactivo.pages.dev"
SWIFT

salida="construido"
rm -rf "$salida"; mkdir -p "$salida/TalentoActivo.app/Contents/MacOS"

for arq in arm64 x86_64; do
  swiftc -O -target "$arq-apple-macos12.0" Fuentes/*.swift -o "$salida/TalentoActivo-$arq"
done
lipo -create "$salida"/TalentoActivo-arm64 "$salida"/TalentoActivo-x86_64 \
  -output "$salida/TalentoActivo.app/Contents/MacOS/TalentoActivo"
cp Info.plist "$salida/TalentoActivo.app/Contents/Info.plist"

# Firma "ad hoc" (sin cuenta de desarrollador): macOS la pedirá aprobar la primera vez.
codesign --force --sign - "$salida/TalentoActivo.app"

ditto -c -k --keepParent "$salida/TalentoActivo.app" ../public/TalentoActivo-Mac.zip
echo "Listo: public/TalentoActivo-Mac.zip"
