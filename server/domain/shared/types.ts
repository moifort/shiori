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
