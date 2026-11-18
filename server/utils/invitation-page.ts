/**
 * The web page an invitation link lands on when the app does not open it.
 *
 * On an iPhone with Shiori installed the link never gets here: it is a
 * universal link, so iOS opens the app on the invitation. This page is what is
 * left — somebody without the app, on a laptop or an Android phone, or in an
 * app whose in-app browser swallowed the universal link — so it sends them to
 * the App Store. That one button serves the last case too: the App Store sees
 * Shiori installed and offers to open it, so no separate `shiori://` button.
 *
 * The store is a button, never an automatic redirect: inside WhatsApp or
 * Instagram the universal link does not fire even with the app installed, and
 * sending those readers to the store would be wrong.
 *
 * It gives nothing away: the code is already in the URL of whoever is reading,
 * and the page never names the reader who made the invitation. No cookie, no
 * script, nothing that follows the visitor.
 */

export const APP_STORE_URL = 'https://apps.apple.com/app/id6811938144'

/** Where the page is read, which decides what it offers. Shiori is not on
 *  Google Play yet, so an Android phone is told so rather than sent nowhere. */
export type InvitationPlatform = 'iphone' | 'android' | 'desktop'

/** The platform a user agent names. An iPad in desktop mode reports itself as a
 *  Mac and is read as a desktop, which still shows the App Store button. */
export const invitationPlatformOf = (userAgent: string): InvitationPlatform =>
  /iPhone|iPad|iPod/.test(userAgent) ? 'iphone' : /Android/.test(userAgent) ? 'android' : 'desktop'

/** The code a link carries, or undefined when it is not one. Only the shape is
 *  checked, never whether it names a live invitation: answering "no such code"
 *  to an unauthenticated visitor would turn this page into a way of testing
 *  codes. */
export const invitationCodeOfLink = (raw: string): string | undefined =>
  /^[A-Za-z0-9]{8}$/.test(raw) ? raw.toUpperCase() : undefined

const escaped = (value: string) =>
  value.replace(
    /[<>&"']/g,
    (char) =>
      ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' })[char] ?? char,
  )

const APPLE_MARK =
  '<svg class="apple-mark" viewBox="0 0 17 20" width="22" height="26" aria-hidden="true"><path fill="currentColor" d="M14.2 10.6c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.9-3.5.9-.7 0-1.8-.8-3-.8-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.4 1.2 0 1.6-.8 3.1-.8 1.4 0 1.8.8 3.1.7 1.3 0 2.1-1.1 2.8-2.3.9-1.3 1.3-2.6 1.3-2.7-.1 0-2.7-1-2.7-3.7ZM11.9 3.8c.6-.8 1.1-1.9 1-3-.9 0-2.1.6-2.7 1.4-.6.7-1.1 1.8-1 2.9 1 .1 2.1-.5 2.7-1.3Z"/></svg>'

/** The App Store badge, the one the project site already uses. */
const storeBadge = `<a class="store-badge" href="${APP_STORE_URL}" aria-label="Télécharger dans l'App Store">
    ${APPLE_MARK}
    <span class="store-text"><small>Télécharger dans</small><b>App Store</b></span>
  </a>`

const stepsFor = (platform: InvitationPlatform) =>
  platform === 'android'
    ? `<p class="note">Shiori n'existe pas encore sur Android : il arrive bientôt sur Google Play.</p>`
    : `<ol>
    ${platform === 'desktop' ? '<li>Ouvrez ce lien sur votre iPhone.</li>' : ''}
    <li>Installez Shiori depuis l'App Store, si ce n'est pas déjà fait.</li>
    <li>Rouvrez ce lien : l'application s'ouvrira sur l'invitation.</li>
    <li>Sinon, dans les réglages, « Amis », « J'ai reçu une invitation », et collez ce code.</li>
  </ol>`

export const invitationPage = (code: string | undefined, platform: InvitationPlatform): string => {
  const body = code
    ? `${platform === 'android' ? '' : storeBadge}
  <div class="code">${escaped(code)}</div>
  ${stepsFor(platform)}`
    : `<p>Ce lien est incomplet : demandez qu'on vous le renvoie.</p>
  ${platform === 'android' ? '' : storeBadge}`

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
  p { margin: 0 0 1.5rem; opacity: .75; }
  .store-badge {
    display: inline-flex; align-items: center; gap: 10px; height: 50px;
    padding: 0 18px 0 14px; border-radius: 12px; background: #000; color: #fff;
    text-decoration: none; box-shadow: 0 10px 30px rgba(0,0,0,.18);
  }
  @media (prefers-color-scheme: dark) { .store-badge { background: #fff; color: #000; } }
  .apple-mark { display: block; flex: none; margin-top: -3px; }
  .store-text { display: flex; flex-direction: column; align-items: flex-start; line-height: 1; text-align: left; }
  .store-text small { font-size: 10px; letter-spacing: .02em; margin-bottom: 3px; opacity: .9; }
  .store-text b { font-size: 19px; font-weight: 600; letter-spacing: -.01em; }
  .code {
    font: 700 2rem/1 ui-monospace, SFMono-Regular, Menlo, monospace;
    letter-spacing: .25em; padding: 1rem 1.25rem; border-radius: .75rem;
    background: rgba(127,127,127,.12); display: inline-block; margin: 1.75rem 0 1.5rem;
  }
  ol { text-align: left; margin: 0 auto; max-width: 24rem; padding-left: 1.25rem; }
  li { margin-bottom: .5rem; }
  .note { margin: 0; }
</style>
</head>
<body>
<main>
  <h1>Une bibliothèque vous est ouverte</h1>
  <p>Quelqu'un vous invite à partager sa bibliothèque sur Shiori, et à voir la sienne.</p>
  ${body}
</main>
</body>
</html>`
}
