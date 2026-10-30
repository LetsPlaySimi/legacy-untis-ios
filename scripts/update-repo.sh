#!/bin/sh
# Rebuilds the Cydia repo index in docs/ from the .deb files in packages/.
# Run after `make package`. Needs: dpkg-dev (dpkg-scanpackages), bzip2, gzip.
set -e
cd "$(dirname "$0")/.."
mkdir -p docs/debs
cp -f packages/*.deb docs/debs/
cd docs
dpkg-scanpackages -m debs /dev/null > Packages 2>/dev/null
bzip2 -kf Packages
gzip -9 -c Packages > Packages.gz
echo "Repo updated:"
grep -E "^(Package|Version|Filename):" Packages
echo "Now commit and push: git add -A && git commit -m 'Update repo' && git push"
