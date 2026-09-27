import { describe, expect, test } from 'bun:test'
import { amazonDateOf, amazonEditionFrom } from './parsing'

/** The book details carousel as an Amazon product page draws it. */
const page = (date: string, language: string) =>
  `<div class="a-section rpi-attribute-label"> <span>Date de publication</span> </div>
   <div class="a-section"> <span class="rpi-icon book_details-publication_date"></span> </div>
   <div class="a-section a-spacing-none a-text-center rpi-attribute-value"> <span>${date}</span> </div>
   <div class="a-section rpi-attribute-label"> <span>Langue</span> </div>
   <div class="a-section"> <span class="rpi-icon language"></span> </div>
   <div class="a-section a-spacing-none a-text-center rpi-attribute-value"> <span>${language}</span> </div>`

describe('an Amazon date', () => {
  test('is read in every store’s way of writing it', () => {
    expect(amazonDateOf('26 août 2021') as string).toBe('2021-08-26')
    expect(amazonDateOf('December 30, 2025') as string).toBe('2025-12-30')
    expect(amazonDateOf('1. März 2024') as string).toBe('2024-03-01')
    expect(amazonDateOf('8 de octubre de 2026') as string).toBe('2026-10-08')
    expect(amazonDateOf('2024/3/1') as string).toBe('2024-03-01')
    expect(amazonDateOf('bientôt')).toBeUndefined()
  })
})

describe('an Amazon book page', () => {
  test('gives the edition’s release day', () => {
    expect(amazonEditionFrom(page('8 octobre 2026', 'Français'), 'fr')).toEqual({
      releaseDate: '2026-10-08' as never,
    })
  })

  test('of a book in another language is not that edition', () => {
    expect(amazonEditionFrom(page('3 mars 2024', 'Anglais'), 'fr')).toBe('unknown')
  })

  test('with no book details, a captcha, is unreadable', () => {
    expect(amazonEditionFrom('<form action="/errors/validateCaptcha">', 'fr')).toBe('unreadable')
  })
})
