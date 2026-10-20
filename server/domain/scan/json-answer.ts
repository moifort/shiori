/** Reading a model's answer as JSON when it could not be asked for JSON mode:
 *  a grounded step answers in free text, Gemini's and Claude's alike. */

/** Said as a description, because the model shown a bare schema sometimes
 *  answers with the schema itself. */
export const answerShape = (schema: unknown) =>
  `Réponds UNIQUEMENT par l'objet JSON demandé, sans aucun texte autour. Le schéma JSON ci-dessous décrit la forme de cet objet ; c'est une description, ne le recopie pas :
${JSON.stringify(schema)}`

/** The JSON object in an answer. JSON mode returns it bare; free text may fence
 *  it, say a word around it, repeat it, or close it with one brace too many —
 *  seen on September 27th 2026 — so the object read is the one that opens at
 *  the first brace and closes where its own braces balance, whatever follows.
 *  It may also explain itself in a block comment inside the object, as it did
 *  on September 28th 2026; the comment is dropped rather than paid for
 *  twice. */
export const answerOf = (text: string): unknown => {
  const start = text.indexOf('{')
  if (start === -1) throw new Error('Gemini answered without a JSON object')
  const json = withoutComments(text.slice(start))
  return JSON.parse(json.slice(0, closingBraceOf(json, 0) + 1))
}

/** The text with its block comments removed, those inside strings aside. */
const withoutComments = (json: string): string => {
  let kept = ''
  let inString = false
  for (let index = 0; index < json.length; index += 1) {
    const char = json[index]
    if (inString) {
      kept += char
      if (char === '\\') kept += json[++index] ?? ''
      else if (char === '"') inString = false
    } else if (char === '/' && json[index + 1] === '*') {
      const end = json.indexOf('*/', index + 2)
      if (end === -1) return kept
      index = end + 1
    } else {
      if (char === '"') inString = true
      kept += char
    }
  }
  return kept
}

/** Where the object opening at `start` closes, braces inside strings aside;
 *  the text's end when it never does, so that JSON.parse says what is wrong. */
const closingBraceOf = (text: string, start: number): number => {
  let depth = 0
  let inString = false
  for (let index = start; index < text.length; index += 1) {
    const char = text[index]
    if (inString) {
      if (char === '\\') index += 1
      else if (char === '"') inString = false
    } else if (char === '"') inString = true
    else if (char === '{') depth += 1
    else if (char === '}') {
      depth -= 1
      if (depth === 0) return index
    }
  }
  return text.length - 1
}
