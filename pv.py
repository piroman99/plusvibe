#!/usr/bin/env python3
"""Быстрый просмотр баланса и расходов PlusVibe API.

Использование:
    python3 plusvibe/pv.py            # человекочитаемая сводка
    python3 plusvibe/pv.py --write    # обновить plusvibe/status.txt + короткая строка статуса
    python3 plusvibe/pv.py --json     # сырой JSON
    python3 plusvibe/pv.py --raw      # только /api/key/usage

Ключ берётся (по порядку):
  1. env PLUSVIBE_API_KEY
  2. файл рядом со скриптом: plusvibe/key.txt  (или .key, или env)
Формат файла — либо просто `sk-pv-...`, либо строка `PLUSVIBE_API_KEY=sk-pv-...`.

Порог низкого баланса: env PLUSVIBE_LOW_THRESHOLD (по умолчанию 100 ₽).
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime

BASE = os.environ.get("PLUSVIBE_BASE", "https://plusvibeapi.ru").rstrip("/")
HERE = os.path.dirname(os.path.abspath(__file__))
STATUS_FILE = os.path.join(HERE, "status.txt")

try:
    LOW_THRESHOLD = float(os.environ.get("PLUSVIBE_LOW_THRESHOLD", "100"))
except ValueError:
    LOW_THRESHOLD = 100.0


def _candidate_files() -> list[str]:
    """Один и тот же ключ используется и скриптом, и GNOME-виджетом."""
    names = ("key.txt", ".key", "env")
    dirs = [
        os.path.expanduser("~/.config/plusvibe"),
        HERE,
        os.path.join(HERE, "gnome-widget"),
    ]
    out = []
    for d in dirs:
        for n in names:
            out.append(os.path.join(d, n))
    return out


def load_key() -> str | None:
    k = os.environ.get("PLUSVIBE_API_KEY")
    if k and k.strip():
        return k.strip()
    for p in _candidate_files():
        if not os.path.exists(p):
            continue
        with open(p, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    kk, vv = line.split("=", 1)
                    if kk.strip() in ("PLUSVIBE_API_KEY", "KEY", "X_API_KEY", "API_KEY"):
                        return vv.strip().strip('"').strip("'")
                else:
                    return line
    return None


def get(path: str, key: str) -> dict:
    req = urllib.request.Request(
        BASE + path,
        headers={
            "Authorization": "Bearer " + key,
            "x-api-key": key,
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        return {"__error__": f"HTTP {e.code}", "body": body}
    except Exception as e:  # noqa: BLE001
        return {"__error__": str(e)}


def _find(obj, *needles):
    """Найти первое значение, чей ключ содержит все needles (регистронезависимо)."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            lk = str(k).lower()
            if all(n in lk for n in needles) and not isinstance(v, (dict, list)):
                return v
        for v in obj.values():
            r = _find(v, *needles)
            if r is not None:
                return r
    return None


def rub(v) -> str:
    try:
        return f"{float(v):,.2f} ₽".replace(",", " ")
    except (TypeError, ValueError):
        return str(v)


def collect(key: str) -> dict:
    usage = get("/api/key/usage", key)
    balance = get("/v1/balance", key)
    if "__error__" in usage and "__error__" in balance:
        return {"error": usage}
    return {
        "balance": _find(balance, "balance") if isinstance(balance, dict) else None,
        "today": _find(usage, "today"),
        "month": _find(usage, "month"),
        "requests": _find(usage, "request"),
        "usage_raw": usage,
        "balance_raw": balance,
    }


def summary_text(d: dict) -> str:
    lines = [
        "PlusVibe API — обновлено "
        + datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z"),
        f"  Остаток:   {rub(d['balance']) if d['balance'] is not None else '—'}",
        "  Сегодня:   "
        + (rub(d["today"]) if d["today"] is not None else "—")
        + (f"   ({d['requests']} запр.)" if d["requests"] is not None else ""),
        f"  За месяц:  {rub(d['month']) if d['month'] is not None else '—'}",
    ]
    if d["balance"] is None and d["today"] is None and d["month"] is None:
        lines += ["", "Сырой ответ /api/key/usage:", json.dumps(d["usage_raw"], ensure_ascii=False, indent=2)]
    return "\n".join(lines)


def low(d: dict) -> bool:
    try:
        return float(d["balance"]) < LOW_THRESHOLD
    except (TypeError, ValueError):
        return False


def main() -> int:
    key = load_key()
    if not key:
        msg = "Нет ключа. Задайте PLUSVIBE_API_KEY или положите ключ в plusvibe/key.txt"
        print(msg)
        return 2

    d = collect(key)

    if "--raw" in sys.argv:
        print(json.dumps(d.get("usage_raw", d), ensure_ascii=False, indent=2))
        return 0
    if "--json" in sys.argv:
        print(json.dumps(d, ensure_ascii=False, indent=2, default=str))
        return 0

    if "error" in d:
        text = "PlusVibe API — ошибка\n" + json.dumps(d["error"], ensure_ascii=False, indent=2)
        if "--write" in sys.argv:
            with open(STATUS_FILE, "w", encoding="utf-8") as fh:
                fh.write(text + "\n")
            print("ERROR " + json.dumps(d["error"], ensure_ascii=False))
        else:
            print(text)
        return 1

    text = summary_text(d)
    if "--write" in sys.argv:
        with open(STATUS_FILE, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        flag = "LOW" if low(d) else "OK"
        print(
            f"{flag} balance={d['balance']} today={d['today']} "
            f"month={d['month']} reqs={d['requests']} threshold={LOW_THRESHOLD}"
        )
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
