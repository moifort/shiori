import { describe, expect, test } from 'bun:test'

import { slugify, withoutAccents } from '~/utils/slug'

/** What slugify answered before its accent folding moved into `withoutAccents`
 *  (2026-11-14). It keys shared documents — series catalogues, authors,
 *  watches — so not one character of it may move. */
const KEYS: [string, string][] = [
  ["L'Assassin royal", 'assassin-royal'],
  ['Assassin Royal', 'assassin-royal'],
  ['Le Seigneur des Anneaux', 'seigneur-des-anneaux'],
  ['Les Mis\u00e9rables', 'miserables'],
  ['Les  Mis\u00e9rables ', 'miserables'],
  ['\u00c8ve', 'eve'],
  ['\u0152uvre compl\u00e8te', 'uvre-complete'],
  ['Stra\u00dfe', 'stra-e'],
  ['\u00c6sir', 'sir'],
  ['\u00c7a', 'ca'],
  ['H\u00e9l\u00e8ne Cixous', 'helene-cixous'],
  ['Jean-Paul Sartre', 'jean-paul-sartre'],
  ['\u00c9mile Zola', 'emile-zola'],
  ['The Lord of the Rings', 'lord-of-the-rings'],
  ['A Game of Thrones', 'game-of-thrones'],
  ['An Ember in the Ashes', 'ember-in-the-ashes'],
  ['Un Bonheur insoutenable', 'bonheur-insoutenable'],
  ['Une saison', 'saison'],
  ['Des souris et des hommes', 'souris-et-des-hommes'],
  ['Du c\u00f4t\u00e9 de chez Swann', 'cote-de-chez-swann'],
  ['De la d\u00e9mocratie', 'la-democratie'],
  ['L\u2019\u00c9tranger', 'etranger'],
  ['l\u2019homme', 'homme'],
  ['Rock^n roll', 'rock-n-roll'],
  ['Pa`rt', 'pa-rt'],
  ['Ce\u00b4dric', 'ce-dric'],
  ['Na\u00a8ive', 'na-ive'],
  ['l\u00b7l', 'l'],
  ['Cat\u00b7al\u00e0', 'cat-ala'],
  ['\u30ca\u30eb\u30c8', ''],
  ['\u30ac\u30f3\u30c0\u30e0', ''],
  ['\u30ef\u30f3\u30d4\u30fc\u30b9', ''],
  ['\u30fc', ''],
  ['\u9b3c\u6ec5\u306e\u5203', ''],
  ['\u041f\u0440\u0438\u0432\u0435\u0442 \u043c\u0438\u0440', ''],
  ['\u0395\u03bb\u03bb\u03b7\u03bd\u03b9\u03ba\u03ac', ''],
  ['\u05e2\u05d1\u05e8\u05d9\u05ea', ''],
  ['\u0627\u0644\u0639\u0631\u0628\u064a\u0629', ''],
  ['\u0110or\u0111e', 'or-e'],
  ['\u0141\u00f3d\u017a', 'odz'],
  ['S\u00f8ren Kierkegaard', 's-ren-kierkegaard'],
  ['\u00c5ngstr\u00f6m', 'angstrom'],
  ['\u00d1and\u00fa', 'nandu'],
  ['na\u00efve caf\u00e9', 'naive-cafe'],
  ['r\u00e9sum\u00e9', 'resume'],
  ['cr\u00e8me br\u00fbl\u00e9e', 'creme-brulee'],
  ['DUNE', 'dune'],
  ['Dune 2', 'dune-2'],
  ['One Piece, tome 5', 'one-piece-tome-5'],
  ['1984', '1984'],
  ['  spaced  out  ', 'spaced-out'],
  ['---', ''],
  ['', ''],
  ["L'", 'l'],
  ['Les', 'les'],
  ['the', 'the'],
  ['Thea', 'thea'],
  ['Lesbos', 'lesbos'],
  ['Anne', 'anne'],
  ['Dee', 'dee'],
  ['Red Rising [French Edition]', 'red-rising-french-edition'],
  ['Harry Potter (Tome 1)', 'harry-potter-tome-1'],
  ['\u1e60\u1e6b\u1e59\u0227\u1e45\u0121\u1e17', 'strange'],
  ['\u01c5emal', 'emal'],
  ['\ufb01nancial', 'nancial'],
  ['\u216b', ''],
  ['\u2460\u2461', ''],
  ['\uff26\uff55\uff4c\uff4c', ''],
  ['\u00c6', ''],
  ['x\u0302 \u0233', 'x-y'],
  ['a\u0301b\u1dc0c\u20d0d\ufe20e', 'ab-c-d-e'],
  ['\u1e9e', ''],
  ['\u0130stanbul', 'istanbul'],
]

describe('slugify', () => {
  test('keys every spelling exactly as it always has', () => {
    for (const [value, key] of KEYS) expect([value, slugify(value)]).toEqual([value, key])
  })
})

describe('withoutAccents', () => {
  test('drops the accents and keeps the letters', () => {
    expect(withoutAccents('Hélène Ève crème brûlée Ñandú')).toBe('Helene Eve creme brulee Nandu')
  })

  // Only the combining marks go: a spacing accent or a middle dot stays a
  // character of its own, which slugify turns into a separator.
  test('leaves the spacing marks', () => {
    expect(withoutAccents('Pa`rt l·l')).toBe('Pa`rt l·l')
  })
})
