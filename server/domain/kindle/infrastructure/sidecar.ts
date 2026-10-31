/** Where a Kindle sidecar says the reader is.
 *
 *  A sidecar is a Palm database of type `BPARMOBI`: the offset of its first
 *  record sits at 0x4e, and that record, tagged `BPAR`, holds the position 12
 *  bytes in. Amazon documents none of it: the field was found on a real account
 *  and checked against what its Kindle showed. Its other records hold the
 *  reader's highlights, so nothing here is ever logged. Undefined on a file of any
 *  other shape, or one holding no position. */
const RECORD_OFFSET = 0x4e
const POSITION_OFFSET = 0x0c
const NO_POSITION = 0xffffffff

export const positionIn = (sidecar: Buffer): number | undefined => {
  if (sidecar.length < RECORD_OFFSET + 4) return undefined
  const record = sidecar.readUInt32BE(RECORD_OFFSET)
  if (sidecar.length < record + POSITION_OFFSET + 4) return undefined
  if (sidecar.toString('latin1', record, record + 4) !== 'BPAR') return undefined
  const position = sidecar.readUInt32BE(record + POSITION_OFFSET)
  return position === NO_POSITION ? undefined : position
}
