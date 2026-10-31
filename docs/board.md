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
- A prod component is drawn from its SwiftUI source and a real capture, never copied from an
  older artboard, which may lag.

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

Rules 5–8 of CLAUDE.md: one child session per comment, started without asking (a card when the
app refuses the start from an automated turn), the child resolves its thread and archives
itself on the user's validation, only the parent listens to the board.

## Capturing artboards

Artboards reference images as `/_blob/<id>`, served only by the board's frame origin.

1. In the built-in browser open the board, read `document.querySelector('iframe').src`.
2. In a second tab open that `_t` URL, then `https://<id>.frame.claudeusercontent.com/x`.
3. There, `fetch('/_f/<version>/project/<Name>.dc.html')`, drop the `support.js` line, put each
   file in an `iframe.srcdoc` sized to its `$preview`, and screenshot.

Every publish makes a new version and invalidates the token: repeat steps 1–2. Fresh PNG uploads
can answer 404 on the frame origin; publish them as support files under `project/` instead.
