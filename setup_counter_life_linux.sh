#!/usr/bin/env bash
# ==============================================================================
# Script de automatización de compatibilidad para Counter-Life en Xash3D
# Compatible con Ubuntu, Xubuntu, Kubuntu, Debian y derivados (i386 / amd64 / ARM)
# ==============================================================================

# Si fue invocado con /bin/sh (dash en Debian/Ubuntu), reejecutar con bash
if [ -z "${BASH_VERSION:-}" ]; then
    exec /usr/bin/env bash "$0" "$@"
fi

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

# Función para ejecutar comandos con privilegios elevados (compatible con Ubuntu/Debian)
run_as_root() {
    local cmd="$*"
    if [ "$EUID" -eq 0 ]; then
        bash -c "$cmd"
    elif command -v sudo >/dev/null 2>&1; then
        sudo bash -c "$cmd"
    elif command -v su >/dev/null 2>&1; then
        echo -e "${COLOR_WARN}Se requieren permisos de administrador. Introduce la contraseña de root:${COLOR_RESET}"
        su -c "$cmd"
    else
        log_error "Se requieren permisos de administrador para instalar paquetes, pero ni 'sudo' ni 'su' están disponibles."
        log_error "Por favor, ejecuta este script como root o instala 'sudo'."
        exit 1
    fi
}

echo "=================================================================="
echo "    Instalador de compatibilidad Linux para Counter-Life (Xash3D)"
echo "   (Probado en Ubuntu, Xubuntu, Kubuntu, Debian y derivados)"
echo "=================================================================="

# 1. Determinar el directorio base de Xash3D
TARGET_DIR="${1:-}"
if [ -z "$TARGET_DIR" ]; then
    SCRIPT_PATH="${BASH_SOURCE[0]}"
    while [ -h "$SCRIPT_PATH" ]; do
        SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
        SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
        [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
    done
    TARGET_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
fi

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

# 3. Detectar la arquitectura exacta del binario de Xash3D o del sistema
ARCH=""
XASH_BIN=""
if [ -f "$TARGET_DIR/xash" ]; then
    XASH_BIN="$TARGET_DIR/xash"
elif [ -f "$TARGET_DIR/xash3d" ]; then
    XASH_BIN="$TARGET_DIR/xash3d"
fi

# Intento 1: Usando file si está instalado
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

# Intento 2: Usando od (parte de coreutils, siempre presente en cualquier Linux)
if [ -z "$ARCH" ] && [ -n "$XASH_BIN" ] && command -v od >/dev/null 2>&1; then
    HEADER=($(od -An -t u1 -N 20 "$XASH_BIN" 2>/dev/null || true))
    if [ "${#HEADER[@]}" -ge 20 ]; then
        BIT_CLASS="${HEADER[4]}"
        MACHINE="${HEADER[18]}"
        if [ "$BIT_CLASS" = "1" ] && [ "$MACHINE" = "3" ]; then
            ARCH="linux-i386"
        elif [ "$BIT_CLASS" = "2" ] && [ "$MACHINE" = "62" ]; then
            ARCH="linux-amd64"
        elif [ "$BIT_CLASS" = "2" ] && [ "$MACHINE" = "183" ]; then
            ARCH="linux-arm64"
        elif [ "$BIT_CLASS" = "1" ] && [ "$MACHINE" = "40" ]; then
            ARCH="linux-armhf"
        fi
    fi
fi

# Intento 3: Respaldo con uname -m
if [ -z "$ARCH" ]; then
    UNAME_M=$(uname -m)
    case "$UNAME_M" in
        i386|i686)
            ARCH="linux-i386"
            ;;
        x86_64)
            # Si el directorio indica i386 pero uname dice x86_64, preferir i386
            if [[ "$TARGET_DIR" =~ i386 ]]; then
                ARCH="linux-i386"
            else
                ARCH="linux-amd64"
            fi
            ;;
        aarch64|arm64)
            ARCH="linux-arm64"
            ;;
        armv7l|armhf)
            ARCH="linux-armhf"
            ;;
        *)
            log_warn "Arquitectura no estándar ($UNAME_M). Usando linux-i386 por defecto."
            ARCH="linux-i386"
            ;;
    esac
fi

log_info "Arquitectura seleccionada: $ARCH"

# 4. Comprobación y autoinstalación de paquetes necesarios vía apt
log_info "Comprobando paquetes y librerías del sistema..."

REQUIRED_PKGS=()
MISSING_PKGS=()
NEED_ADD_I386=false

# Herramientas esenciales
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || REQUIRED_PKGS+=("curl")
command -v unzip >/dev/null 2>&1 || REQUIRED_PKGS+=("unzip")
command -v file >/dev/null 2>&1 || REQUIRED_PKGS+=("file")
REQUIRED_PKGS+=("ca-certificates")

# Librerías en tiempo de ejecución (C, C++, GCC) según arquitectura
if command -v dpkg >/dev/null 2>&1; then
    HOST_ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)

    if [ "$ARCH" = "linux-i386" ]; then
        if [ "$HOST_ARCH" != "i386" ]; then
            if ! dpkg --print-foreign-architectures 2>/dev/null | grep -q "^i386$"; then
                NEED_ADD_I386=true
            fi
        fi
        REQUIRED_PKGS+=("libc6:i386" "libstdc++6:i386")

        # Seleccionar libgcc apropiado para la versión de Debian/Ubuntu
        if dpkg -l libgcc-s1 >/dev/null 2>&1; then
            REQUIRED_PKGS+=("libgcc-s1:i386")
        elif dpkg -l libgcc1 >/dev/null 2>&1; then
            REQUIRED_PKGS+=("libgcc1:i386")
        else
            REQUIRED_PKGS+=("libgcc-s1:i386")
        fi
    elif [ "$ARCH" = "linux-amd64" ]; then
        REQUIRED_PKGS+=("libc6" "libstdc++6")
        if dpkg -l libgcc-s1 >/dev/null 2>&1; then
            REQUIRED_PKGS+=("libgcc-s1")
        else
            REQUIRED_PKGS+=("libgcc1")
        fi
    fi

    # Comprobar qué paquetes faltan actualmente instalados
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
            MISSING_PKGS+=("$pkg")
        fi
    done
fi

# Instalar con apt si falta algún paquete o se requiere habilitar multiarch i386
if [ ${#MISSING_PKGS[@]} -gt 0 ] || [ "$NEED_ADD_I386" = true ]; then
    if command -v apt-get >/dev/null 2>&1 || command -v apt >/dev/null 2>&1; then
        APT_TOOL="apt-get"
        command -v apt-get >/dev/null 2>&1 || APT_TOOL="apt"

        if [ "$NEED_ADD_I386" = true ]; then
            log_info "Habilitando soporte multiarch i386 en dpkg..."
            run_as_root "dpkg --add-architecture i386"
        fi

        log_warn "Se detectaron paquetes faltantes en el sistema: ${MISSING_PKGS[*]}"
        log_info "Actualizando repositorios e instalando dependencias mediante apt..."

        # Intentar instalación de los paquetes faltantes
        INSTALL_CMD="DEBIAN_FRONTEND=noninteractive $APT_TOOL update && DEBIAN_FRONTEND=noninteractive $APT_TOOL install -y ${MISSING_PKGS[*]}"
        if ! run_as_root "$INSTALL_CMD"; then
            # Si falla por libgcc-s1 vs libgcc1 en versiones antiguas de Debian/Ubuntu, reintentar con libgcc1
            if [[ " ${MISSING_PKGS[*]} " =~ "libgcc-s1:i386" ]]; then
                log_warn "Reintentando con libgcc1:i386 para compatibilidad con versiones anteriores..."
                ALT_PKGS=("${MISSING_PKGS[@]/libgcc-s1:i386/libgcc1:i386}")
                run_as_root "DEBIAN_FRONTEND=noninteractive $APT_TOOL install -y ${ALT_PKGS[*]}"
            else
                log_error "Falló la instalación de paquetes con apt. Revisa tu conexión a internet o repositorios."
                exit 1
            fi
        fi
        log_success "Dependencias del sistema instaladas correctamente."
    else
        log_error "Faltan paquetes necesarios (${MISSING_PKGS[*]}) y 'apt' no está disponible en este sistema."
        log_error "Por favor instálalos manualmente con el gestor de paquetes de tu distribución."
        exit 1
    fi
else
    log_success "Todos los paquetes y librerías necesarias del sistema están instalados."
fi

# Configurar herramienta de descarga (curl o wget)
DOWNLOADER=""
if command -v curl >/dev/null 2>&1; then
    DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOADER="wget"
else
    log_error "Ni 'curl' ni 'wget' están disponibles en el sistema."
    exit 1
fi

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

# 7. Configurar liblist.gam (manejando correctamente formatos CRLF de Windows)
LIBLIST="$MOD_DIR/liblist.gam"
if [ -f "$LIBLIST" ]; then
    # Limpiar retornos de carro \r para evitar problemas de formato
    tr -d '\r' < "$LIBLIST" > "$TMP_DIR/liblist_clean.gam"
    cp "$LIBLIST" "$LIBLIST.bak"

    if grep -q "gamedll_linux" "$TMP_DIR/liblist_clean.gam"; then
        log_info "'gamedll_linux' ya existe en liblist.gam. Actualizando ruta..."
        sed -i -E 's|gamedll_linux[[:space:]]+".*"|gamedll_linux "dlls/cl.so"|g' "$TMP_DIR/liblist_clean.gam"
    else
        log_info "Agregando directiva 'gamedll_linux' a liblist.gam..."
        if grep -q "gamedll" "$TMP_DIR/liblist_clean.gam"; then
            sed -i '/gamedll[[:space:]]/a gamedll_linux "dlls/cl.so"' "$TMP_DIR/liblist_clean.gam"
        else
            echo 'gamedll_linux "dlls/cl.so"' >> "$TMP_DIR/liblist_clean.gam"
        fi
    fi
    cp "$TMP_DIR/liblist_clean.gam" "$LIBLIST"
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

# Ajustar propietarios si el script fue ejecutado con sudo
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    USER_GROUP=$(id -gn "$SUDO_USER" 2>/dev/null || echo "$SUDO_USER")
    chown -R "$SUDO_USER:$USER_GROUP" "$MOD_DIR/dlls/cl.so" "$MOD_DIR/cl_dlls/client.so" "$LIBLIST" 2>/dev/null || true
fi

# 8. Verificación final rápida con xash (si existe el binario)
if [ -f "$TARGET_DIR/xash" ]; then
    log_info "Verificando inicialización con el motor Xash3D..."
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
