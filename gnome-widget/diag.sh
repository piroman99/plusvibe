#!/usr/bin/env bash
# Короткая диагностика виджета PlusVibe (один экран, без установки и без правок).
# Запуск:  bash ~/.nanobot/workspace/plusvibe/gnome-widget/diag.sh
UUID="plusvibe@ivan.local"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DEST="$DATA_HOME/gnome-shell/extensions/$UUID"
KEYFILE="${XDG_CONFIG_HOME:-$HOME/.config}/plusvibe/key.txt"

echo "1) shell: $(gnome-shell --version 2>/dev/null || echo '?')  session: ${XDG_SESSION_TYPE:-?}"
echo "2) файлы: $( [ -f "$DEST/metadata.json" ] && echo "есть $DEST" || echo "НЕТ $DEST" )"
echo -n "3) в списке shell: "
gnome-extensions list 2>/dev/null | grep -qx "$UUID" && echo "да" || echo "НЕТ"
echo "4) info:"; gnome-extensions info "$UUID" 2>&1 | sed -n '1,12p' | sed 's/^/     /'
echo -n "5) enabled-extensions: "
gsettings get org.gnome.shell enabled-extensions 2>/dev/null | grep -q "$UUID" && echo "включено в настройках" || echo "НЕ включено в настройках"
echo -n "6) disable-extension-version-validation: "
gsettings get org.gnome.shell disable-extension-version-validation 2>/dev/null || echo "?"
echo "7) журнал (plusvibe/JS ERROR, текущая загрузка):"
journalctl --user -b -o cat 2>/dev/null | grep -iE "plusvibe|JS ERROR|Extension .* error" | tail -8 | sed 's/^/     /' || echo "     (нет)"
echo "8) ключ:"
if grep -qE 'sk-pv-[A-Za-z0-9]' "$KEYFILE" 2>/dev/null; then
  K="$(grep -oE 'sk-pv-[A-Za-z0-9_-]+' "$KEYFILE" | head -1)"
  echo "     файл $KEYFILE — ключ есть (${K:0:6}…${K: -4})"
  for ep in /v1/balance /api/key/usage; do
    code="$(curl -sS -o /tmp/_pv_body -w '%{http_code}' --max-time 20 -H "x-api-key: $K" -H "Authorization: Bearer $K" "https://plusvibeapi.ru$ep" 2>/dev/null)"
    echo "     $ep -> HTTP $code : $(head -c 220 /tmp/_pv_body 2>/dev/null)"
  done
  rm -f /tmp/_pv_body
else
  echo "     ключа нет в $KEYFILE"
fi
