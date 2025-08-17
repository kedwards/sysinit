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
    # @TODO: save users changes if any
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

# Setup SSH agent for GitHub access
setup_ssh_agent() {
  local ssh_env="$HOME/.ssh/agent-env"

  echo "Setting up SSH agent for Ansible..."

  # Start SSH agent if not running
  if [ -f "$ssh_env" ]; then
    source "$ssh_env" >/dev/null
    if ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
      echo "Starting new SSH agent..."
      ssh-agent >"$ssh_env"
      chmod 600 "$ssh_env"
      source "$ssh_env" >/dev/null
    else
      echo "SSH agent already running (PID: $SSH_AGENT_PID)"
    fi
  else
    echo "Starting SSH agent..."
    ssh-agent >"$ssh_env"
    chmod 600 "$ssh_env"
    source "$ssh_env" >/dev/null
  fi

  # Check if keys are loaded
  if ! ssh-add -l >/dev/null 2>&1; then
    echo "No SSH keys loaded. Attempting to add keys..."

    # Try to add keys
    for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519; do
      if [ -f "$key" ]; then
        echo "Adding key: $key"
        if ssh-add "$key"; then
          echo "Successfully added $key"
          break
        else
          echo "Failed to add $key (wrong passphrase or other error)"
        fi
      fi
    done

    # Check again if keys are loaded
    if ! ssh-add -l >/dev/null 2>&1; then
      echo "No SSH keys are loaded in the agent."
      echo "Please manually add your key:"
      echo "  source $ssh_env && ssh-add ~/.ssh/id_rsa"
      echo "Then run this script again."
      exit 1
    fi
  else
    echo "SSH keys are loaded:"
    ssh-add -l
  fi

  # Export environment for Ansible
  export SSH_AUTH_SOCK
  export SSH_AGENT_PID
}

# Run ansible playbook
run_ansible() {
  echo ""
  echo "🚀 Running Ansible playbook..."
  ansible-playbook playbook.yml -K
}

# Main
install_packages
install_mise
# sync_repo
setup_python_env
setup_ssh_agent
run_ansible
