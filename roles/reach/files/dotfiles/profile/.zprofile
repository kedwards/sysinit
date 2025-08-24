#!/usr/bin/env zsh

# load profile scripts
if [ -d ~/.profile.d ]; then
  for i in ~/.profile.d/*; do
    if [ -f "$i" ]; then
      source $i
    fi
  done
fi
