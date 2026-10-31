import { describe, expect, test } from 'bun:test'
import { positionIn } from '~/domain/kindle/infrastructure/sidecar'

const aSidecar = (position: number, tag = 'BPAR') => {
  const file = Buffer.alloc(0x60 + 0x38)
  file.writeUInt32BE(0x60, 0x4e)
  file.write(tag, 0x60, 'latin1')
  file.writeUInt32BE(position, 0x60 + 0x0c)
  return file
}

describe('the position in a sidecar', () => {
  test('is read off its first record', () => {
    expect(positionIn(aSidecar(310049))).toBe(310049)
  })

  test('is absent where the file says none', () => {
    expect(positionIn(aSidecar(0xffffffff))).toBeUndefined()
  })

  test('is absent from a file of another shape', () => {
    expect(positionIn(aSidecar(310049, 'DATA'))).toBeUndefined()
    expect(positionIn(Buffer.alloc(20))).toBeUndefined()
  })
})
