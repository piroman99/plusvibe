# GNOME-виджет PlusVibe Balance

Индикатор в верхней панели GNOME: остаток PlusVibe API прямо в панели,
клик — меню с расходом за сегодня/месяц и числом запросов.

Подходит для GNOME Shell **45–50** (ESM-расширения). На GNOME 44 и старее не
устанавливается (там другой механизм расширений).

## Что в папке

| Файл | Назначение |
|------|-----------|
| `metadata.json` | описание расширения (UUID, версии shell) |
| `extension.js` | сам виджет |
| `stylesheet.css` | стили (подсветка низкого баланса) |
| `install.sh` | установка одной командой |
| `key.txt.example` | шаблон; рабочий ключ впиши в `~/.config/plusvibe/key.txt` (см. ниже) |

## Установка

### Вариант 1 — скриптом
```bash
cd gnome-widget
./install.sh
```

### Вариант 2 — вручную (копированием)
```bash
UUID=plusvibe@ivan.local
DEST=~/.local/share/gnome-shell/extensions/$UUID
mkdir -p "$DEST"
cp metadata.json extension.js stylesheet.css "$DEST"/
gnome-extensions enable "$UUID"
```

После установки перезапусти GNOME Shell:
- **X11**: `Alt`+`F2` → набери `r` → Enter
- **Wayland**: выйди из сессии и войди снова (или перезагрузка)

## Ключ

Впиши ключ `sk-pv-...` в один из файлов (проверяются по порядку):
1. `~/.config/plusvibe/key.txt`
2. `key.txt` рядом с `extension.js` (создай по образцу `key.txt.example`)

Формат — просто строка, либо `PLUSVIBE_API_KEY=sk-pv-...`.
Если файла нет, расширение создаст шаблон в `~/.config/plusvibe/key.txt`.

## Настройка

Прямо в `extension.js`:
- `REFRESH_SECONDS = 600` — период обновления (секунды);
- `LOW_THRESHOLD = 100.0` — порог подсветки остатка красным.

## Как выглядит

- `PV 1 234.56 ₽` — всё хорошо;
- `PV 50.00 ₽` красным — остаток ниже порога;
- `PV: ключ?` — не найден ключ;
- `PV ⚠` — ошибка запроса (меню покажет детали);
- `PV …` — идёт обновление.
