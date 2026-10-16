'use strict';

/* PlusVibe Balance — индикатор в верхней панели GNOME Shell (45+).
 *
 * Показывает остаток PlusVibe API. Клик по индикатору — меню с деталями
 * (остаток, расход за сегодня и за месяц, число запросов).
 *
 * Ключ (sk-pv-...) берётся по порядку:
 *   1) ~/.config/plusvibe/key.txt
 *   2) key.txt рядом с этим extension.js
 * Файл ключа: либо просто `sk-pv-...`, либо строка `PLUSVIBE_API_KEY=sk-pv-...`.
 * Если файла нет — extension создаёт шаблон в ~/.config/plusvibe/key.txt.
 */

import GObject from 'gi://GObject';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import St from 'gi://St';
import Clutter from 'gi://Clutter';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const BASE_URL = 'https://plusvibeapi.ru';
const REFRESH_SECONDS = 600; // обновление раз в 10 минут
const LOW_THRESHOLD = 100.0; // ₽ — ниже этого остаток подсвечивается

let keyCandidates = [];

function readKeyFrom(path) {
  try {
    const file = Gio.File.new_for_path(path);
    const [ok, bytes] = file.load_contents(null);
    if (!ok)
      return null;
    const text = new TextDecoder().decode(bytes).trim();
    for (const raw of text.split('\n')) {
      let line = raw.trim();
      if (!line || line.startsWith('#'))
        continue;
      const eq = line.indexOf('=');
      if (eq >= 0)
        line = line.slice(eq + 1);
      line = line.trim().replace(/^["']|["']$/g, '');
      if (line)
        return line;
    }
  } catch (e) {
    // нет файла / нет доступа — просто пропускаем
  }
  return null;
}

function readKey() {
  for (const p of keyCandidates) {
    const k = readKeyFrom(p);
    if (k)
      return k;
  }
  return null;
}

function runCurl(url, key) {
  return new Promise((resolve, reject) => {
    let proc;
    try {
      proc = Gio.Subprocess.new(
        ['curl', '-sS', '--max-time', '20',
          '-H', `Authorization: Bearer ${key}`,
          '-H', `x-api-key: ${key}`,
          url],
        Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE);
    } catch (e) {
      reject(e);
      return;
    }
    proc.communicate_utf8_async(null, null, (p, res) => {
      try {
        const [, stdout, stderr] = p.communicate_utf8_finish(res);
        if (!p.get_successful()) {
          reject(new Error(stderr || `curl exit ${p.get_exit_status()}`));
          return;
        }
        resolve(JSON.parse(stdout));
      } catch (e) {
        reject(e);
      }
    });
  });
}

function findValue(obj, needle) {
  if (!obj || typeof obj !== 'object')
    return undefined;
  if (Array.isArray(obj)) {
    for (const item of obj) {
      const r = findValue(item, needle);
      if (r !== undefined)
        return r;
    }
    return undefined;
  }
  for (const k of Object.keys(obj)) {
    if (k.toLowerCase().includes(needle) && obj[k] !== null && typeof obj[k] !== 'object')
      return obj[k];
  }
  for (const k of Object.keys(obj)) {
    const r = findValue(obj[k], needle);
    if (r !== undefined)
      return r;
  }
  return undefined;
}

function fmtRub(v) {
  const n = Number(v);
  if (!isFinite(n))
    return '—';
  return n.toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ' ₽';
}

const PlusVibeIndicator = GObject.registerClass(
class PlusVibeIndicator extends PanelMenu.Button {
  _init() {
    super._init(0.0, 'PlusVibe Balance');

    this._destroyed = false;
    this._timerId = 0;

    this._label = new St.Label({
      text: 'PV …',
      y_align: Clutter.ActorAlign.CENTER,
      style_class: 'plusvibe-panel-label',
    });
    this.add_child(this._label);

    this._balItem = new PopupMenu.PopupMenuItem('Остаток: —', {reactive: false});
    this._todayItem = new PopupMenu.PopupMenuItem('Сегодня: —', {reactive: false});
    this._monthItem = new PopupMenu.PopupMenuItem('За месяц: —', {reactive: false});
    this.menu.addMenuItem(this._balItem);
    this.menu.addMenuItem(this._todayItem);
    this.menu.addMenuItem(this._monthItem);

    this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

    this.menu.addMenuItem(new PopupMenu.PopupMenuItem(
      'Ключ: ~/.config/plusvibe/key.txt', {reactive: false}));

    this._refreshItem = new PopupMenu.PopupMenuItem('Обновить');
    this._refreshItem.connect('activate', () => this._refresh());
    this.menu.addMenuItem(this._refreshItem);

    this._refresh();
    this._timerId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT,
      REFRESH_SECONDS, () => {
        this._refresh();
        return GLib.SOURCE_CONTINUE;
      });
  }

  _setLabel(text, low) {
    if (this._destroyed)
      return;
    this._label.set_text(text);
    if (low)
      this._label.add_style_class_name('plusvibe-low');
    else
      this._label.remove_style_class_name('plusvibe-low');
  }

  _setMenu(balance, today, month) {
    if (this._destroyed)
      return;
    this._balItem.label.set_text(`Остаток: ${balance}`);
    this._todayItem.label.set_text(`Сегодня: ${today}`);
    this._monthItem.label.set_text(`За месяц: ${month}`);
  }

  async _refresh() {
    if (this._destroyed)
      return;

    const key = readKey();
    if (!key) {
      this._setLabel('PV: ключ?', false);
      this._setMenu('—', '—', '—');
      return;
    }

    this._setLabel('PV …', false);
    try {
      const [usage, balance] = await Promise.all([
        runCurl(`${BASE_URL}/api/key/usage`, key),
        runCurl(`${BASE_URL}/v1/balance`, key),
      ]);
      if (this._destroyed)
        return;

      let bal = findValue(balance, 'balance');
      if (bal === undefined)
        bal = findValue(usage, 'balance');
      const today = findValue(usage, 'today');
      const month = findValue(usage, 'month');
      const reqs = findValue(usage, 'request');

      const balStr = fmtRub(bal);
      const isLow = Number(bal) < LOW_THRESHOLD;
      this._setLabel(`PV ${balStr}`, isLow);

      let todayStr = today === undefined ? '—' : fmtRub(today);
      if (reqs !== undefined)
        todayStr += ` (${reqs})`;
      this._setMenu(balStr, todayStr, month === undefined ? '—' : fmtRub(month));
    } catch (e) {
      if (this._destroyed)
        return;
      this._setLabel('PV ⚠', false);
      this._setMenu('ошибка', String(e.message || e), '—');
    }
  }

  destroy() {
    this._destroyed = true;
    if (this._timerId) {
      GLib.Source.remove(this._timerId);
      this._timerId = 0;
    }
    super.destroy();
  }
});

export default class PlusVibeExtension extends Extension {
  enable() {
    const configDir = GLib.build_filenamev([GLib.get_user_config_dir(), 'plusvibe']);
    keyCandidates = [
      GLib.build_filenamev([configDir, 'key.txt']),
      GLib.build_filenamev([this.path, 'key.txt']),
    ];

    try {
      GLib.mkdir_with_parents(configDir, 0o755);
      const kp = GLib.build_filenamev([configDir, 'key.txt']);
      if (!GLib.file_test(kp, GLib.FileTest.EXISTS))
        GLib.file_set_contents(kp, '# Вставьте ключ PlusVibe (sk-pv-...) одной строкой\n');
    } catch (e) {
      // не критично — просто не сможем создать шаблон
    }

    this._indicator = new PlusVibeIndicator();
    Main.panel.addToStatusArea('plusvibe', this._indicator);
  }

  disable() {
    if (this._indicator) {
      this._indicator.destroy();
      this._indicator = null;
    }
    keyCandidates = [];
  }
}
