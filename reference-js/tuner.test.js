'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const tuner = require('./tuner.js');
const tunings = require('../defaults/tunings.json');

const near = (actual, expected, tolerance, label) =>
  assert.ok(Math.abs(actual - expected) <= tolerance, `${label}: got ${actual}, wanted ${expected} ± ${tolerance}`);

test('notes: names, numbers and frequencies', () => {
  assert.strictEqual(tuner.parseNote('A4'), 69);
  assert.strictEqual(tuner.parseNote('E2'), 40);
  assert.strictEqual(tuner.parseNote('C4'), 60);
  assert.strictEqual(tuner.parseNote('Eb2'), 39);
  assert.strictEqual(tuner.parseNote('F#3'), 54);
  assert.strictEqual(tuner.parseNote('a1'), 33);
  assert.strictEqual(tuner.parseNote('H2'), null);
  assert.strictEqual(tuner.parseNote(''), null);
  near(tuner.midiToFrequency(69), 440, 1e-9, 'A4');
  near(tuner.midiToFrequency(40), 82.4069, 1e-3, 'E2');
  near(tuner.midiToFrequency(33), 55, 1e-9, 'A1');
  near(tuner.midiToFrequency(69, 432), 432, 1e-9, 'A4 at 432');
  const d = tuner.describe(446, 440);
  assert.deepStrictEqual([d.name, d.octave, d.midi], ['A', 4, 69]);
  near(d.cents, 23.45, 0.05, 'cents sharp');
  const low = tuner.describe(81.5);
  assert.deepStrictEqual([low.name, low.octave], ['E', 2]);
  assert.ok(low.cents < 0);
});

test('tunings: every preset reads cleanly', () => {
  assert.ok(tunings.length >= 17);
  const ids = new Set();
  for (const t of tunings) {
    assert.ok(!ids.has(t.id), 'duplicate id ' + t.id); ids.add(t.id);
    const r = tuner.resolveTuning(t, 440);
    assert.strictEqual(r.strings.length, t.instrument === 'ukulele' ? 4 : 6, t.id);
    for (const s of r.strings) assert.ok(s.midi !== null && s.frequency > 40 && s.frequency < 600, t.id + ' ' + s.note);
  }
});

// Every distinct note across every tuning, at both common sample rates, in tune and 20 cents out.
const NOTES = [...new Set(tunings.flatMap(t => t.strings))].map(n => ({ note: n, midi: tuner.parseNote(n) }))
  .sort((a, b) => a.midi - b.midi);

test('detect: clean plucks land within 1.5 cents, for every string of every tuning', () => {
  let worst = 0;
  for (const rate of [44100, 48000]) {
    for (const { note, midi } of NOTES) {
      for (const offset of [-20, 0, 20]) {
        const truth = tuner.midiToFrequency(midi) * Math.pow(2, offset / 1200);
        const r = tuner.detectPitch(tuner.synthString(truth, rate, 4096), rate);
        assert.ok(r, `${note} @${rate} ${offset}c not detected`);
        const err = Math.abs(tuner.centsBetween(r.frequency, truth));
        worst = Math.max(worst, err);
        assert.ok(err <= 1.5, `${note} @${rate} ${offset}c off by ${err.toFixed(2)} cents (read ${r.frequency.toFixed(2)} Hz)`);
        assert.ok(r.clarity >= 0.85, `${note} clarity ${r.clarity}`);
      }
    }
  }
  console.log('    worst clean error: ' + worst.toFixed(3) + ' cents over ' + NOTES.length + ' notes');
});

test('detect: a laptop-mic pluck (weak fundamental, hiss) still lands within 3 cents', () => {
  let worst = 0;
  for (const rate of [44100, 48000]) {
    for (const { note, midi } of NOTES) {
      const truth = tuner.midiToFrequency(midi) * Math.pow(2, 7 / 1200);
      const r = tuner.detectPitch(tuner.synthString(truth, rate, 4096, { weakFundamental: true, noise: 0.02 }), rate);
      assert.ok(r, `${note} @${rate} not detected`);
      const err = Math.abs(tuner.centsBetween(r.frequency, truth));
      worst = Math.max(worst, err);
      assert.ok(err <= 3, `${note} @${rate} off by ${err.toFixed(2)} cents (read ${r.frequency.toFixed(2)} Hz, wanted ${truth.toFixed(2)})`);
    }
  }
  console.log('    worst laptop-mic error: ' + worst.toFixed(3) + ' cents');
});

test('detect: silence and hiss give nothing', () => {
  assert.strictEqual(tuner.detectPitch(new Array(4096).fill(0), 44100), null);
  let seed = 7; const hiss = [];
  for (let i = 0; i < 4096; i++) { seed = (seed * 48271) % 2147483647; hiss.push((seed / 2147483647 * 2 - 1) * 0.3); }
  const r = tuner.detectPitch(hiss, 44100);
  assert.ok(r === null || r.clarity < 0.85, 'hiss must not look like a note');
  assert.strictEqual(tuner.detectPitch([0.1, 0.2], 44100), null);
});

test('strings: nearest string, honest about how far off it is', () => {
  const std = tuner.resolveTuning(tunings.find(t => t.id === 'guitar-standard'), 440);
  let m = tuner.matchString(110.0 * Math.pow(2, 12 / 1200), std);
  assert.deepStrictEqual([m.index, m.note], [1, 'A2']); near(m.cents, 12, 0.01, 'A string cents');
  m = tuner.matchString(329.63, std); assert.deepStrictEqual([m.index, m.note], [5, 'E4']);
  m = tuner.matchString(55.0, std);   // a slack new string on its way up: must NOT read as "A2, in tune"
  assert.strictEqual(m.note, 'E2'); near(m.cents, -700, 1, 'slack string');
  m = tuner.matchString(98.0, std); assert.strictEqual(m.note, 'A2'); near(m.cents, -200, 1, 'two semitones flat');
  const uke = tuner.resolveTuning(tunings.find(t => t.id === 'ukulele-standard'), 440);
  m = tuner.matchString(392.0, uke); assert.deepStrictEqual([m.index, m.note], [0, 'G4']);
  m = tuner.matchString(261.63 * Math.pow(2, -30 / 1200), uke); assert.strictEqual(m.note, 'C4'); near(m.cents, -30, 0.1, 'uke C flat');
  const lowG = tuner.resolveTuning(tunings.find(t => t.id === 'ukulele-low-g'), 440);
  m = tuner.matchString(196.0, lowG); assert.deepStrictEqual([m.index, m.note], [0, 'G3']);
});

test('session: smooths, locks after a steady moment, holds briefly, then idles', () => {
  const std = tuner.resolveTuning(tunings.find(t => t.id === 'guitar-standard'), 440);
  const s = tuner.newSession();
  const E2 = std.strings[0].frequency;
  const reading = cents => ({ frequency: E2 * Math.pow(2, cents / 1200), clarity: 0.97, rms: 0.2 });

  assert.strictEqual(tuner.feed(s, null, 0, std, 440).state, 'idle');
  let d = tuner.feed(s, reading(-18), 100, std, 440);
  assert.deepStrictEqual([d.state, d.label, d.stringIndex, d.inTune], ['listening', 'E2', 0, false]); near(d.cents, -18, 0.01, 'first');
  tuner.feed(s, reading(-16), 150, std, 440);
  d = tuner.feed(s, reading(60), 200, std, 440);           // one wild reading must not move the needle much
  near(d.cents, -16, 0.01, 'median ignores the outlier');

  d = tuner.feed(s, reading(2), 900, std, 440);             // older readings have aged out of the window
  near(d.cents, 2, 0.01, 'fresh window'); assert.strictEqual(d.inTune, false, 'not locked yet');
  d = tuner.feed(s, reading(1), 1100, std, 440); assert.strictEqual(d.inTune, false);
  d = tuner.feed(s, reading(-1), 1300, std, 440); assert.strictEqual(d.inTune, true, 'locked after 350 ms in tolerance');

  d = tuner.feed(s, null, 1500, std, 440);
  assert.deepStrictEqual([d.state, d.label, d.inTune], ['holding', 'E2', true]);
  d = tuner.feed(s, { frequency: E2, clarity: 0.4, rms: 0.2 }, 1600, std, 440); assert.strictEqual(d.state, 'holding', 'unclear readings are ignored');
  d = tuner.feed(s, { frequency: E2, clarity: 0.99, rms: 0.001 }, 1700, std, 440); assert.strictEqual(d.state, 'holding', 'quiet readings are ignored');
  d = tuner.feed(s, null, 2600, std, 440); assert.strictEqual(d.state, 'idle');

  d = tuner.feed(s, { frequency: 110, clarity: 0.95, rms: 0.2 }, 2700, std, 440);
  assert.deepStrictEqual([d.label, d.stringIndex], ['A2', 1], 'from idle, the first reading takes over at once');

  // One stray reading of another string changes nothing. Two in a row do.
  d = tuner.feed(s, { frequency: 147, clarity: 0.95, rms: 0.2 }, 2750, std, 440); assert.strictEqual(d.label, 'A2', 'stray reading ignored');
  d = tuner.feed(s, { frequency: 110.5, clarity: 0.95, rms: 0.2 }, 2800, std, 440); assert.strictEqual(d.label, 'A2');
  d = tuner.feed(s, { frequency: 147, clarity: 0.95, rms: 0.2 }, 2850, std, 440); assert.strictEqual(d.label, 'A2', 'count restarts after an interruption');
  d = tuner.feed(s, { frequency: 147.2, clarity: 0.95, rms: 0.2 }, 2900, std, 440); assert.deepStrictEqual([d.label, d.stringIndex], ['D3', 2]);

  const c = tuner.newSession();                                                     // chromatic mode
  d = tuner.feed(c, { frequency: 446, clarity: 0.95, rms: 0.2 }, 0, null, 440);
  assert.deepStrictEqual([d.label, d.octave, d.stringIndex], ['A', 4, null]); near(d.cents, 23.45, 0.05, 'chromatic cents');
});

test('session: says so once when every string has locked, and only once', () => {
  const uke = tuner.resolveTuning(tunings.find(t => t.id === 'ukulele-standard'), 440);
  const s = tuner.newSession();
  let now = 0, fired = 0;
  const hold = (index) => {
    let last;
    for (let i = 0; i < 6; i++) { now += 100; last = tuner.feed(s, { frequency: uke.strings[index].frequency, clarity: 0.97, rms: 0.2 }, now, uke, 440); if (last.allInTuneNow) fired++; }
    return last;
  };
  hold(0); hold(1); hold(2);
  assert.strictEqual(fired, 0, 'three of four strings is not done');
  hold(3);
  assert.strictEqual(fired, 1, 'fires when the fourth string locks');
  hold(0); hold(3);
  assert.strictEqual(fired, 1, 'never fires twice in one session');
});

test('write tuner fixtures', () => {
  const dir = path.join(__dirname, '..', 'fixtures');
  const notes = NOTES.map(({ note, midi }) => ({ note, midi, frequency: tuner.midiToFrequency(midi, 440) }));
  const std = tuner.resolveTuning(tunings.find(t => t.id === 'guitar-standard'), 440);
  const uke = tuner.resolveTuning(tunings.find(t => t.id === 'ukulele-standard'), 440);
  const stringCases = [[82.0, 'guitar-standard'], [111.3, 'guitar-standard'], [330.5, 'guitar-standard'], [196.0, 'ukulele-standard'],
    [255.0, 'ukulele-standard'], [441.0, 'ukulele-standard'], [61.0, 'guitar-drop-b'], [56.2, 'guitar-drop-a']].map(([freq, id]) => {
    const r = tuner.resolveTuning(tunings.find(t => t.id === id), 440);
    const m = tuner.matchString(freq, r);
    return { frequency: freq, tuning: id, index: m.index, note: m.note, cents: m.cents };
  });
  const s = tuner.newSession();
  const script = [[null, 0], [-18, 100], [-16, 150], [60, 200], [2, 900], [1, 1100], [-1, 1300], [null, 1500], [null, 2600], [4, 2700], [9, 2750], [3, 2800], ['A', 2850], [2, 2900], ['A', 2950], ['A', 3000]];
  const E2 = std.strings[0].frequency;
  const session = script.map(([cents, at]) => {
    const reading = cents === null ? null
      : cents === 'A' ? { frequency: 110.4, clarity: 0.97, rms: 0.2 }
      : { frequency: E2 * Math.pow(2, cents / 1200), clarity: 0.97, rms: 0.2 };
    const d = tuner.feed(s, reading, at, std, 440);
    return { reading, at, display: d };
  });
  fs.writeFileSync(path.join(dir, 'tuner.json'), JSON.stringify({ tunings, notes, stringCases, session }, null, 2));
  assert.ok(uke.strings.length === 4);
});
