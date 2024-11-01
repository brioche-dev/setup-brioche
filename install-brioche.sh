#!/usr/bin/env bash

# Wrap the installation in a function so it only runs once the
# entire script is downloaded
function install_brioche() {
    set -euo pipefail

    # Set installation directory from the first argument or default to $HOME/.local/bin
    install_dir="${1:-$HOME/.local/bin}"
    version="${2:-v0.1.3}"

    # Only validate $HOME if using the default installation directory
    if [[ "$install_dir" == "$HOME/.local/bin" ]]; then
        if [ -z "$HOME" ]; then
            echo "::error::$HOME environment variable is not set!"
            exit 1
        fi
        if [ ! -d "$HOME" ]; then
            echo "::error::$HOME does not exist!"
            exit 1
        fi
    fi

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
}

install_brioche "$@"
