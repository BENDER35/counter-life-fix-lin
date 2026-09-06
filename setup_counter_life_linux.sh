#!/usr/bin/env bash
# ==============================================================================
# Script de automatización de compatibilidad para Counter-Life en Xash3D (Linux)
# Desarrollado para motores Xash3D FWGS (x86 32-bit / x86_64 / ARM)
# ==============================================================================

set -euo pipefail

# Colores para la salida en consola
COLOR_RESET="\033[0m"
COLOR_INFO="\033[1;34m"
COLOR_SUCCESS="\033[1;32m"
COLOR_WARN="\033[1;33m"
COLOR_ERROR="\033[1;31m"

log_info()    { echo -e "${COLOR_INFO}[INFO]${COLOR_RESET} $*"; }
log_success() { echo -e "${COLOR_SUCCESS}[OK]${COLOR_RESET} $*"; }
log_warn()    { echo -e "${COLOR_WARN}[AVISO]${COLOR_RESET} $*"; }
log_error()   { echo -e "${COLOR_ERROR}[ERROR]${COLOR_RESET} $*" >&2; }

echo "=================================================================="
echo "    Instalador de compatibilidad Linux para Counter-Life (Xash3D)"
echo "=================================================================="

# 1. Determinar el directorio base de Xash3D
TARGET_DIR="${1:-$(cd "$(dirname "$(readlink -f "$0")")" && pwd)}"
log_info "Directorio objetivo de Xash3D: $TARGET_DIR"

if [ ! -d "$TARGET_DIR" ]; then
    log_error "El directorio especificado no existe: $TARGET_DIR"
    exit 1
fi

# 2. Localizar la carpeta del mod Counter-Life
MOD_DIR=""
for candidate in "Counter-Life" "counter-life" "Counter_Life" "cl"; do
    if [ -d "$TARGET_DIR/$candidate" ]; then
        MOD_DIR="$TARGET_DIR/$candidate"
        break
    fi
done

if [ -z "$MOD_DIR" ]; then
    log_error "No se encontró la carpeta del mod 'Counter-Life' en $TARGET_DIR."
    log_error "Asegúrate de haber extraído los datos de Counter-Life antes de ejecutar este script."
    exit 1
fi

log_info "Carpeta de mod detectada: $MOD_DIR"

# 3. Comprobar herramientas requeridas (curl/wget y unzip)
DOWNLOADER=""
if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
else
    log_error "Se necesita 'curl' o 'wget' para descargar los binarios. Instálalo con tu gestor de paquetes."
    exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
    log_error "Se necesita la utilidad 'unzip' para descomprimir los binarios."
    exit 1
fi

# 4. Detectar la arquitectura del ejecutable de Xash3D o del sistema
ARCH=""
XASH_BIN=""
if [ -f "$TARGET_DIR/xash" ]; then
    XASH_BIN="$TARGET_DIR/xash"
elif [ -f "$TARGET_DIR/xash3d" ]; then
    XASH_BIN="$TARGET_DIR/xash3d"
fi

if [ -n "$XASH_BIN" ] && command -v file >/dev/null 2>&1; then
    FILE_INFO=$(file -b "$XASH_BIN" || true)
    if [[ "$FILE_INFO" =~ 32-bit.*80386|Intel\ 80386|i386 ]]; then
        ARCH="linux-i386"
    elif [[ "$FILE_INFO" =~ 64-bit.*x86-64 ]]; then
        ARCH="linux-amd64"
    elif [[ "$FILE_INFO" =~ aarch64|ARM\ aarch64 ]]; then
        ARCH="linux-arm64"
    elif [[ "$FILE_INFO" =~ ARM ]]; then
        ARCH="linux-armhf"
    fi
fi

# Respaldo con uname -m si no se detectó por binario
if [ -z "$ARCH" ]; then
    UNAME_M=$(uname -m)
    case "$UNAME_M" in
        i386|i686)
            ARCH="linux-i386"
            ;;
        x86_64)
            ARCH="linux-amd64"
            ;;
        aarch64|arm64)
            ARCH="linux-arm64"
            ;;
        armv7l|armhf)
            ARCH="linux-armhf"
            ;;
        *)
            log_warn "Arquitectura no estándar detectada ($UNAME_M). Asumiendo linux-i386 por defecto."
            ARCH="linux-i386"
            ;;
    esac
fi

log_info "Arquitectura seleccionada para el mod: $ARCH"

# 5. Descargar el paquete de binarios compilado por FWGS
DOWNLOAD_URL="https://github.com/FWGS/hlsdk-mega-build/releases/download/continuous/Counter-Life-${ARCH}.zip"
TMP_DIR=$(mktemp -d "/tmp/counter_life_install.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

ZIP_PATH="$TMP_DIR/Counter-Life-${ARCH}.zip"
log_info "Descargando binarios desde: $DOWNLOAD_URL ..."

if [ "$DOWNLOADER" = "curl" ]; then
    curl -f -L --progress-bar -o "$ZIP_PATH" "$DOWNLOAD_URL"
else
    wget -q --show-progress -O "$ZIP_PATH" "$DOWNLOAD_URL"
fi

if [ ! -s "$ZIP_PATH" ]; then
    log_error "La descarga falló o el archivo descargado está vacío."
    exit 1
fi
log_success "Descarga completada con éxito."

# 6. Descomprimir e instalar librerías .so
log_info "Extrayendo librerías..."
unzip -q -o "$ZIP_PATH" -d "$TMP_DIR/extracted"

DLL_SOURCE=$(find "$TMP_DIR/extracted" -name "cl.so" | head -n 1)
CLIENT_SOURCE=$(find "$TMP_DIR/extracted" -name "client.so" | head -n 1)

if [ -z "$DLL_SOURCE" ] || [ -z "$CLIENT_SOURCE" ]; then
    log_error "El archivo ZIP no contenía 'cl.so' o 'client.so' esperados."
    exit 1
fi

mkdir -p "$MOD_DIR/dlls" "$MOD_DIR/cl_dlls"

cp "$DLL_SOURCE" "$MOD_DIR/dlls/cl.so"
chmod +x "$MOD_DIR/dlls/cl.so"
log_success "Instalado: $MOD_DIR/dlls/cl.so"

cp "$CLIENT_SOURCE" "$MOD_DIR/cl_dlls/client.so"
chmod +x "$MOD_DIR/cl_dlls/client.so"
log_success "Instalado: $MOD_DIR/cl_dlls/client.so"

# 7. Configurar liblist.gam
LIBLIST="$MOD_DIR/liblist.gam"
if [ -f "$LIBLIST" ]; then
    if grep -q "gamedll_linux" "$LIBLIST"; then
        log_info "'gamedll_linux' ya existe en liblist.gam. Actualizando ruta si es necesario..."
        sed -i -E 's|gamedll_linux[[:space:]]+".*"|gamedll_linux "dlls/cl.so"|g' "$LIBLIST"
    else
        log_info "Agregando directiva 'gamedll_linux' a liblist.gam..."
        cp "$LIBLIST" "$LIBLIST.bak"
        if grep -q "gamedll" "$LIBLIST"; then
            sed -i '/gamedll[[:space:]]/a gamedll_linux "dlls/cl.so"' "$LIBLIST"
        else
            echo 'gamedll_linux "dlls/cl.so"' >> "$LIBLIST"
        fi
    fi
    log_success "Archivo $LIBLIST configurado correctamente."
else
    log_warn "No se encontró liblist.gam en $MOD_DIR. Creando uno básico..."
    cat << 'EOF' > "$LIBLIST"
game "Counter-Life"
gamedir "Counter-Life"
version "Version 1"
gamedll "dlls\cl.dll"
gamedll_linux "dlls/cl.so"
mpentity "info_player_start"
startmap "c1a0d"
nomodels "1"
type "singleplayer_only"
trainmap "target_practice"
cldll "1"
svonly "0"
icon "CLicon"
developer "Haunter"
EOF
    log_success "Archivo liblist.gam creado."
fi

# 8. Verificación final rápida con xash (si existe)
if [ -f "$TARGET_DIR/xash" ]; then
    log_info "Verificando carga con el motor..."
    if (cd "$TARGET_DIR" && ./xash -dev 0 -game "$(basename "$MOD_DIR")" +quit >/dev/null 2>&1); then
        log_success "¡Comprobación exitosa! Xash3D reconoció e inicializó Counter-Life correctamente."
    else
        log_warn "No se pudo ejecutar la prueba silenciosa, pero los archivos se instalaron correctamente."
    fi
fi

echo "=================================================================="
echo -e "${COLOR_SUCCESS}¡Compatibilidad de Counter-Life configurada con éxito!${COLOR_RESET}"
echo "Puedes iniciar el juego ejecutando:"
echo "  ./xash3d -game $(basename "$MOD_DIR")"
echo "=================================================================="
