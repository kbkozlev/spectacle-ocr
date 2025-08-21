#!/usr/bin/env bash
set -euo pipefail

########################################
# Color & formatting
########################################
_use_color() {
  # Enable color only if stdout is a TTY and NO_COLOR isn't set
  if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    return 0
  else
    return 1
  fi
}

if _use_color; then
  BOLD="\033[1m"; DIM="\033[2m"; RESET="\033[0m"
  FG_RED="\033[31m"; FG_GRN="\033[32m"; FG_YLW="\033[33m"
  FG_BLU="\033[34m"; FG_MAG="\033[35m"; FG_CYN="\033[36m"; FG_WHT="\033[37m"
else
  BOLD=""; DIM=""; RESET=""
  FG_RED=""; FG_GRN=""; FG_YLW=""; FG_BLU=""; FG_MAG=""; FG_CYN=""; FG_WHT=""
fi

hr()   { printf '\n%b\n' "${DIM}----------------------------------------${RESET}"; }
say()  { printf '%b\n' "$*${RESET}"; }                 # plain
info() { printf '%b\n' "${FG_CYN}$*${RESET}"; }
ok()   { printf '%b\n' "${FG_GRN}$*${RESET}"; }
warn() { printf '%b\n' "${FG_YLW}$*${RESET}"; }
err()  { printf '%b\n' "${FG_RED}$*${RESET}" >&2; }

########################################
# Helpers
########################################
need_cmd() { command -v "$1" >/dev/null 2>&1; }

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif need_cmd sudo; then
    sudo "$@"
  else
    err "Need root privileges to run: $*"
    err "Please run this script as root or install sudo."
    exit 1
  fi
}

detect_pkg_mgr() {
  if need_cmd apt-get; then echo "apt"; return
  elif need_cmd dnf; then echo "dnf"; return
  elif need_cmd yum; then echo "yum"; return
  elif need_cmd pacman; then echo "pacman"; return
  elif need_cmd zypper; then echo "zypper"; return
  elif need_cmd apk; then echo "apk"; return
  fi
  echo "unknown"
}

on_wayland() {
  if [ "${XDG_SESSION_TYPE:-}" = "wayland" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    return 0
  else
    return 1
  fi
}

########################################
# Dependency planning + confirmation
########################################
plan_packages() {
  local mgr="$1" clip_pkg="$2"
  case "$mgr" in
    apt)    echo "tesseract-ocr imagemagick $clip_pkg libnotify-bin desktop-file-utils" ;;
    dnf)    echo "tesseract ImageMagick $clip_pkg libnotify desktop-file-utils" ;;
    yum)    echo "tesseract ImageMagick $clip_pkg libnotify desktop-file-utils" ;;
    pacman) echo "tesseract imagemagick $clip_pkg libnotify desktop-file-utils" ;;
    zypper) echo "tesseract ImageMagick $clip_pkg libnotify-tools desktop-file-utils" ;;
    apk)    echo "tesseract-ocr imagemagick $clip_pkg libnotify desktop-file-utils" ;;
    *)      echo "" ;;
  esac
}

confirm_install() {
  local mgr="$1"
  local clip_pkg
  if on_wayland; then clip_pkg="wl-clipboard"; else clip_pkg="xclip"; fi

  local pkgs
  pkgs="$(plan_packages "$mgr" "$clip_pkg")"

  if [ -z "$pkgs" ]; then
    err "Could not detect a supported package manager."
    say "Please install these manually, then re-run:"
    say "  - tesseract (or tesseract-ocr)"
    say "  - ImageMagick"
    say "  - ${clip_pkg}"
    say "  - libnotify (libnotify-bin / libnotify-tools)"
    say "  - desktop-file-utils"
    exit 1
  fi

  hr
  info "${BOLD}The script needs to install the following packages:${RESET}"
  say "  ${FG_WHT}${pkgs}${RESET}"
  say
  warn "This will use '${mgr}' and may download packages from your configured repositories."
  say
  printf '%b' "${FG_MAG}${BOLD}Proceed with installation? [Y/n]: ${RESET}"
  local reply
  read -r reply
  reply="${reply:-Y}"
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    warn "Installation aborted by user. Exiting."
    exit 0
  fi

  export __CLIP_PKG="$clip_pkg"
  export __PKG_LIST="$pkgs"
}

install_deps() {
  local mgr="$1"
  local pkgs="$2"

  hr
  info "${BOLD}Installing dependencies using package manager:${RESET} ${FG_WHT}$mgr${RESET}"
  say "Packages: ${FG_WHT}$pkgs${RESET}"
  hr

  case "$mgr" in
    apt)
      as_root apt-get update -y
      as_root apt-get install -y $pkgs
      ;;
    dnf)
      as_root dnf install -y $pkgs
      ;;
    yum)
      as_root yum install -y $pkgs
      ;;
    pacman)
      as_root pacman -Sy --noconfirm $pkgs
      ;;
    zypper)
      as_root zypper --non-interactive install $pkgs
      ;;
    apk)
      as_root apk add --no-cache $pkgs
      ;;
    *)
      err "Unsupported package manager after confirmation step."
      exit 1
      ;;
  esac
  ok "Dependencies installed."
}

write_desktop_file() {
  local install_path="$1"   # full path to ocr.sh
  local desktop_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  mkdir -p "$desktop_dir"

  local desktop_file="$desktop_dir/spectacle-ocr.desktop"

  cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=Extract Text
Exec=sh -c "nohup '$install_path' %f >/dev/null 2>&1 &"
MimeType=image/png;
Icon=scanner
Terminal=false
Type=Application
Categories=Utility;
StartupNotify=false
EOF

  ok "Wrote desktop entry: ${desktop_file}"

  if need_cmd update-desktop-database; then
    update-desktop-database "$desktop_dir" || true
    info "Updated desktop database for: ${desktop_dir}"
  else
    warn "'update-desktop-database' not found. It will update automatically later, or install 'desktop-file-utils' and run it."
  fi
}

########################################
# Main
########################################
hr
info "${BOLD}OCR Setup for ocr.sh${RESET}"
hr

# Ensure ocr.sh exists next to this setup script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="$SCRIPT_DIR/ocr.sh"
if [ ! -f "$SOURCE_SCRIPT" ]; then
  err "Could not find 'ocr.sh' next to this setup script at: $SOURCE_SCRIPT"
  exit 1
fi

# Detect package manager & confirm install
PKG_MGR="$(detect_pkg_mgr)"
confirm_install "$PKG_MGR"   # sets __CLIP_PKG and __PKG_LIST
install_deps "$PKG_MGR" "$__PKG_LIST"

# Choose installation directory
DEFAULT_INSTALL_DIR="$HOME/.local/bin"
printf '%b' "${FG_MAG}${BOLD}Installation directory${RESET} ${DIM}[default: ${DEFAULT_INSTALL_DIR}]${RESET}: "
read -r INSTALL_DIR
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

mkdir -p "$INSTALL_DIR"

TARGET_SCRIPT="$INSTALL_DIR/ocr.sh"
cp -f "$SOURCE_SCRIPT" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"

ok "Installed: ${TARGET_SCRIPT}"
say "${DIM}Make sure '${INSTALL_DIR}' is in your PATH.${RESET}"

# Create desktop entry
write_desktop_file "$TARGET_SCRIPT"

hr
ok "${BOLD}All set!${RESET}"
hr
