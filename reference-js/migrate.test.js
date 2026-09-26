'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const m = require('./migrate.js');

const entry = (name) => ({ name: name, aliases: [], kind: 'site', target: 'https://' + name });
const OLD_LIVE = [entry('youtube'), entry('gmail'), entry('tuner'), entry('timer')];   // his stale config.json
const CURRENT_DEFAULTS = [entry('youtube'), entry('gmail'), entry('tuner'), entry('timer'),
  entry('note'), entry('reminder'), entry('flip'), entry('settings'), entry('help'), entry('bored')];

test('migrate: a stale config gains every built-in it is missing, exactly once', () => {
  const r = m.mergeBuiltinCatalog(OLD_LIVE, CURRENT_DEFAULTS, []);
  assert.deepStrictEqual(r.catalog.map(e => e.name),
    ['youtube', 'gmail', 'tuner', 'timer', 'note', 'reminder', 'flip', 'settings', 'help', 'bored'],
    'existing entries keep their order; new ones are appended in the defaults\' order');
  assert.deepStrictEqual(r.offered, CURRENT_DEFAULTS.map(e => e.name).sort(),
    'every default now present, old and new alike, is recorded as offered');
});

test('migrate: running it again changes nothing (idempotent)', () => {
  const first = m.mergeBuiltinCatalog(OLD_LIVE, CURRENT_DEFAULTS, []);
  const second = m.mergeBuiltinCatalog(first.catalog, CURRENT_DEFAULTS, first.offered);
  assert.deepStrictEqual(second.catalog.map(e => e.name), first.catalog.map(e => e.name));
  assert.deepStrictEqual(second.offered, first.offered);
});

test('migrate: deleting a built-in on purpose is respected, forever', () => {
  const withFlip = m.mergeBuiltinCatalog(OLD_LIVE, CURRENT_DEFAULTS, []);
  const withoutHelp = withFlip.catalog.filter(e => e.name !== 'help');   // he deleted "help" in Settings
  const next = m.mergeBuiltinCatalog(withoutHelp, CURRENT_DEFAULTS, withFlip.offered);
  assert.ok(!next.catalog.some(e => e.name === 'help'), '"help" was offered before and is missing now: stays gone');
  assert.ok(next.offered.includes('help'), 'still remembered as offered, so it never sneaks back');
  assert.deepStrictEqual(next.catalog.map(e => e.name), withoutHelp.map(e => e.name), 'nothing else changes');
});

test('migrate: his own custom entries are left completely alone', () => {
  const withCustom = OLD_LIVE.concat([{ name: 'bat', aliases: ['batman'], kind: 'site', target: 'https://reader.example/x', living: true }]);
  const r = m.mergeBuiltinCatalog(withCustom, CURRENT_DEFAULTS, []);
  const bat = r.catalog.find(e => e.name === 'bat');
  assert.deepStrictEqual(bat, withCustom[4]);
  assert.ok(!r.offered.includes('bat'), 'a non-default name is never tracked as "offered"');
});

test('migrate: a brand new built-in nobody has ever seen gets added once', () => {
  const withCalc = CURRENT_DEFAULTS.concat([entry('calculator')]);
  const r = m.mergeBuiltinCatalog(OLD_LIVE, withCalc, []);
  assert.ok(r.catalog.some(e => e.name === 'calculator'));
  assert.ok(r.offered.includes('calculator'));
});

test('write migrate fixtures', () => {
  const dir = path.join(__dirname, '..', 'fixtures');
  const cases = [
    { existing: OLD_LIVE, defaults: CURRENT_DEFAULTS, offered: [] },
    { existing: m.mergeBuiltinCatalog(OLD_LIVE, CURRENT_DEFAULTS, []).catalog,
      defaults: CURRENT_DEFAULTS, offered: m.mergeBuiltinCatalog(OLD_LIVE, CURRENT_DEFAULTS, []).offered },
    { existing: OLD_LIVE.filter(e => e.name !== 'tuner'), defaults: CURRENT_DEFAULTS, offered: ['tuner', 'youtube'] },
    { existing: OLD_LIVE.concat([{ name: 'bat', aliases: [], kind: 'site', target: 'https://x', living: true }]), defaults: CURRENT_DEFAULTS, offered: [] },
    { existing: [], defaults: CURRENT_DEFAULTS, offered: [] }
  ].map(c => ({ ...c, result: m.mergeBuiltinCatalog(c.existing, c.defaults, c.offered) }));
  fs.writeFileSync(path.join(dir, 'migrate.json'), JSON.stringify({ cases }, null, 2));
});
