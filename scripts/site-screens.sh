#!/usr/bin/env bash
#
# The landing page's pictures of the app, cut from the App Store captures
# (scripts/screenshots.sh): whole screens for the iPhones, and parts of them
# for the feature cards, so that every picture of the app is the app itself,
# its type and its colours as iOS draws them.
#
#   scripts/site-screens.sh
#
# Run after a capture run; the files land in site/screens/.
set -euo pipefail

cd "$(dirname "$0")/.."

SCREENS="00-scan 01-library 02-home 02-stats 03-series 05-discover 06-shared 08-discover-more 10-discover-series 11-search 12-cover"

# name, capture, then the part as y x height width, in the capture's pixels
# (1320x2868), and the language when the two captures differ. Each part is
# the app's white card alone, cut on its edges: the page draws its rounded
# corners and its shadow, so none of the screen's grey shows around it. The
# challenge and the discoveries are cut inside their edges (23 and 30 pixels),
# clear of their rounded corners, and the page gives the margin back.
PARTS=(
  "series 03-series 683 60 507 1200"
  "authors 09-authors 683 60 465 1200"
  "stats 02-home 1174 48 608 1224"
  "hearts 08-discover-more 1110 60 607 1200"
  "challenge 06-shared 1606 83 572 1154 fr"
  "challenge 06-shared 1606 83 512 1154 en"
  "discoveries 05-discover 534 90 816 1140"
)

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for lang in fr en; do
  from="screenshots/captures/$lang"
  for shot in $SCREENS; do
    sips -Z 1434 -s format jpeg -s formatOptions 60 "$from/$shot.png" \
      --out "site/screens/$lang-$shot.jpg" >/dev/null
  done
  for part in "${PARTS[@]}"; do
    read -r name shot y x height width only <<<"$part"
    [[ -n "$only" && "$only" != "$lang" ]] && continue
    sips -c "$height" "$width" --cropOffset "$y" "$x" "$from/$shot.png" \
      --out "$work/$name.png" >/dev/null
    # Full width: a card draws it at up to 600 points, sharp on a Retina screen.
    sips -s format jpeg -s formatOptions 70 "$work/$name.png" \
      --out "site/screens/$lang-part-$name.jpg" >/dev/null
  done
done
ls site/screens
