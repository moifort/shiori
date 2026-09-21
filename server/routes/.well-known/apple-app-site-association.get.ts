/**
 * What tells iOS that this host's invitation links belong to Shiori.
 *
 * Without it an invitation link opens Safari and the reader has to copy a code
 * across by hand; with it, tapping the link opens the app on the invitation
 * itself. Apple fetches this file from its own CDN, over HTTPS, following no
 * redirects and expecting `application/json` — which is why it is served from
 * the API rather than from a static host Shiori does not have.
 *
 * `paths` is scoped to `/invite/*` on purpose: `/graphql` and everything else
 * this server answers must keep opening in a browser.
 *
 * The bundle identifier and the team are the app's, and a build signed with any
 * other pair silently stops matching — there is no error, links simply open the
 * web page again.
 */
const APP_ID = '46C337T7YN.com.polyforms.shiori.app'

export default defineEventHandler((event) => {
  setResponseHeader(event, 'content-type', 'application/json')
  // Apple re-reads this rarely, and a stale copy only costs a web page instead
  // of the app. A day is short enough to recover from a mistake the same day.
  setResponseHeader(event, 'cache-control', 'public, max-age=86400')
  return {
    applinks: {
      apps: [],
      details: [{ appID: APP_ID, paths: ['/invite/*'] }],
    },
  }
})
