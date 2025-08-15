#!/bin/bash
# Ansible Playbook Runner with SSH Agent
# This script ensures SSH agent is running and keys are loaded before running the playbook

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_ENV="$HOME/.ssh/agent-env"

echo "🔑 Setting up SSH agent for Ansible..."

# Start SSH agent if not running
if [ -f "$SSH_ENV" ]; then
    source "$SSH_ENV" > /dev/null
    if ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
        echo "Starting new SSH agent..."
        ssh-agent > "$SSH_ENV"
        chmod 600 "$SSH_ENV"
        source "$SSH_ENV" > /dev/null
    else
        echo "SSH agent already running (PID: $SSH_AGENT_PID)"
    fi
else
    echo "Starting SSH agent..."
    ssh-agent > "$SSH_ENV"
    chmod 600 "$SSH_ENV"
    source "$SSH_ENV" > /dev/null
fi

# Check if keys are loaded
if ! ssh-add -l >/dev/null 2>&1; then
    echo "🔐 No SSH keys loaded. Attempting to add keys..."
    
    # Try to add keys
    for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519; do
        if [ -f "$key" ]; then
            echo "Adding key: $key"
            if ssh-add "$key"; then
                echo "✅ Successfully added $key"
                break
            else
                echo "❌ Failed to add $key (wrong passphrase or other error)"
            fi
        fi
    done
    
    # Check again if keys are loaded
    if ! ssh-add -l >/dev/null 2>&1; then
        echo "❌ No SSH keys are loaded in the agent."
        echo "Please manually add your key:"
        echo "  source $SSH_ENV && ssh-add ~/.ssh/id_rsa"
        echo "Then run this script again."
        exit 1
    fi
else
    echo "✅ SSH keys are loaded:"
    ssh-add -l
fi

echo ""
echo "🚀 Running Ansible playbook..."
export SSH_AUTH_SOCK
export SSH_AGENT_PID

# Run the playbook with all arguments passed to this script
ansible-playbook playbook.yml "$@"
