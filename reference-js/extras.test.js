'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const x = require('./extras.js');

const DURATIONS = [
  ['10', 600], ['1', 60], ['1.5', 90], ['0.5', 30], ['25', 1500],
  ['90s', 90], ['90 sec', 90], ['45 seconds', 45], ['10m', 600], ['10 min', 600], ['10 minutes', 600], ['1 minute', 60],
  ['1h', 3600], ['2 hours', 7200], ['1h30', 5400], ['1h 30m', 5400], ['1 hour 30 minutes', 5400], ['1 hour and 30 minutes', 5400],
  ['5m30', 330], ['5m 30s', 330], ['1h 2m 3s', 3723],
  ['1:30', 90], ['0:45', 45], ['10:00', 600], ['1:30:00', 5400], ['01:02:03', 3723],
  ['for 10 minutes', 600], ['of about 5 min', 300], [' 10 ', 600], ['10 MIN', 600], ['24h', 86400],
  ['', null], ['soon', null], ['ten', null], ['10 bananas', 'null'], ['0', null], ['0s', null], ['25h', null], ['1:75:00x', null], ['5s 10', null]
].map(([t, s]) => [t, s === 'null' ? null : s]);

test('timer: reading durations', () => {
  for (const [text, seconds] of DURATIONS) assert.strictEqual(x.parseDuration(text), seconds, JSON.stringify(text));
});

test('timer: counting down and formatting', () => {
  assert.strictEqual(x.formatRemaining(581000), '9:41');
  assert.strictEqual(x.formatRemaining(580001), '9:41');
  assert.strictEqual(x.formatRemaining(7000), '0:07');
  assert.strictEqual(x.formatRemaining(1), '0:01');
  assert.strictEqual(x.formatRemaining(0), '0:00');
  assert.strictEqual(x.formatRemaining(-50), '0:00');
  assert.strictEqual(x.formatRemaining(3723000), '1:02:03');
  const t = x.startTimer(600, 1000);
  assert.deepStrictEqual(x.timerStatus(t, 1000), { remainingMs: 600000, fraction: 1, done: false, text: '10:00' });
  assert.deepStrictEqual(x.timerStatus(t, 301000), { remainingMs: 300000, fraction: 0.5, done: false, text: '5:00' });
  assert.deepStrictEqual(x.timerStatus(t, 601000), { remainingMs: 0, fraction: 0, done: true, text: '0:00' });
  assert.strictEqual(x.timerStatus(t, 999999).done, true);
});

const site = (name, target, living) => ({ name, aliases: [], kind: 'site', target, profile: 'personal', living });
const CATALOG = [
  site('youtube', 'https://www.youtube.com', false),
  site('bat', 'https://reader.example/manga/absolute-batman/chapter-3', true),
  site('berserk', 'https://reader.example/manga/berserk/chapter-40?page=2', true),
  site('course', 'https://learn.example.org/python/lesson/4', true),
  site('bleach', 'https://www.netflix.com/watch/111', true),
  site('suits', 'https://www.netflix.com/watch/222', true),
  { name: 'steam', aliases: [], kind: 'app', target: 'com.valvesoftware.steam', living: true }
];
const BOOKMARK_CASES = [
  ['https://reader.example/manga/absolute-batman/chapter-14', 'update', ['bat']],
  ['https://www.reader.example/manga/berserk/chapter-41#top', 'update', ['berserk']],
  ['https://reader.example/manga/one-piece/chapter-1', 'ambiguous', ['bat', 'berserk']],
  ['https://reader.example/', 'ambiguous', ['bat', 'berserk']],
  ['http://LEARN.example.org/python/lesson/9?x=1', 'update', ['course']],
  ['https://www.netflix.com/watch/98765', 'ambiguous', ['bleach', 'suits']],
  ['https://www.youtube.com/watch?v=abc', 'none', []],     // youtube is not living, so a video never overwrites it
  ['https://somewhere-else.example/page', 'none', []],
  ['', 'none', []],
  ['not a url', 'none', []]
];

test('bookmarks: only living entries move, and only when it is clear which one', () => {
  for (const [url, result, names] of BOOKMARK_CASES) {
    const r = x.findLivingEntry(url, CATALOG);
    assert.strictEqual(r.result, result, url);
    const got = r.result === 'update' ? [r.entry.name] : r.result === 'ambiguous' ? r.entries.map(e => e.name) : [];
    assert.deepStrictEqual(got, names, url);
  }
  const moved = x.moveEntry(CATALOG, 'bat', 'https://reader.example/manga/absolute-batman/chapter-14');
  assert.strictEqual(moved.find(e => e.name === 'bat').target, 'https://reader.example/manga/absolute-batman/chapter-14');
  assert.strictEqual(moved.find(e => e.name === 'bat').living, true);
  assert.strictEqual(moved.find(e => e.name === 'berserk').target, CATALOG[2].target);
  assert.strictEqual(CATALOG[1].target, 'https://reader.example/manga/absolute-batman/chapter-3', 'the original catalog is not changed in place');
});

test('bookmarks: url parts', () => {
  assert.deepStrictEqual(x.urlParts('https://www.Example.com:8080/a/b/?q=1#frag'), { host: 'example.com:8080', segments: ['a', 'b'] });
  assert.deepStrictEqual(x.urlParts('https://user:pw@example.com/x'), { host: 'example.com', segments: ['x'] });
  assert.deepStrictEqual(x.urlParts('example.com'), { host: 'example.com', segments: [] });
});

test('write extras fixtures', () => {
  const dir = path.join(__dirname, '..', 'fixtures');
  const formats = [581000, 580001, 7000, 1, 0, -50, 3723000, 59999, 60000, 3600000].map(ms => ({ ms, text: x.formatRemaining(ms) }));
  const bookmarks = BOOKMARK_CASES.map(([url]) => {
    const r = x.findLivingEntry(url, CATALOG);
    return { url, result: r.result, names: r.result === 'update' ? [r.entry.name] : r.result === 'ambiguous' ? r.entries.map(e => e.name) : [] };
  });
  fs.writeFileSync(path.join(dir, 'extras.json'), JSON.stringify({
    durations: DURATIONS.map(([text, seconds]) => ({ text, seconds })), formats, catalog: CATALOG, bookmarks
  }, null, 2));
});
