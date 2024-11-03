#!/usr/bin/env bash
set -euo pipefail

# Based on the official install script here:
# https://github.com/brioche-dev/brioche.dev/blob/main/public/install.sh

# Validate environment variables
if [ -z "${HOME:-}" ]; then
    echo '::error::$HOME must be set'
    exit 1
fi
if [ -z "${install_dir:-}" -o -z "${version:-}" ]; then
    echo '::error::$install_dir and $version must be set'
    exit 1
fi
if [ -z "${GITHUB_PATH:-}" ]; then
    echo '::error::$GITHUB_PATH not set! This script should be run in GitHub Actions'
    exit 1
fi

# If `install_dir` contains a `$` character, then try to expand env vars
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
                echo "::error:env var \$${env_var} is not set (used in \$install_dir)"
                exit 1
            fi
        done

        # Expand each env var
        install_dir="$(echo "$install_dir" | envsubst)"

        # Ensure the result is not empty
        if [ -z "$install_dir" ]; then
            echo '::error:$install_dir expanded to empty string'
        fi

        ;;
esac

# Get the URL based on the OS and architecture
case "$OSTYPE" in
    linux*)
        case "$(uname -m)" in
            x86_64)
                brioche_url="https://releases.brioche.dev/$version/x86_64-linux/brioche"
                ;;
            *)
                echo "::error::Sorry, Brioche isn't currently supported on your architecture"
                echo "  Detected architecture: $(uname -m)"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "::error::Sorry, Brioche isn't currently supported on your operating system"
        echo "  Detected OS: $OSTYPE"
        exit 1
        ;;
esac

# Create a temporary directory
echo "::group::Setting up temporary directory"
brioche_temp="$(mktemp -d -t brioche-XXXX)"
trap 'rm -rf -- "$brioche_temp"' EXIT
echo "Temporary directory created at $brioche_temp"
echo "::endgroup::"

echo "::group::Downloading Brioche"
echo "Downloading from $brioche_url"
curl --proto '=https' --tlsv1.2 -fL "$brioche_url" -o "$brioche_temp/brioche"
echo "Download complete"
echo "::endgroup::"

echo "::group::Installing Brioche"
mkdir -p "$install_dir"
chmod +x "$brioche_temp/brioche"
mv "$brioche_temp/brioche" "$install_dir/brioche"
echo "Installation complete! Brioche installed to $install_dir/brioche"
echo "::endgroup::"

echo '::group::Updating $PATH'

# Add Brioche's install directory, plus the installation directory for
# installed packages
new_paths=("$install_dir" "$HOME/.local/share/brioche/installed/bin")
for new_path in "${new_paths[@]}"; do
    echo "$new_path" >> "$GITHUB_PATH"
    echo "Added to \$PATH: $new_path"
done

echo '::endgroup'
