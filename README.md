# spectacle-ocr

Add quick **OCR (text extraction)** to screenshots you take with **Spectacle**.  
In Spectacle select **Extract** or right click an image → **Extract Text** → the recognized text lands in your clipboard, with a desktop notification.

---

## ✨ Features

- 🖼️ Auto-resizes the image for better OCR accuracy  
- 🧠 Tesseract OCR with multiple languages (`eng` by default)  
- 📋 Copies result straight to your clipboard (Wayland **wl-copy** / X11 **xclip**)  
- 🔔 Desktop notifications for success and errors  
- 🧹 Cleans up temporary files automatically

---

## 📦 Requirements

- **Tesseract OCR** (with language data for the languages you use)
- **ImageMagick** (`magick` command)
- **Clipboard tool**
  - Wayland: `wl-clipboard` (uses `wl-copy`)
  - X11: `xclip`
- **libnotify** (`notify-send`)
- **desktop-file-utils** (to update the desktop database)

> These are installed automatically by the setup script below.

---

## 🚀 Installation

### Option A: Use the setup script (recommended)

1. Download the files with either git or wget.
2. cd into the folder
3. Run:
   ```bash
   bash setup.sh
   ```
4. The script will:
   - Detect your package manager and prompt you to install the required packages
   - Ask where to install `ocr.sh` (defaults to `~/.local/bin`)
   - Create `~/.local/share/applications/spectacle-ocr.desktop`
   - Update the desktop database

> After installation, you’ll have a launcher named **“Extract Text”** registered for PNG images.

### Option B: Manual install

1. Install dependencies for your distro, e.g. Ubuntu/Debian:
   ```bash
   sudo apt-get update
   sudo apt-get install -y tesseract-ocr imagemagick wl-clipboard xclip libnotify-bin desktop-file-utils
   ```
   (Wayland users only need `wl-clipboard`; X11 users only need `xclip`.)

2. Copy `ocr.sh` somewhere in your `$PATH` and make it executable:
   ```bash
   install -Dm755 ./ocr.sh "$HOME/.local/bin/ocr.sh"
   ```

3. Create the desktop entry:
   ```bash
   mkdir -p ~/.local/share/applications
   cat > ~/.local/share/applications/spectacle-ocr.desktop <<'EOF'
   [Desktop Entry]
   Name=Extract Text
   Exec=sh -c "nohup $HOME/.local/bin/ocr.sh %f >/dev/null 2>&1 &"
   MimeType=image/png;
   Icon=scanner
   Terminal=false
   Type=Application
   Categories=Utility;
   StartupNotify=false
   EOF

   update-desktop-database ~/.local/share/applications || true
   ```

---

## 🧰 Usage

### From Spectacle / your file manager
- Take a screenshot with **Spectacle** and click **Export** -> **Extract Text**.
- OR save the image and in your file manager, right-click the PNG → **Open With → Extract Text**.  
  The text is copied to your clipboard and you’ll see a notification.

### From the terminal
```bash
ocr.sh /path/to/image.png
# Result is copied to the clipboard; notification is shown.
```

---

## ⚙️ Configuration

- **Languages**: Change the `LANG` parameter at the top of the `ocr.sh` script to select the languages. 
- Examples:
  - English only: `LANG="eng"`
  - English + German: `LANG="eng+deu"`
  - Add other Tesseract langs if installed (e.g., `spa`, `fra`, etc.).
---

## 🧪 Notes & Limitations

- **Wayland vs X11**: The script prefers `wl-copy` (Wayland) and falls back to `xclip` (X11).
- **ImageMagick policies**: Some distros restrict certain operations via ImageMagick’s policy file. If you hit errors, check `/etc/ImageMagick-*/policy.xml`.
- **Input formats**: The `.desktop` entry registers for `image/png`. Extend `MimeType` if you want JPEG, etc.

---

## 🧹 Uninstall

```bash
rm -f ~/.local/share/applications/spectacle-ocr.desktop
update-desktop-database ~/.local/share/applications || true
rm -f ~/.local/bin/ocr.sh
```

