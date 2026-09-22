import type { Brand } from 'ts-brand'

export type UserId = Brand<string, 'UserId'>
/** What an account is entitled to. `free` is everyone's starting point and the
 *  only state that needs no proof; `premium` is a verified App Store purchase. */
export type Plan = 'free' | 'premium'
export type Eur = Brand<number, 'Eur'>
export type Year = Brand<number, 'Year'>
export type Month = Brand<string, 'Month'>
export type Count = Brand<number, 'Count'>
export type Percentage = Brand<number, 'Percentage'>
/** A title and an author name are spoken by both `book` and `series`: a catalogue
 *  lists volume titles, a book carries its own. They live here so neither domain
 *  has to import the other's vocabulary. */
export type BookTitle = Brand<string, 'BookTitle'>
export type AuthorName = Brand<string, 'AuthorName'>
/** A person the reader knows, by name: the reader's own first name, asked for
 *  once during onboarding so the app can address them, or the friend who
 *  recommended them a book. Distinct from AuthorName, which names someone who
 *  wrote a book. */
export type PersonName = Brand<string, 'PersonName'>
/** One to five whole stars, given to a book or to a saga. Half stars double the
 *  value space without adding discernment, and shrink the touch target. */
export type StarRating = Brand<number, 'StarRating'>
