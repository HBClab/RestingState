#!/usr/bin/env bash
set -ev

changed_sh_files=$(git diff --name-only $TRAVIS_COMMIT_RANGE | grep .sh)
if [ -z "${changed_sh_files}" ]; then
  echo "no shell scripts were changed in this pull request"
else
  shellcheck "${changed_sh_files}"
fi
