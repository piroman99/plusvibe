#!/usr/bin/env python3
"""Добавляет UUID в org.gnome.shell enabled-extensions, сохраняя остальные."""
import ast
import subprocess
import sys

UUID = "plusvibe@ivan.local"
if len(sys.argv) > 1:
    UUID = sys.argv[1]

SCHEMA = "org.gnome.shell"
KEY = "enabled-extensions"


def gget():
    r = subprocess.run(["gsettings", "get", SCHEMA, KEY],
                       capture_output=True, text=True)
    return r.stdout.strip()


def gset(value):
    subprocess.run(["gsettings", "set", SCHEMA, KEY, value])


out = gget()
try:
    cur = list(ast.literal_eval(out)) if out else []
except Exception:
    cur = []

if UUID in cur:
    print("   уже в списке:", out)
    sys.exit(0)

cur.append(UUID)
val = "[" + ", ".join("'%s'" % x for x in cur) + "]"
gset(val)
print("   было :", out)
print("   стало:", gget())
