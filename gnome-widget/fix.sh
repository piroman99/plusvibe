#!/usr/bin/env bash
# Включает виджет PlusVibe и показывает РЕАЛЬНЫЕ ошибки (ничего не удаляет).
# Запуск:  bash ~/.nanobot/workspace/plusvibe/gnome-widget/fix.sh
UUID="plusvibe@ivan.local"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

echo "== 1. глобальный выключатель пользовательских расширений =="
DU="$(gsettings get org.gnome.shell disable-user-extensions 2>/dev/null)"
echo "disable-user-extensions = ${DU:-?}"
if [ "$DU" = "true" ]; then
  echo "   -> стоит запрет, снимаю"
  gsettings set org.gnome.shell disable-user-extensions false
fi

echo
echo "== 2. enabled-extensions ДО =="
gsettings get org.gnome.shell enabled-extensions 2>/dev/null

echo
echo "== 3. gnome-extensions enable (показываю ошибку, если есть) =="
ERR="$(gnome-extensions enable "$UUID" 2>&1)"
RC=$?
if [ -n "$ERR" ]; then echo "   $ERR"; else echo "   (без вывода)"; fi
echo "   exit=$RC"

echo
echo "== 4. добавляю в enabled-extensions напрямую =="
python3 "$DIR/pv_enable.py" "$UUID" 2>&1 | sed 's/^/   /'

echo
echo "== 5. enabled-extensions ПОСЛЕ =="
gsettings get org.gnome.shell enabled-extensions 2>/dev/null

echo
echo "== 6. gnome-extensions info =="
gnome-extensions info "$UUID" 2>&1 | sed -n '1,12p' | sed 's/^/   /'

echo
echo "== 7. журнал (ошибки расширений, текущая загрузка) =="
journalctl --user -b -o cat 2>/dev/null | grep -iE "plusvibe|JS ERROR|Extension" | tail -10 | sed 's/^/   /' || echo "   (пусто)"

echo
echo "== 8. что дальше =="
echo "• Если в п.6 'Включено: Да' / 'Состояние: ENABLED', а индикатора нет —"
echo "  на Wayland Alt+F2→r не работает: выйди из сессии и войди снова."
echo "• Если в п.3/п.4 была ошибка — покажи мне её текст."
