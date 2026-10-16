#!/usr/bin/env bash
# Установка GNOME-виджета PlusVibe Balance (одним запуском).
set -euo pipefail

UUID="plusvibe@ivan.local"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIP="${TMPDIR:-/tmp}/${UUID}.shell-extension.zip"

command -v gnome-extensions >/dev/null || {
  echo "Не найден gnome-extensions. Это GNOME? Установите пакет gnome-shell." >&2
  exit 1
}
command -v zip >/dev/null || { echo "Нужен zip." >&2; exit 1; }

cd "$DIR"
rm -f "$ZIP"
zip -q "$ZIP" metadata.json extension.js stylesheet.css

gnome-extensions install --force "$ZIP"

# ключ: переносим из папки в ~/.config (если уже вписан)
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/plusvibe"
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/key.txt" ]; then
  cp "$DIR/key.txt" "$CONFIG_DIR/key.txt" 2>/dev/null || \
    printf '# Вставьте ключ PlusVibe (sk-pv-...) одной строкой\n' > "$CONFIG_DIR/key.txt"
fi

gnome-extensions enable "$UUID" 2>/dev/null || true

# --- проверка результата (без вранья) -------------------------------------
EXT_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$UUID"
if [ -f "$EXT_DIR/metadata.json" ]; then
  echo "Файлы установлены: $EXT_DIR"
else
  echo "ВНИМАНИЕ: файлы не найдены в $EXT_DIR — установите вручную (см. README, вариант 2)." >&2
fi

INFO="$(gnome-extensions info "$UUID" 2>&1 || true)"
if printf '%s' "$INFO" | grep -qiE 'не найдено|not found|not installed';
 then
  echo "Shell пока НЕ видит расширение — это нормально до перезапуска GNOME Shell."
else
  echo "Shell видит расширение:"
  printf '%s\n' "$INFO" | sed 's/^/  /'
fi

cat <<EOF

Готово: $UUID

Если индикатор не появился — перезапустите GNOME Shell:
  • X11:     Alt+F2 → r → Enter
  • Wayland: выйдите из сессии и войдите снова (или перезагрузка)

Ключ впишите в: $CONFIG_DIR/key.txt
(либо в key.txt рядом с extension.js)
EOF
