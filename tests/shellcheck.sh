#!/usr/bin/env bash
set -ev

if [ -z "${TRAVIS_COMMIT_RANGE}" ]; then
  changed_sh_files=$(git diff --name-only HEAD~1 | grep .sh)
else
  changed_sh_files=$(git diff --name-only "${TRAVIS_COMMIT_RANGE}" | grep .sh)
fi

if [ -z "${changed_sh_files}" ]; then
  echo "no shell scripts were changed in this pull request"
else
  shellcheck "${changed_sh_files}"
fi
