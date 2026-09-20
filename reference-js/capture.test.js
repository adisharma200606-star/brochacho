'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const cap = require('./capture.js');

// Monday 21 September 2026, 14:30 on the wall clock.
const NOW = Date.UTC(2026, 8, 21, 14, 30);
const at = (d, h, m = 0) => Date.UTC(2026, 8, d, h, m);

const CASES = [
  // [typed, title, due]
  ['buy new strings', 'buy new strings', null],
  ['me to call mom tomorrow at 5', 'call mom', at(22, 17)],
  ['to call mom tomorrow at 5pm', 'call mom', at(22, 17)],
  ['call mom tomorrow', 'call mom', at(22, 9)],
  ['call mom at 5', 'call mom', at(21, 17)],
  ['call mom at 2', 'call mom', at(22, 14)],                 // 14:00 has passed, so tomorrow
  ['standup at 9', 'standup', at(21, 21)],                   // 9:00 has passed, 21:00 has not
  ['standup at 9am', 'standup', at(22, 9)],
  ['standup tomorrow at 9', 'standup', at(22, 9)],
  ['gym 6:30 pm', 'gym', at(21, 18, 30)],
  ['gym 18:30', 'gym', at(21, 18, 30)],
  ['gym at 06:15', 'gym', at(22, 6, 15)],
  ['take the pizza out in 20 minutes', 'take the pizza out', NOW + 20 * 60000],
  ['take the pizza out in 20min', 'take the pizza out', NOW + 20 * 60000],
  ['check the build in an hour', 'check the build', NOW + 3600000],
  ['stretch in half an hour', 'stretch', NOW + 1800000],
  ['renew the domain in 2 weeks', 'renew the domain', NOW + 14 * 86400000],
  ['submit the report friday', 'submit the report', at(25, 9)],
  ['submit the report on friday at 4pm', 'submit the report', at(25, 16)],
  ['submit the report next fri', 'submit the report', at(25, 9)],
  ['team lunch monday', 'team lunch', at(28, 9)],            // today is Monday, so the next one
  ['watch the match tonight', 'watch the match', at(21, 20)],
  ['watch the match tonight at 11pm', 'watch the match', at(21, 23)],
  ['water the plants in the morning', 'water the plants', at(22, 9)],
  ['call the bank this afternoon', 'call the bank', at(21, 15)],
  ['lunch at noon', 'lunch', at(22, 12)],
  ['pay rent day after tomorrow', 'pay rent', at(23, 9)],
  ['email Priya about the deck today', 'email Priya about the deck', at(21, 16)],    // 9:00 has gone, so a bit later today
  // things that must NOT be read as times
  ['watch 12 angry men', 'watch 12 angry men', null],
  ['buy 2 sets of strings', 'buy 2 sets of strings', null],
  ['in two minds about the tee', 'in two minds about the tee', null],
  ['read chapter 5', 'read chapter 5', null],
  ['tomorrow', 'tomorrow', at(22, 9)],                       // nothing left for a title, so keep what he typed
  ['', '', null]
];

test('reminders: reading what he meant', () => {
  for (const [typed, title, due] of CASES) {
    const r = cap.parseReminder(typed, NOW);
    assert.strictEqual(r.title, title, 'title for ' + JSON.stringify(typed));
    assert.strictEqual(r.dueWall, due, 'due for ' + JSON.stringify(typed) + ': got ' + (r.dueWall === null ? null : new Date(r.dueWall).toISOString()));
  }
});

test('reminders: a day that is named wins over "it already passed"', () => {
  // "today" with a time that has passed stays today: he said today.
  assert.strictEqual(cap.parseReminder('log hours today at 9am', NOW).dueWall, at(21, 9));
  // Late at night, "at 5" still means the coming 17:00.
  assert.strictEqual(cap.parseReminder('call mom at 5', Date.UTC(2026, 8, 21, 23, 0)).dueWall, at(22, 17));
  // Month and year roll over.
  assert.strictEqual(cap.parseReminder('party tomorrow at 8pm', Date.UTC(2026, 11, 31, 10, 0)).dueWall, Date.UTC(2027, 0, 1, 20, 0));
});

test('reminders: saying it back', () => {
  assert.strictEqual(cap.describeDue(null, NOW), 'no time set');
  assert.strictEqual(cap.describeDue(at(21, 17), NOW), 'Today 17:00');
  assert.strictEqual(cap.describeDue(at(22, 9), NOW), 'Tomorrow 09:00');
  assert.strictEqual(cap.describeDue(at(25, 16, 5), NOW), 'Fri 25 Sep 16:05');
});

test('write capture fixtures', () => {
  const dir = path.join(__dirname, '..', 'fixtures');
  const extra = [['log hours today at 9am', NOW], ['call mom at 5', Date.UTC(2026, 8, 21, 23, 0)], ['party tomorrow at 8pm', Date.UTC(2026, 11, 31, 10, 0)]];
  const cases = CASES.map(([typed]) => [typed, NOW]).concat(extra).map(([typed, now]) => {
    const r = cap.parseReminder(typed, now);
    return { typed, now, title: r.title, dueWall: r.dueWall, said: cap.describeDue(r.dueWall, now) };
  });
  fs.writeFileSync(path.join(dir, 'capture.json'), JSON.stringify({ cases }, null, 2));
});
