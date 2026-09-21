/**
 * The page an invitation link opens.
 *
 * A reader shares a link rather than a bare code, because a link is what people
 * send each other. Whoever taps it may not have Shiori, may be on a laptop, may
 * not know what any of this is — so the link lands here rather than nowhere, and
 * this page says what to do next.
 *
 * It is public on purpose and it gives nothing away: the code is already in the
 * URL of whoever is reading, and the page never names the reader who made the
 * invitation or says a word about their library. Opening it does not spend the
 * code either — only `acceptFriendInvitation` does, from inside the app, signed
 * in as the person taking it up.
 */
const escaped = (value: string) =>
  value.replace(/[<>&"']/g, (char) =>
    char === '<'
      ? '&lt;'
      : char === '>'
        ? '&gt;'
        : char === '&'
          ? '&amp;'
          : char === '"'
            ? '&quot;'
            : '&#39;',
  )

export default defineEventHandler((event) => {
  // Only the shape is checked here, never whether it names a live invitation:
  // answering "no such code" to an unauthenticated visitor would turn this page
  // into a way of testing codes.
  const raw = getRouterParam(event, 'code') ?? ''
  const code = /^[A-Za-z0-9]{8}$/.test(raw) ? raw.toUpperCase() : ''

  setResponseHeader(event, 'content-type', 'text/html; charset=utf-8')
  setResponseHeader(event, 'cache-control', 'no-store')
  // Nothing here is meant to be framed, and the code should not ride along to
  // anywhere else the reader clicks from this page.
  setResponseHeader(event, 'x-frame-options', 'DENY')
  setResponseHeader(event, 'referrer-policy', 'no-referrer')

  return `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Invitation Shiori</title>
<style>
  :root { color-scheme: light dark; }
  body {
    margin: 0; min-height: 100vh; display: grid; place-items: center;
    font: 17px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
    background: #faf7f2; color: #1c1b19;
  }
  @media (prefers-color-scheme: dark) { body { background: #16150f; color: #f2efe9; } }
  main { max-width: 32rem; padding: 2rem 1.5rem; text-align: center; }
  h1 { font-size: 1.5rem; margin: 0 0 .75rem; }
  p { margin: 0 0 1.25rem; opacity: .75; }
  .code {
    font: 700 2rem/1 ui-monospace, SFMono-Regular, Menlo, monospace;
    letter-spacing: .25em; padding: 1rem 1.25rem; border-radius: .75rem;
    background: rgba(127,127,127,.12); display: inline-block; margin-bottom: 1.5rem;
  }
  ol { text-align: left; margin: 0 auto; max-width: 24rem; padding-left: 1.25rem; }
  li { margin-bottom: .5rem; }
</style>
</head>
<body>
<main>
  <h1>Une bibliothèque vous est ouverte</h1>
  <p>Quelqu'un vous invite à partager sa bibliothèque sur Shiori, et à voir la sienne.</p>
  ${code ? `<div class="code">${escaped(code)}</div>` : "<p>Ce lien est incomplet : demandez qu'on vous le renvoie.</p>"}
  <ol>
    <li>Installez Shiori sur votre iPhone, si ce n'est pas déjà fait.</li>
    <li>Ouvrez les réglages de l'application, puis « Amis ».</li>
    <li>Touchez « J'ai reçu une invitation » et collez ce code.</li>
  </ol>
</main>
</body>
</html>`
})
