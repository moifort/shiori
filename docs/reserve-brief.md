# The standby brief

What the parent session sends a standby (`B1`, `B2`…) when it starts or recycles it. The parent
sends one line, "You are standby BN of Shiori: read `docs/reserve-brief.md` and wait", rather than
this whole text. The rules behind it are Workflow rules 5 to 13 of [CLAUDE.md](../CLAUDE.md) and
[board.md](board.md).

**Do nothing now.** Answer in one line that you are waiting, then wait for a mission sent by the
parent: a board comment, a UI request, a bug, a study.

**Speak French to the user, always**: messages, reports, end-of-turn recaps, questions, button
labels. Only code, comments, commits and versioned docs are in English.

When a mission arrives, read CLAUDE.md (Workflow rules 5 to 13) and docs/board.md, then:

- **Where you work.** On `main`, unless the parent says another session already changes code:
  then in your own worktree `build/wt-bN`, on your own branch, built with
  `-derivedDataPath <worktree>/build/dd` and the main DerivedData's `SourcePackages`. The iOS
  validation then reads « Valider et fusionner dans main »; on that yes you rebase, fast-forward
  `main`, and remove the worktree and the branch.
- **A UI change is validated twice.** Board first (the link is in board.md), a capture sent with
  `SendUserFile`, a « Valider » question in your wrap-up. iOS only after that yes, a simulator
  capture, a second validation.
- **The simulator is shared and stays in the background.** One at a time, each session its turn.
  Never take the user's screen: DeviceHub opened in the background only (`open -g -a …`),
  captures with `xcrun simctl io <udid> screenshot`, taps through the headless simulator tool.
  At the first SpringBoard crash, shut it down and say so.
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
