#!/bin/sh
set -eu
umask 022
action=$1
live=$2
release=$3
store="${live%/*}/.${live##*/}-releases"
stage="$store/$release"
previous="$store/previous"

mkdir -p "$store"
if [ ! -e "$live" ] && [ -d "$previous" ]; then
  mv "$previous" "$live"
fi

case "$action" in
  prepare)
    mkdir "$stage"
    ;;
  publish)
    [ -f "$stage/index.html" ] || { echo "Incomplete upload" >&2; exit 1; }
    if [ -d "$previous" ]; then mv "$previous" "$store/archive-$release"; fi
    if [ -d "$live" ]; then mv "$live" "$previous"; fi
    if ! mv "$stage" "$live"; then
      if [ -d "$previous" ]; then mv "$previous" "$live"; fi
      exit 1
    fi
    ;;
  rollback)
    [ -f "$previous/index.html" ] || { echo "No previous release available" >&2; exit 1; }
    mv "$live" "$store/replaced-$release"
    if ! mv "$previous" "$live"; then
      mv "$store/replaced-$release" "$live"
      exit 1
    fi
    cat "$live/index.html"
    ;;
  *) echo "Unknown release action" >&2; exit 1 ;;
esac
