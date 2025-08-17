#!/usr/bin/env bash

script_directory=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
pushd "$script_directory/dotfiles"

#mapfile -t apps < <(find . -maxdepth 1 -type d -not -path '.' -exec basename {} \;)
#for app in "${apps[@]}"; do
#  stow --restow --target="$app" -d "${script_directory}/dot_files/${app}"
#done

# stow configs
stow --restow --target="$HOME" *

MARKER="# sysinit: load custom profile settings"

# Check if the snippet already exists
if grep -Fq "$MARKER" ~/.bashrc; then
  echo "Snippet already exists in ~/.bashrc"
  exit 0
fi

# Append the snippet
cat <<"EOF" >> ~/.bashrc
# ${MARKER}
if [ -d "$HOME/.profile.d" ]; then
  # Files to exclude from sourcing
  exclude_list=(
    "$HOME/.profile.d/secret"
  )
  
  for profile_file in "$HOME"/.profile.d/*; do
    # Skip if not a regular readable file
    [ -f "$profile_file" ] && [ -r "$profile_file" ] || continue
    
    # Skip hidden files (.something)
    [[ "$(basename "$profile_file")" == .* ]] && continue

    # Skip if file is in exclude_list
    if printf '%s\n' "${exclude_list[@]}" | grep -Fxq "$profile_file"; then
      continue
    fi

    source "$profile_file"
  done
fi
EOF

popd