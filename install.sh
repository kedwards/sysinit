# #!/bin/bash

# set -euo pipefail

# SYSINIT_REPO=https://github.com/withreach/sysinit.git

# # Determine script directory with fallback
# # If run via stdin (e.g., curl ... | bash)
# # or if sourced or run as file
# if [[ -p /dev/stdin ]]; then
#   script_dir="$HOME/sysinit"
# elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
#   script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
# else
#   script_dir="$(dirname "$(realpath "$0")")"
# fi

# cleanup() {
#   if command -v deactivate >/dev/null; then
#     deactivate || true
#   fi
#   sudo rm -rf "$script_dir/.venv" "${mise_installer:-/tmp}/mise_install.sh" || true
# }
# trap cleanup ERR EXIT

# # Detect packages based on os type
# get_packages_for_pm() {
#   local pm="$1"
#   case "$pm" in
#   apt-get)
#     echo "curl git gpg"
#     ;;
#   pacman)
#     echo "curl git gnupg"
#     ;;
#   yum)
#     echo "curl git gnupg2"
#     ;;
#   *)
#     echo "curl git gnupg"
#     ;;
#   esac
# }

# # === Detect Package Manager ===
# get_package_manager() {
#   declare -A os_info=(
#     ["/etc/redhat-release"]="yum"
#     ["/etc/arch-release"]="pacman"
#     ["/etc/debian_version"]="apt-get"
#   )
#   for f in "${!os_info[@]}"; do
#     if [[ -f "$f" ]]; then
#       echo "${os_info[$f]}"
#       return
#     fi
#   done
#   echo "unknown"
# }

# # Install required packages
# install_packages() {
#   local pm
#   pm=$(get_package_manager)
#   local packages
#   packages=$(get_packages_for_pm "$pm")

#   case "$pm" in
#   apt-get)
#     sudo apt-get update
#     sudo apt-get upgrade -y
#     sudo apt-get install -y $packages
#     sudo apt-get autoremove -y
#     ;;
#   pacman)
#     sudo pacman -Syu --noconfirm
#     sudo pacman -S --noconfirm $packages
#     ;;
#   yum)
#     sudo yum update -y
#     sudo yum install -y $packages
#     ;;
#   *)
#     echo "Unsupported or unknown package manager"
#     exit 1
#     ;;
#   esac
# }

# # Install mise and add
# # mise to PATH and activate
# install_mise() {
#   mise_installer="$(mktemp -d)"
#   gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 0x7413A06D
#   curl https://mise.jdx.dev/install.sh.sig | gpg --decrypt >"$mise_installer/mise_install.sh"
#   sh "$mise_installer/mise_install.sh"
#   export PATH="$HOME/.local/bin:$PATH"
#   echo "eval \"\$($HOME/.local/bin/mise activate bash)\"" >>~/.bashrc
#   eval "$("$HOME/.local/bin/mise" activate bash)"
# }

# # Clone or pull sysinit repo
# sync_repo() {
#   if [[ -d "$script_dir" ]]; then
#     # @TODO: save users changes if any
#     git -C "$script_dir" pull
#   else
#     git clone -b main --single-branch $SYSINIT_REPO "$script_dir"
#   fi
# }

# # Set up virtual environment
# # and install dependencies
# setup_python_env() {
#   cd "$script_dir"
#   mise trust -a
#   mise use --global uv
#   uv venv --clear
#   # shellcheck disable=SC1091
#   source ".venv/bin/activate"
#   uv pip install -e .
# }

# # Setup SSH agent for GitHub access
# setup_ssh_agent() {
#   local ssh_env="$HOME/.ssh/agent-env"

#   echo "Setting up SSH agent for Ansible..."

#   # Start SSH agent if not running
#   if [ -f "$ssh_env" ]; then
#     source "$ssh_env" >/dev/null
#     if ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
#       echo "Starting new SSH agent..."
#       ssh-agent >"$ssh_env"
#       chmod 600 "$ssh_env"
#       source "$ssh_env" >/dev/null
#     else
#       echo "SSH agent already running (PID: $SSH_AGENT_PID)"
#     fi
#   else
#     echo "Starting SSH agent..."
#     ssh-agent >"$ssh_env"
#     chmod 600 "$ssh_env"
#     source "$ssh_env" >/dev/null
#   fi

#   # Check if keys are loaded
#   if ! ssh-add -l >/dev/null 2>&1; then
#     echo "No SSH keys loaded. Attempting to add keys..."

#     # Try to add keys
#     for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519; do
#       if [ -f "$key" ]; then
#         echo "Adding key: $key"
#         if ssh-add "$key"; then
#           echo "Successfully added $key"
#           break
#         else
#           echo "Failed to add $key (wrong passphrase or other error)"
#         fi
#       fi
#     done

#     # Check again if keys are loaded
#     if ! ssh-add -l >/dev/null 2>&1; then
#       echo "No SSH keys are loaded in the agent."
#       echo "Please manually add your key:"
#       echo "  source $ssh_env && ssh-add ~/.ssh/id_rsa"
#       echo "Then run this script again."
#       exit 1
#     fi
#   else
#     echo "SSH keys are loaded:"
#     ssh-add -l
#   fi

#   # Export environment for Ansible
#   export SSH_AUTH_SOCK
#   export SSH_AGENT_PID
# }

# # Run ansible playbook
# run_ansible() {
#   echo ""
#   echo "🚀 Running Ansible playbook..."
#   ansible-playbook playbook.yml -K
# }

# # Main
# install_packages
# install_mise
# # sync_repo
# setup_python_env
# setup_ssh_agent
# run_ansible

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

# Check and collect required Git configuration
setup_git_config() {
  echo "Checking Git configuration..."

  # Check for environment variables first
  GIT_USER_NAME="${GIT_USER_NAME:-$(git config --global user.name 2>/dev/null || true)}"
  GIT_USER_EMAIL="${GIT_USER_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"
  GIT_SIGNING_KEY="${GIT_SIGNING_KEY:-$(git config --global user.signingkey 2>/dev/null || true)}"

  # Prompt for missing required values
  if [ -z "$GIT_USER_NAME" ]; then
    read -p "Enter your Git user name: " GIT_USER_NAME
  fi

  if [ -z "$GIT_USER_EMAIL" ]; then
    read -p "Enter your Git email: " GIT_USER_EMAIL
  fi

  # Signing key is optional
  if [ -z "$GIT_SIGNING_KEY" ]; then
    read -p "Enter your Git signing key (optional, press Enter to skip): " GIT_SIGNING_KEY
  fi

  # Validate required fields
  if [ -z "$GIT_USER_NAME" ] || [ -z "$GIT_USER_EMAIL" ]; then
    echo "Error: Git user name and email are required"
    exit 1
  fi

  # Export for use in ansible
  export GIT_USER_NAME
  export GIT_USER_EMAIL
  export GIT_SIGNING_KEY

  echo "Git configuration set:"
  echo "  Name: $GIT_USER_NAME"
  echo "  Email: $GIT_USER_EMAIL"
  echo "  Signing Key: ${GIT_SIGNING_KEY:-<not set>}"
}

# Set up virtual environment
# and install dependencies
# setup_python_env() {
#   cd "$script_dir"
  
#   # Ensure mise is in PATH and activated
#   export PATH="$HOME/.local/bin:$PATH"
#   if command -v mise >/dev/null 2>&1; then
#     eval "$(mise activate bash)"
#   else
#     echo "Error: mise not found in PATH"
#     exit 1
#   fi
  
#   # Trust the .mise.toml file
#   mise trust -a
  
#   # Install uv globally if not already installed
#   mise use --global uv
  
#   # Wait a moment for mise to set up the environment
#   sleep 1
  
#   # Verify uv is available
#   if ! command -v uv >/dev/null 2>&1; then
#     echo "Error: uv not available after mise setup"
#     exit 1
#   fi
  
#   # Create virtual environment
#   uv venv --clear
  
#   # Activate virtual environment
#   # shellcheck disable=SC1091
#   source ".venv/bin/activate"
  
#   # Install dependencies
#   uv pip install -e .
# }


setup_python_env() {
  cd "$script_dir"
  
  # Ensure mise is in PATH and activated
  export PATH="$HOME/.local/bin:$PATH"
  if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
  else
    echo "Error: mise not found in PATH"
    exit 1
  fi
  
  # Trust the .mise.toml file
  mise trust -a
  
  # Install uv globally if not already installed
  echo "Installing uv via mise..."
  mise use --global uv
  
  # Refresh mise environment to pick up newly installed tools
  eval "$(mise activate bash)"
  
  # Add mise shims to PATH explicitly
  export PATH="$HOME/.local/share/mise/shims:$PATH"
  
  # Wait a moment and try to refresh mise
  sleep 2
  mise reshim
  
  # Verify uv is available, with multiple attempts
  local attempts=0
  local max_attempts=5
  
  while [ $attempts -lt $max_attempts ]; do
    if command -v uv >/dev/null 2>&1; then
      echo "✅ uv is available"
      break
    fi
    
    echo "⏳ Waiting for uv to be available (attempt $((attempts + 1))/$max_attempts)..."
    sleep 1
    eval "$(mise activate bash)"
    export PATH="$HOME/.local/share/mise/shims:$PATH"
    attempts=$((attempts + 1))
  done
  
  # Final check
  if ! command -v uv >/dev/null 2>&1; then
    echo "Error: uv not available after mise setup"
    echo "Debugging information:"
    echo "PATH: $PATH"
    echo "mise list:"
    mise list || true
    echo "mise which uv:"
    mise which uv || true
    echo "Checking common uv locations:"
    ls -la "$HOME/.local/share/mise/installs/uv/" 2>/dev/null || echo "No uv installs found"
    exit 1
  fi
  
  # Create virtual environment
  echo "Creating virtual environment..."
  uv venv --clear
  
  # Activate virtual environment
  # shellcheck disable=SC1091
  source ".venv/bin/activate"
  
  # Install dependencies
  echo "Installing dependencies..."
  uv pip install -e .
}

# Setup SSH agent for GitHub access
setup_ssh_agent() {
  local ssh_env="$HOME/.ssh/agent-env"

  echo "Setting up SSH agent for Ansible..."

  # Ensure .ssh directory exists
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  # Kill any existing ssh-agent if running
  if [ -f "$ssh_env" ]; then
    source "$ssh_env" >/dev/null 2>&1 || true
    if [ -n "${SSH_AGENT_PID:-}" ] && kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
      echo "Killing existing SSH agent (PID: $SSH_AGENT_PID)"
      kill "$SSH_AGENT_PID" 2>/dev/null || true
    fi
  fi

  # Start fresh SSH agent
  echo "Starting new SSH agent..."
  ssh-agent > "$ssh_env"
  chmod 600 "$ssh_env"
  
  # Source the agent environment
  # shellcheck disable=SC1090
  source "$ssh_env" >/dev/null
  
  # Verify agent is running
  if [ -z "${SSH_AGENT_PID:-}" ] || ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
    echo "Error: Failed to start SSH agent"
    exit 1
  fi
  
  echo "SSH agent started (PID: $SSH_AGENT_PID)"

  # Look for SSH keys to add
  local keys_found=false
  local keys_added=false
  
  for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519 ~/.ssh/id_ecdsa; do
    if [ -f "$key" ]; then
      keys_found=true
      echo "Found SSH key: $key"
      
      # Check if key is encrypted
      if grep -q "ENCRYPTED" "$key" 2>/dev/null; then
        echo "Key $key is encrypted, prompting for passphrase..."
      fi
      
      # Try to add the key
      if ssh-add "$key" 2>/dev/null; then
        echo "Successfully added $key"
        keys_added=true
        break
      else
        echo "Failed to add $key (may need passphrase or key is invalid)"
      fi
    fi
  done

  # Check if any keys were found
  if [ "$keys_found" = false ]; then
    echo "No SSH keys found in ~/.ssh/"
    echo "Please generate an SSH key pair:"
    echo "  ssh-keygen -t ed25519 -C \"your_email@example.com\""
    echo "Then run this script again."
    exit 1
  fi

  # Check if any keys were successfully added
  if [ "$keys_added" = false ]; then
    echo "No SSH keys could be loaded. This might be due to:"
    echo "  - Encrypted keys requiring passphrase"
    echo "  - Invalid or corrupted key files"
    echo "  - Permission issues"
    echo ""
    echo "Please manually add your key:"
    echo "  source $ssh_env"
    echo "  ssh-add ~/.ssh/id_ed25519  # or your key file"
    echo "Then run this script again."
    exit 1
  fi

  # Verify keys are loaded
  echo "Loaded SSH keys:"
  ssh-add -l

  # Export environment for Ansible
  export SSH_AUTH_SOCK
  export SSH_AGENT_PID
  
  # Also export to a file that can be sourced later
  cat > "$HOME/.ssh/current-agent" << EOF
export SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
export SSH_AGENT_PID="$SSH_AGENT_PID"
EOF
  chmod 600 "$HOME/.ssh/current-agent"
}

# Run ansible playbook
run_ansible() {
  echo ""
  echo "🚀 Running Ansible playbook..."
  ansible-playbook playbook.yml -K \
    -e "git_user_name=${GIT_USER_NAME}" \
    -e "git_user_email=${GIT_USER_EMAIL}" \
    -e "git_signing_key=${GIT_SIGNING_KEY}"
}

# Main execution with better error handling
main() {
  echo "🚀 Starting sysinit installation..."
  
  echo "📦 Installing system packages..."
  install_packages
  
  echo "🔧 Installing mise..."
  install_mise
  
  # Uncomment when ready to sync repo
  # echo "📁 Syncing repository..."
  # sync_repo
  
  echo "🔧 Setting up Git configuration..."
  setup_git_config
  
  echo "🐍 Setting up Python environment..."
  setup_python_env
  
  echo "🔐 Setting up SSH agent..."
  setup_ssh_agent
  
  echo "⚡ Running Ansible playbook..."
  run_ansible
  
  echo "✅ Installation complete!"
}

# Run main function
main "$@"