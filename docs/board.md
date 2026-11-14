# The Shiori Board

How the design board and the iOS app stay in sync, and how a comment on the board is handled.
The comment workflow itself (rules 5–8) is in [CLAUDE.md](../CLAUDE.md#workflow); this page is
the rest of the board's working rules.

## What the board is

"The board" / "the canvas" is the **Shiori Board**, a Design (canvas) artifact:
https://claude.ai/artifact/LEGLY8VDYdRDs7gc2dsrhn. It is neither a design-system artifact (the
"Shiori" design systems were deleted on 2026-10-28) nor the SwiftUI previews.

- One `project/<Name>.dc.html` artboard per screen: home (`Accueil-*`), library (`Lib-*`), book
  pages (`Fiche-*`), onboarding (`Onboarding-*`) on the page "App"; variants `V-*`.
- Layout lives in `project/canvas.json` (`boards`, `order`). A new artboard sits 80 px from its
  siblings in the same row, with its `boards` entry and `order` slot.

## Board first, then code

SwiftUI and the board are always in sync.

- A requested UI change is drawn on the board first, then sent as a capture.
- **Outside the prototyping zone** (`Zone-Prototypage.dc.html`, page "App"): the change goes all
  the way to iOS in the same task — board edit, capture, SwiftUI, simulator screenshot, commit.
- **Inside the prototyping zone**: board-only exploration until the user says to build it.
- A change that lands in code by another route (a fix, a refactor) is mirrored on the board in
  the same task.
- **One element, every screen**: changing a badge, label, button or component on one artboard
  means changing it on every artboard that shows it.
- A scrolling screen is ONE artboard drawn at its full length (root height, `$preview` and
  `boards` `h` set to the whole page), never split into a top and a "bas de page" artboard.
- A rail holding a single card draws it full width (353 px on a 393 px phone), as iOS does.
- A prod component is drawn from its SwiftUI source and a real capture, never copied from an
  older artboard, which may lag.

## Validated prototype = production screen

Once the user validates a prototype and it is built on iOS, it leaves the prototyping zone in the
same task:

- the retained design becomes a production artboard on the page "App", next to its sibling
  screens (as a full screen, not cropped), drawn from the SwiftUI source and a real capture;
- every other variant of that prototype moves to the Variants page, marked as in the
  "Variants" section below, and is never touched again;
- the prototyping zone keeps only what is still being explored.

## Variants

- New variants and explorations go in the prototyping zone. The "Variants" page only archives
  shipped work: once built, a prototype's variants move there and are never touched again.
- A variant artboard shows only the part that varies (the hero, the card), cropped in root
  height, `$preview` and its `boards` `h`. Alternatives to one question stack in a column,
  80 px apart.
- Variants of a component are ONE artboard like `Bouton-ajout.dc.html`: black ground, a title, one
  section per option, the current one first, no phone mock. A phone mock only for page variants.
- Once the user picks a variant, mark it (3 px `#30d158` ring and a green "✓ Retenue" pill), then
  apply it to every artboard showing that element.

## Comment sessions

Rules 5–8 of CLAUDE.md: one child session per comment, started without asking, the child
resolves its thread and, on the user's validation, is cleared and re-briefed by the parent
if it was a standby (archived otherwise), the parent resolves the
thread of a child the user closed themself, only the parent listens to the board.

Why a child does not always start at once: a comment sent from the board reaches the parent as
an automated turn, not as the user's own message, and the app refuses to start a session
(`user_asked`) on such a turn, though it still lets the parent message an existing session. So
the parent keeps **standby sessions**, at least three free, titled `B1`, `B2`… (started empty, waiting for a
mission): on a comment with no child on its theme, it sends the full brief to a standby, which
becomes that thread's child at once (the parent renames it "BN · <theme>"). Once
the user validates its work, the standby sends "Réserve libérée : <title>"; the parent clears
its context (`clear_session`), renames it "BN · libre" and re-sends the standby
brief. A standby is never archived. On each of the user's messages the
parent first tops the free standbys back up to three (`list_sessions`, `linked: true`, also after a
clear). With no standby left, the parent proposes the child instead (`own_initiative`, a card
the user clicks). Over Remote Control the cards do not show and the app refuses the proposal
too: the parent then says so in one line starting with "⏸ Bloqué" that tells the user what to
do ("⏸ Bloqué : fil X en attente, envoie n'importe quel message ici pour lancer sa session"),
never a bare "waiting for its session". Either way, the user's next message in the parent,
whatever it says, is the go-ahead: the parent starts every waiting child first (`proposal_id`,
or `user_asked` with the same brief when nothing could be proposed), then answers the message.
It never asks for a keyword.

**The parent checks that every ticket it hands out is handled** (CLAUDE.md, Workflow rule 6).
A child often receives a ticket and never acts on it: the message waits in a queue, or it
handles one request out of several. The parent keeps the list of the tickets it sent (thread or
request, child, time). Each time a child ends a turn, and on each of the user's messages, it
checks every open ticket:

- against the child's transcript (`list_events`);
- against the thread (`ArtifactComments`, `read`);
- against the commits (`git log`).

A resolved thread is not proof on its own: the board must have been republished, or the commit
must exist. A ticket with no trace goes back to its child, and the user hears of it in one line.
A child that sends "Réserve libérée" with a ticket untouched is not cleared until that ticket is
handled.

## Capturing artboards

Artboards reference images as `/_blob/<id>`, served only by the board's frame origin.

1. In the built-in browser open the board, read `document.querySelector('iframe').src`.
2. In a second tab open that `_t` URL, then `https://<id>.frame.claudeusercontent.com/x`.
3. There, `fetch('/_f/<version>/project/<Name>.dc.html')`, drop the `support.js` line, put each
   file in an `iframe.srcdoc` sized to its `$preview`, and screenshot.

Every publish makes a new version and invalidates the token: repeat steps 1–2. Fresh PNG uploads
can answer 404 on the frame origin; publish them as support files under `project/` instead.
