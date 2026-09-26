import { describe, expect, test } from 'bun:test'
import { ObjectPath, SignedUrl } from '~/system/object-store/primitives'
import { reusingSignatures } from '~/system/object-store/signatures'

const MINUTE = 60 * 1000

const setup = (capacity = 100) => {
  let clock = 0
  let signed = 0
  const sign = async (path: string) => {
    signed += 1
    return SignedUrl(`https://signed.test/${path}?n=${signed}`)
  }
  const downloadUrl = reusingSignatures(sign, { now: () => clock, capacity })
  return {
    downloadUrl,
    advance: (ms: number) => {
      clock += ms
    },
    signed: () => signed,
  }
}

describe('reusingSignatures', () => {
  test('signs a path once and hands the same URL back while it has time left', async () => {
    const { downloadUrl, advance, signed } = setup()
    const first = await downloadUrl(ObjectPath('covers/a.jpg'))
    advance(44 * MINUTE)
    expect(await downloadUrl(ObjectPath('covers/a.jpg'))).toBe(first)
    expect(signed()).toBe(1)
  })

  test('signs again once the URL would expire too soon to be worth handing out', async () => {
    const { downloadUrl, advance, signed } = setup()
    const first = await downloadUrl(ObjectPath('covers/a.jpg'))
    advance(46 * MINUTE)
    expect(await downloadUrl(ObjectPath('covers/a.jpg'))).not.toBe(first)
    expect(signed()).toBe(2)
  })

  test('two requests for the same path at once share one signature', async () => {
    const { downloadUrl, signed } = setup()
    const [left, right] = await Promise.all([
      downloadUrl(ObjectPath('covers/a.jpg')),
      downloadUrl(ObjectPath('covers/a.jpg')),
    ])
    expect(left).toBe(right)
    expect(signed()).toBe(1)
  })

  test('a failed signature is not kept', async () => {
    let fail = true
    const downloadUrl = reusingSignatures(
      async (path) => {
        if (fail) throw new Error('IAM unavailable')
        return SignedUrl(`https://signed.test/${path}`)
      },
      { now: () => 0 },
    )
    await expect(downloadUrl(ObjectPath('covers/a.jpg'))).rejects.toThrow('IAM unavailable')
    fail = false
    expect(await downloadUrl(ObjectPath('covers/a.jpg'))).toBe(
      SignedUrl('https://signed.test/covers/a.jpg'),
    )
  })

  test('forgets the oldest path past its capacity', async () => {
    const { downloadUrl, signed } = setup(2)
    await downloadUrl(ObjectPath('covers/a.jpg'))
    await downloadUrl(ObjectPath('covers/b.jpg'))
    await downloadUrl(ObjectPath('covers/c.jpg'))
    await downloadUrl(ObjectPath('covers/c.jpg'))
    await downloadUrl(ObjectPath('covers/b.jpg'))
    expect(signed()).toBe(3)
    await downloadUrl(ObjectPath('covers/a.jpg'))
    expect(signed()).toBe(4)
  })
})
