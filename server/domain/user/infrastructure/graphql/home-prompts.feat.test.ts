import { beforeEach, describe, expect, mock, test } from 'bun:test'
import { graphql } from 'graphql'
import type { PersonName, UserId } from '~/domain/shared/types'
import type { UserProfile } from '~/domain/user/types'
import { type FakeFirestore, fakeDb, resetFakeFirestore } from '~/test/fake-firestore'

mock.module('~/system/firebase', () => ({ db: fakeDb }))

const { schema } = await import('~/domain/shared/graphql/schema')

const reader = 'reader' as UserId
let fake: FakeFirestore

beforeEach(() => {
  fake = resetFakeFirestore()
  const profile: UserProfile = {
    userId: reader,
    firstName: 'Thibaut' as PersonName,
    onboardingCompletedAt: new Date('2026-10-01'),
  }
  fake.seed('users', reader, profile)
})

const run = async (source: string, variableValues?: Record<string, unknown>) => {
  const result = await graphql({
    schema,
    source,
    contextValue: { event: {}, userId: reader },
    variableValues,
  })
  expect(result.errors).toBeUndefined()
  return result.data as Record<string, { homePrompts: string[] }>
}

const prompts = async () => (await run('{ me { homePrompts } }')).me?.homePrompts

const dismiss = (prompt: string, dismissed?: boolean) =>
  run(
    'mutation D($prompt: HomePrompt!, $dismissed: Boolean) { dismissHomePrompt(prompt: $prompt, dismissed: $dismissed) { homePrompts } }',
    { prompt, dismissed },
  )

describe('the home prompts', () => {
  test('ask a new reader for Audible, Kindle and a friend, in that order', async () => {
    expect(await prompts()).toEqual(['AUDIBLE', 'KINDLE', 'FRIENDS'])
  })

  test('leave out a connected account and a reader who has a friend', async () => {
    fake.seed('audible-connections', reader, { userId: reader, account: { marketplace: 'fr' } })
    fake.seed('friendships', 'f-1', { userIds: [reader, 'friend' as UserId] })

    expect(await prompts()).toEqual(['KINDLE'])
  })

  test('turned down, a prompt stays gone, and comes back when taken back', async () => {
    const after = await dismiss('KINDLE')
    expect(after.dismissHomePrompt?.homePrompts).toEqual(['AUDIBLE', 'FRIENDS'])
    expect(await prompts()).toEqual(['AUDIBLE', 'FRIENDS'])

    const back = await dismiss('KINDLE', false)
    expect(back.dismissHomePrompt?.homePrompts).toEqual(['AUDIBLE', 'KINDLE', 'FRIENDS'])
  })
})
