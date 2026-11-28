# The standby brief

What the parent session sends a standby (`B1`, `B2`…) when it starts or recycles it. The parent
sends one line, "You are standby BN of Shiori: read `docs/reserve-brief.md` and wait", rather than
this whole text. The rules behind it are Workflow rules 5 to 13 of [CLAUDE.md](../CLAUDE.md) and
[board.md](board.md).

**Do nothing now.** Answer in one line that you are waiting, then wait for a mission sent by the
parent: a board comment, a UI request, a bug, a study.

**No Android work until the user says so explicitly** (his decision of 2026-11-28): iOS and server
only, never touch `android/`, no Android build, capture or port. If a change has an Android
counterpart, name it in your report and leave it: the nightly catch-up on pi6
(`shiori-android-catch-up`, 4:00) ports every iOS commit of `main` to Android in one pull
request, so no Android patch needs saving either.

**Speak French to the user, always**: messages, reports, end-of-turn recaps, questions, button
labels. Only code, comments, commits and versioned docs are in English.

When a mission arrives, read CLAUDE.md (Workflow rules 5 to 13) and docs/board.md, then:

- **Where you work.** On `main`, unless the parent says another session already changes code:
  then in your own worktree `build/wt-bN`, on your own branch, built with
  `-derivedDataPath <worktree>/build/dd` and the main DerivedData's `SourcePackages`. The iOS
  validation then reads « Valider et fusionner dans main »; on that yes you rebase, fast-forward
  `main`, and remove the worktree and the branch.
- **A UI change is validated twice.** Board first (the link is in board.md), a capture sent with
  `SendUserFile`, a « Valider » question in your wrap-up. iOS only after that yes, an iPhone
  capture, a second validation. Every validation ask comes with a capture of the board as it
  stands now, sent in the same turn: a new edit means a new capture before asking again.
- **Captures on the iPhone first**: `scripts/device-capture.sh <screen> [light|dark] <out.png>`
  (the iPhone section of [ios-guide.md](ios-guide.md#captures-the-iphone-first-the-simulator-as-fallback)),
  iOS unit tests run on the iPhone as well (`-destination 'id=<udid>' -only-testing:ShioriTests`,
  same section), under both locks.
- **An iOS build in a worktree** needs two gitignored things first: copy
  `ios/Shiori/GoogleService-Info.plist` from the main checkout (without it the app crashes at
  launch), and regenerate the Apollo code with the CLI that matches the Apollo package (2.2.0):
  `cd ios && ~/.cache/apollo-cli/apollo-ios-cli generate` — `apollo-ios-cli` is not on PATH, and
  `build/apollo-cli/` holds 2.5.0, which Apollo 2.2.0 refuses.
- **Never boot the iOS simulator.** Since 2026-11-25 it crashes SpringBoard at boot or at app
  launch, even started through DeviceHub (16 crash reports on 2026-11-26 alone). Until the user
  says otherwise: iPhone only. iPhone unplugged → verify by build, unit-test compilation and
  previews, say plainly that no capture or test run was possible, and ask the parent; do not fall
  back to the simulator.
- **One turn per result.** Chain your steps in one turn; end a turn only when you have something
  to show the user or a question for them, never after each small step.
- **Board threads.** Resolve a thread without replying as soon as the change is made. Handle new
  comments on your theme and no other: the rest goes to the parent. Keep no auto-replying board
  watch: turn it off after each publish (`ArtifactComments`, `watch`, `on: false`).
- **A bug is looked for elsewhere** before its fix is done (rule 11).
- **Never**: edit `android/`, touch the changelogs, push without the user's "push", launch a
  subagent, use Chrome. Commit without asking, with an explicit pathspec.
- **When the user gives the final validation**, send the parent "Réserve libérée : <title>" with
  the commits, what is merged, and what is left open, then stop. Never archive yourself.
