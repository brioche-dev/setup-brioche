#!/usr/bin/env bash
set -euo pipefail

# Validate environment variables
if [ -z "${GITHUB_PATH:-}" ] || [ -z "${GITHUB_ACTION_PATH:-}" ]; then
    echo '::error::$GITHUB_PATH or $GITHUB_ACTION_PATH not set! This script should be run in GitHub Actions'
    exit 1
fi
if [ -z "${HOME:-}" ]; then
    echo '::error::$HOME must be set'
    exit 1
fi

# Set BRIOCHE_INSTALL_BIN_DIR using 'install-bin-dir' (expanding $HOME)
if [ -n "${install_bin_dir:-}" ]; then
    export BRIOCHE_INSTALL_BIN_DIR="${install_bin_dir/'$HOME'/$HOME}"
elif [ -n "${install_dir:-}" ]; then
    # If the deprecated 'install-dir' is set, use it to set the install bin dir.
    # For backwards compatibility, we also expand env vars using `envsubst`.

    case "$install_dir" in
        *'$'* )
            # Ensure the `envsubst` command exists
            if ! type envsubst >/dev/null; then
                echo '::error::envsubst is required to expand env vars in $install_dir'
                exit 1
            fi

            # Get each referenced env var, and validate each one is not empty
            envsubst -v "$install_dir" | while read -r env_var; do
                if [ -z "${!env_var:-}" ]; then
                    echo "::error::env var \$${env_var} is not set (used in \$install_dir)"
                    exit 1
                fi
            done

            # Expand each env var
            install_dir="$(echo "$install_dir" | envsubst)"

            # Ensure the result is not empty
            if [ -z "$install_dir" ]; then
                echo '::error::$install_dir expanded to empty string'
                exit 1
            fi

            ;;
    esac

    export BRIOCHE_INSTALL_BIN_DIR="${install_bin_dir/'$HOME'/$HOME}"
fi

# Set BRIOCHE_INSTALL_ROOT using 'install-root' (expanding $HOME)
if [ -n "${install_root:-}" ]; then
    # Replace '$HOME' with $HOME
    export BRIOCHE_INSTALL_ROOT="${install_root/'$HOME'/$HOME}"
fi

# Set other installer options
export BRIOCHE_INSTALL_VERSION="${version:-}"
export BRIOCHE_INSTALL_APPARMOR_CONFIG="${install_apparmor:-auto}"
export BRIOCHE_INSTALL_CONTEXT='github-actions'

echo "::group::Fetching latest Brioche installer version..."

# Get the current version number of the installer
installer_version=$(curl --proto '=https' --tlsv1.2 -fL 'https://installer.brioche.dev/channels/stable/latest-version.txt')
echo
echo "Latest brioche-installer version is: $installer_version"

echo "::endgroup::"

echo "::group::Downloading Brioche installer $installer_version..."

# Create a temporary directory
brioche_temp="$(mktemp -d -t brioche-installer-XXXX)"
trap 'rm -rf -- "$brioche_temp"' EXIT
echo "Temporary directory created at $brioche_temp"

# Download the install script and signature
curl -o "$brioche_temp/install.sh" --proto '=https' --tlsv1.2 -fL "https://installer.brioche.dev/${installer_version}/install.sh"
curl -o "$brioche_temp/install.sh.sig" --proto '=https' --tlsv1.2 -fL "https://installer.brioche.dev/${installer_version}/install.sh.sig"

# Validate the signature
ssh-keygen -Y verify \
    -s "$brioche_temp/install.sh.sig" \
    -n installer@brioche.dev \
    -f <(echo 'installer@brioche.dev ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPrPgnmFyVoPP+tLPmF9lkth3BwVQx9rqlyyxkUDWkqe') \
    -I installer@brioche.dev \
    < "$brioche_temp/install.sh"

echo "::endgroup::"

# Run the installer
sh "$brioche_temp/install.sh"
