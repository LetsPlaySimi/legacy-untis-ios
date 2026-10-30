#!/bin/sh
# One-time setup: put your own name / GitHub user into the project files.
# usage: scripts/configure.sh <github-user> "<Your Name>" <you@example.com>
set -e
if [ $# -ne 3 ]; then echo 'usage: scripts/configure.sh <github-user> "<Your Name>" <you@example.com>'; exit 1; fi
cd "$(dirname "$0")/.."
USER_="$1"; NAME_="$2"; MAIL_="$3"
LC=$(echo "$USER_" | tr 'A-Z' 'a-z')
for f in README.md control Resources/Info.plist layout/DEBIAN/postinst docs/index.html; do
    sed -i -e "s|YOURNAME|$USER_|g" -e "s|yourname|$LC|g" \
           -e "s|Your Name <you@example.com>|$NAME_ <$MAIL_>|g" "$f"
done
echo "Done. Bundle/package id is now io.github.$LC.legacyuntis"
