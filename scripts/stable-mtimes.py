#!/usr/bin/env python3
"""Give the sources a modification time that depends on their content, not on the clock.

Xcode decides what to recompile from the time a file was last modified. A fresh checkout
stamps every file with the moment it was written, so a build on a new runner recompiles
everything, cached DerivedData or not. Run before the build, this script sets:

- every tracked file to the time of the last commit that touched it, read off the history
  (the checkout needs the commits and trees, not the blobs: `fetch-depth: 0` with
  `filter: blob:none`);
- every file under the paths given as arguments (gitignored files written during the
  job: generated code, materialized secrets) to a time derived from a hash of its
  content, so an identical file carries the same time on every runner and a changed
  file a different one.

Two runs on the same sources thus agree on every time, and the Swift driver, which
compares each input's time with the one it recorded, recompiles only what changed.
"""

import hashlib
import os
import subprocess
import sys


def root() -> str:
    return subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], text=True).strip()


def stamp_tracked_files(top: str) -> int:
    pending = set(
        subprocess.check_output(['git', 'ls-files', '-z'], cwd=top).decode().split('\0')
    )
    pending.discard('')
    # Newest commit first; `-m` lists what a merge brought in, so a file only ever
    # changed on a merged branch is found too. The same history gives the same times.
    log = subprocess.Popen(
        ['git', 'log', '-m', '--format=%x00%ct', '--name-only'],
        cwd=top, stdout=subprocess.PIPE, text=True,
    )
    stamped = 0
    when = None
    assert log.stdout is not None
    for line in log.stdout:
        line = line.rstrip('\n')
        if line.startswith('\0'):
            when = int(line[1:])
            continue
        if not line or line not in pending:
            continue
        pending.discard(line)
        os.utime(os.path.join(top, line), (when, when))
        stamped += 1
        if not pending:
            break
    log.stdout.close()
    log.terminate()
    return stamped


def content_time(path: str) -> int:
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for chunk in iter(lambda: handle.read(1 << 16), b''):
            digest.update(chunk)
    # Any second in 2020: in the past, so nothing looks newer than the build that
    # cached it, yet distinct for distinct contents.
    return 1_577_836_800 + int.from_bytes(digest.digest()[:4], 'big') % 31_536_000


def stamp_by_content(path: str) -> int:
    stamped = 0
    if os.path.isfile(path):
        when = content_time(path)
        os.utime(path, (when, when))
        return 1
    for folder, _, names in os.walk(path):
        for name in names:
            file = os.path.join(folder, name)
            when = content_time(file)
            os.utime(file, (when, when))
            stamped += 1
    return stamped


def main() -> None:
    top = root()
    tracked = stamp_tracked_files(top)
    generated = sum(stamp_by_content(path) for path in sys.argv[1:])
    print(f'{tracked} tracked files stamped from the history, {generated} from their content')


if __name__ == '__main__':
    main()
