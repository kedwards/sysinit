#!/bin/bash

set -euo pipefail

SYSINIT_REPO=https://github.com/withreach/sysinit.git

# Determine script directory with fallback
# If run via stdin (e.g., curl ... | bash)
# or if sourced or run as file
if [[ -p /dev/stdin ]]; then
  script_dir="$HOME/sysinit"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
else
  script_dir="$(dirname "$(realpath "$0")")"
fi

cleanup() {
  if command -v deactivate >/dev/null; then
    deactivate || true
  fi
  sudo rm -rf "$script_dir/.venv" "${mise_installer:-/tmp}/mise_install.sh" || true
}
trap cleanup ERR EXIT

# Detect packages based on os type
get_packages_for_pm() {
  local pm="$1"
  case "$pm" in
  apt-get)
    echo "curl git gpg"
    ;;
  pacman)
    echo "curl git gnupg"
    ;;
  yum)
    echo "curl git gnupg2"
    ;;
  *)
    echo "curl git gnupg"
    ;;
  esac
}

# === Detect Package Manager ===
get_package_manager() {
  declare -A os_info=(
    ["/etc/redhat-release"]="yum"
    ["/etc/arch-release"]="pacman"
    ["/etc/debian_version"]="apt-get"
  )
  for f in "${!os_info[@]}"; do
    if [[ -f "$f" ]]; then
      echo "${os_info[$f]}"
      return
    fi
  done
  echo "unknown"
}

# Install required packages
install_packages() {
  local pm
  pm=$(get_package_manager)
  local packages
  packages=$(get_packages_for_pm "$pm")

  case "$pm" in
  apt-get)
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get install -y $packages
    sudo apt-get autoremove -y
    ;;
  pacman)
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm $packages
    ;;
  yum)
    sudo yum update -y
    sudo yum install -y $packages
    ;;
  *)
    echo "Unsupported or unknown package manager"
    exit 1
    ;;
  esac
}

# Install mise and add
# mise to PATH and activate
install_mise() {
  mise_installer="$(mktemp -d)"
  gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 0x7413A06D
  curl https://mise.jdx.dev/install.sh.sig | gpg --decrypt >"$mise_installer/mise_install.sh"
  sh "$mise_installer/mise_install.sh"
  export PATH="$HOME/.local/bin:$PATH"
  echo "eval \"\$($HOME/.local/bin/mise activate bash)\"" >>~/.bashrc
  eval "$("$HOME/.local/bin/mise" activate bash)"
}

# Clone or pull sysinit repo
sync_repo() {
  if [[ -d "$script_dir" ]]; then
    git -C "$script_dir" pull
  else
    git clone -b main --single-branch $SYSINIT_REPO "$script_dir"
  fi
}

# Set up virtual environment
# and install dependencies
setup_python_env() {
  cd "$script_dir"
  mise trust -a
  mise use --global uv
  uv venv --clear
  # shellcheck disable=SC1091
  source ".venv/bin/activate"
  uv pip install -e .
}

# Run ansible playbook
run_ansible() {
  ansible-playbook playbook.yml -K
}

# Main
install_packages
install_mise
sync_repo
setup_python_env
run_ansible
