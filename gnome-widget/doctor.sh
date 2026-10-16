#!/usr/bin/env bash
# Диагностика + установка GNOME-виджета PlusVibe Balance.
# Запуск:  bash gnome-widget/doctor.sh
# Ничего не ломает: печатает отчёт, а если расширения нет — копирует файлы
# в ~/.local/share/gnome-shell/extensions/plusvibe@ivan.local и включает его.

UUID="plusvibe@ivan.local"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DEST="$DATA_HOME/gnome-shell/extensions/$UUID"
CONF_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
KEYFILE="$CONF_HOME/plusvibe/key.txt"

echo "======== ОКРУЖЕНИЕ ========"
echo "user        : $(id -un)"
echo "HOME        : $HOME"
echo "session     : ${XDG_SESSION_TYPE:-?}   desktop: ${XDG_CURRENT_DESKTOP:-?}"
if command -v gnome-shell >/dev/null 2>&1; then
  echo "gnome-shell : $(gnome-shell --version 2>/dev/null)"
else
  echo "gnome-shell : НЕ найден в PATH"
fi
echo "источник    : $SRC"
echo "цель        : $DEST"
echo

echo "======== ФАЙЛЫ РАСШИРЕНИЯ ========"
if [ -d "$DEST" ]; then
  ls -l "$DEST"
else
  echo "НЕТ каталога: $DEST"
fi
echo

echo "======== ВИДИТ ЛИ SHELL ========"
if command -v gnome-extensions >/dev/null 2>&1; then
  echo "-- gnome-extensions list | grep plusvibe:"
  gnome-extensions list 2>/dev/null | grep -i plusvibe || echo "   (в списке НЕТ)"
  echo "-- gnome-extensions info $UUID:"
  gnome-extensions info "$UUID" 2>&1 | sed 's/^/   /'
else
  echo "gnome-extensions НЕ найден (пакет gnome-shell?)"
fi
echo

echo "======== УСТАНОВКА (если файлов нет) ========"
if [ ! -f "$DEST/metadata.json" ]; then
  mkdir -p "$DEST" && \
  cp -f "$SRC/metadata.json" "$SRC/extension.js" "$SRC/stylesheet.css" "$DEST/" && \
  echo "   файлы скопированы в $DEST" || echo "   НЕ удалось скопировать"
else
  echo "   файлы уже на месте"
fi
echo

echo "======== ПЫТАЮСЬ ВКЛЮЧИТЬ ========"
gnome-extensions enable "$UUID" 2>&1 | sed 's/^/   /' || true
gnome-extensions info "$UUID" 2>&1 | sed 's/^/   /'
echo

echo "======== ОШИБКИ В ЖУРНАЛЕ (20 мин) ========"
journalctl --user -b --since "20 min ago" -o cat 2>/dev/null \
  | grep -iE "plusvibe|extension|JS ERROR" | tail -30 || echo "   (журнал недоступен или пусто)"
echo

echo "======== КЛЮЧ PLUSVIBE ========"
if [ -s "$KEYFILE" ] && grep -qE 'sk-pv-[A-Za-z0-9]' "$KEYFILE"; then
  echo "   ключ найден: $KEYFILE"
  KEY="$(grep -oE 'sk-pv-[A-Za-z0-9_-]+' "$KEYFILE" | head -1)"
  printf '   curl /v1/balance: '
  curl -sS --max-time 15 -H "x-api-key: $KEY" https://plusvibeapi.ru/v1/balance \
    && echo || echo "ошибка curl"
else
  echo "   ключ НЕ вписан ($KEYFILE)"
  echo "   впишите так:  mkdir -p '$CONF_HOME/plusvibe'; echo 'sk-pv-КЛЮЧ' > '$KEYFILE'; chmod 600 '$KEYFILE'"
fi
echo

echo "======== ЧТО ДАЛЬШЕ ========"
echo "• Если выше «State: ENABLED», но индикатора нет — выйдите из сессии и войдите снова"
echo "  (Wayland: Alt+F2→r НЕ работает), затем: gnome-extensions enable $UUID"
echo "• Проверить вручную:  gnome-extensions info $UUID"
echo "• Индикатор появляется в правой части верхней панели как «PV …» даже без ключа."
