#!/usr/bin/env bash

IMAGE="$1"
CR=$(printf '\r')

# Select language packs for Tesseract
LANG="eng" # Default language is English, you can modify this line like "eng+deu" for English and German etc.

# Cleanup function to remove temp and original image
cleanup() {
  rm -f "$RESIZED"
  rm -f "$IMAGE"
}
trap cleanup EXIT

if [[ ! -f "$IMAGE" ]]; then
  notify-send -i dialog-error "OCR Error" "No image file received"
  exit 1
fi

# Resize for better OCR
RESIZED="/tmp/ocr_resized_$$.png"
magick "$IMAGE" -resize 400% "$RESIZED"

# Perform OCR
OCR_OUTPUT=$(tesseract --psm 6 -l "$LANG" "$RESIZED" - 2>&1)
OCR_STATUS=$?

if [ $OCR_STATUS -ne 0 ]; then
  notify-send -i dialog-error "OCR Error" "Tesseract failed: $OCR_OUTPUT"
  exit 1
fi

# Normalize line endings
TEXT=$(echo "$OCR_OUTPUT" | sed "s/\$/${CR}/")

# Copy to clipboard
if command -v wl-copy &>/dev/null; then
  echo -n "$TEXT" | wl-copy
elif command -v xclip &>/dev/null; then
  echo -n "$TEXT" | xclip -selection clipboard
else
  notify-send -i dialog-error "OCR Error" "No clipboard tool found"
  exit 1
fi

# Notify success
notify-send -i edit-paste "OCR" "Text copied to clipboard"
