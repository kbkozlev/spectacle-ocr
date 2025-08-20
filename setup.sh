#!/usr/bin/env bash
set -euo pipefail

# --- Helpers ---
echo_hr() { printf '\n%s\n' "----------------------------------------"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif need_cmd sudo; then
    sudo "$@"
  else
    echo "Error: Need root privileges to run: $*" >&2
    echo "Please run this script as root or install sudo." >&2
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

install_deps() {
  local mgr="$1"
  local clip_pkg=""
  if on_wayland; then
    clip_pkg="wl-clipboard"
  else
    clip_pkg="xclip"
  fi

  echo_hr
  echo "Installing dependencies using package manager: $mgr"
  echo " - OCR: Tesseract"
  echo " - Images: ImageMagick"
  echo " - Clipboard: $clip_pkg"
  echo " - Notifications: libnotify (notify-send)"
  echo " - Desktop DB tool: desktop-file-utils"
  echo_hr

  case "$mgr" in
    apt)
      as_root apt-get update -y
      # Debian/Ubuntu package names:
      as_root apt-get install -y tesseract-ocr imagemagick "$clip_pkg" libnotify-bin desktop-file-utils
      ;;
    dnf)
      as_root dnf install -y tesseract ImageMagick "$clip_pkg" libnotify desktop-file-utils
      ;;
    yum)
      as_root yum install -y tesseract ImageMagick "$clip_pkg" libnotify desktop-file-utils
      ;;
    pacman)
      as_root pacman -Sy --noconfirm tesseract imagemagick "$clip_pkg" libnotify desktop-file-utils
      ;;
    zypper)
      as_root zypper --non-interactive install tesseract ImageMagick "$clip_pkg" libnotify-tools desktop-file-utils
      ;;
    apk)
      as_root apk add --no-cache tesseract-ocr imagemagick "$clip_pkg" libnotify desktop-file-utils
      ;;
    *)
      echo "Could not detect a supported package manager."
      echo "Please install these manually, then re-run:"
      echo "  - tesseract (or tesseract-ocr)"
      echo "  - ImageMagick"
      echo "  - $clip_pkg"
      echo "  - libnotify (or libnotify-bin / libnotify-tools)"
      echo "  - desktop-file-utils"
      exit 1
      ;;
  esac
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

  echo "Wrote desktop entry: $desktop_file"

  if need_cmd update-desktop-database; then
    update-desktop-database "$desktop_dir" || true
    echo "Updated desktop database for: $desktop_dir"
  else
    echo "'update-desktop-database' not found. It will update automatically later, or install 'desktop-file-utils' and run it."
  fi
}

# --- Start ---
echo_hr
echo "OCR Setup for ocr.sh"
echo_hr

# 1) Ensure ocr.sh exists next to this setup script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="$SCRIPT_DIR/ocr.sh"
if [ ! -f "$SOURCE_SCRIPT" ]; then
  echo "Error: Could not find 'ocr.sh' next to this setup script at: $SOURCE_SCRIPT" >&2
  exit 1
fi

# 2) Install dependencies
PKG_MGR="$(detect_pkg_mgr)"
install_deps "$PKG_MGR"

# 3) Choose installation directory (default ~/.local/bin)
DEFAULT_INSTALL_DIR="$HOME/.local/bin"
read -r -p "Installation directory [$DEFAULT_INSTALL_DIR]: " INSTALL_DIR
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

mkdir -p "$INSTALL_DIR"

TARGET_SCRIPT="$INSTALL_DIR/ocr.sh"
cp -f "$SOURCE_SCRIPT" "$TARGET_SCRIPT"
chmod +x "$TARGET_SCRIPT"

echo "Installed: $TARGET_SCRIPT"
echo "Make sure '$INSTALL_DIR' is in your PATH."

# 4) Create desktop entry
write_desktop_file "$TARGET_SCRIPT"

echo_hr
echo "All set!"
echo_hr
