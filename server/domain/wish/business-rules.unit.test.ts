import { describe, expect, test } from 'bun:test'
import { releaseKeyOf } from '~/domain/release/business-rules'
import { AuthorName, BookTitle } from '~/domain/shared/primitives'
import type { UserId } from '~/domain/shared/types'
import { releaseIdentityOf, releaseShownOf, wishIdOf } from '~/domain/wish/business-rules'
import type { Wish } from '~/domain/wish/types'

const wished = (overrides: Partial<Wish> = {}): Wish => {
  const book = { title: BookTitle('Piranesi'), authors: [AuthorName('Susanna Clarke')] }
  return {
    ...book,
    id: wishIdOf('bob' as UserId, book),
    userId: 'bob' as UserId,
    format: 'book',
    origin: { kind: 'friend', label: 'Camille' },
    wishedAt: new Date('2026-11-01'),
    ...overrides,
  }
}

describe('a wish described for its page', () => {
  test('shares the release of its edition, as any list showing it', () => {
    expect(releaseIdentityOf(wished({ language: 'fr' }), 'en').key).toBe(
      releaseKeyOf('Piranesi', 'Susanna Clarke', 'book', 'fr'),
    )
  })

  test('is described in the app’s language when it was wished in none', () => {
    expect(releaseIdentityOf(wished(), 'fr').language).toBe('fr')
  })

  test('is a recording’s release when a recording was wished for', () => {
    expect(releaseIdentityOf(wished({ format: 'audiobook' }), 'fr').format).toBe('audiobook')
  })

  test('is shown out, never looked for', () => {
    const shown = releaseShownOf(wished(), 'fr')
    expect(shown.state).toBe('available')
    expect(shown.watched).toBe(false)
  })

  test('is found as it was wished, for its store link', () => {
    expect(
      releaseShownOf(wished({ isbn13: '9782221251776' as Wish['isbn13'] }), 'fr').found,
    ).toEqual({
      title: BookTitle('Piranesi'),
      isbn13: '9782221251776' as Wish['isbn13'],
    })
  })
})
