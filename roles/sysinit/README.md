sysinit
=======

Ansible role for system initialization and tool installation.

Requirements
------------

- Ansible 2.9+
- Target systems: Ubuntu, Debian, Arch Linux
- Internet connectivity for downloading tools
- GitHub API token (recommended for higher rate limits)

Role Variables
--------------

The following variables can be set to customize the role behavior:

### Core Variables

- `upgrade`: (boolean, default: `false`) - Forces reinstallation/upgrade of tools even if they already exist
- `github_token`: (string, optional) - GitHub API token for accessing release information

### AWS Vault Configuration

- `aws_vault_skip_github_api`: (boolean, default: `false`) - Skip GitHub API lookup and use fixed version
- `aws_vault_fixed_version`: (string, default: `"7.2.0"`) - Version to install when GitHub API is skipped

**Important Behavior Note**: When `upgrade: true` is set, AWS Vault will be downloaded and installed regardless of the `aws_vault_skip_github_api` setting. This means:
- If `aws_vault_skip_github_api: false` and `upgrade: true` → Uses latest version from GitHub API
- If `aws_vault_skip_github_api: true` and `upgrade: true` → Uses fixed version specified in `aws_vault_fixed_version`

### Mise Plugin Configuration

- `sysinit_mise_plugins`: List of mise plugins to install
- `sysinit_mise_custom_plugins`: List of custom mise plugin configurations

Dependencies
------------

- `community.general` collection for GitHub release lookups
- `ansible.builtin` modules

Example Playbook
----------------

Basic usage:

```yaml
- hosts: servers
  become: true
  roles:
    - sysinit
```

With custom configuration:

```yaml
- hosts: servers
  become: true
  vars:
    upgrade: true
    github_token: "{{ vault_github_token }}"
    aws_vault_skip_github_api: false
  roles:
    - sysinit
```

For CI/Testing environments (using fixed versions):

```yaml
- hosts: servers
  become: true
  vars:
    aws_vault_skip_github_api: true
    aws_vault_fixed_version: "7.2.0"
    upgrade: false  # Set to true to force reinstall with fixed version
  roles:
    - sysinit
```

License
-------

BSD

Author Information
------------------

An optional section for the role authors to include contact information, or a website (HTML is not allowed).
