import { invitationCodeOfLink, invitationPage, invitationPlatformOf } from '~/utils/invitation-page'

/**
 * The page an invitation link opens when the app does not: the App Store, the
 * code, and what to do next (`invitationPage` says why it looks the way it
 * does).
 *
 * It is public on purpose and opening it does not spend the code — only
 * `acceptFriendInvitation` does, from inside the app, signed in as the person
 * taking it up.
 */
export default defineEventHandler((event) => {
  const code = invitationCodeOfLink(getRouterParam(event, 'code') ?? '')
  const platform = invitationPlatformOf(getRequestHeader(event, 'user-agent') ?? '')

  setResponseHeader(event, 'content-type', 'text/html; charset=utf-8')
  setResponseHeader(event, 'cache-control', 'no-store')
  // The answer differs by device, so no cache in between may hand an iPhone's
  // page to an Android phone.
  setResponseHeader(event, 'vary', 'user-agent')
  // Nothing here is meant to be framed, and the code should not ride along to
  // the App Store or anywhere else the reader clicks from this page.
  setResponseHeader(event, 'x-frame-options', 'DENY')
  setResponseHeader(event, 'referrer-policy', 'no-referrer')

  return invitationPage(code, platform)
})
