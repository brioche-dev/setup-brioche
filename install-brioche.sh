#!/usr/bin/env bash
set -euo pipefail

LATEST_BRIOCHE_VERSION="v0.1.5"
SEMVER_REGEX='^v(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:\.(?:0|[1-9]\d*))?(?:-(?:(?:[0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+(?:[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'

# Based on the official install script here:
# https://github.com/brioche-dev/brioche.dev/blob/main/public/install.sh

validate_inputs() {
    # Validate environment variables
    if [ -z "${GITHUB_PATH:-}" -o -z "${GITHUB_ACTION_PATH:-}" ]; then
        echo '::error::$GITHUB_PATH or $GITHUB_ACTION_PATH not set! This script should be run in GitHub Actions'
        exit 1
    fi
    if [ -z "${HOME:-}" ]; then
        echo '::error::$HOME must be set'
        exit 1
    fi
    if [ -z "${install_dir:-}" -o -z "${version:-}" -o -z "${install_apparmor:-}" ]; then
        echo '::error::$install_dir, $version, and $install_apparmor must be set'
        exit 1
    fi

    # Validate version constraints:
    # - Only semver versions are allowed for version
    # - Only values `stable`, `nightly` are allowed for release channel
    case "$version" in
        v*)
            if [[ ! $version =~ $SEMVER_REGEX ]]; then
                echo "::error::version must be a valid semver"
                exit 1
            fi
            ;;
        stable|nightly)
            ;;
        *)
            echo "::error::version must be either 'stable', 'nightly' or a semver"
            exit 1
            ;;
    esac
}

install_brioche() {
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

    # Get the OS and architecture-specific config, such as download URL and AppArmor config
    case "$OSTYPE" in
        linux*)
            # aarch64 is not currently supported on stable
            case "$(uname -m) $version" in
                "x86_64 v"*)
                    brioche_url="https://releases.brioche.dev/$version/x86_64-linux/brioche"
                    ;;
                "x86_64 stable")
                    brioche_url="https://releases.brioche.dev/$LATEST_BRIOCHE_VERSION/x86_64-linux/brioche"
                    ;;
                "x86_64 nightly")
                    brioche_url="https://development-content.brioche.dev/github.com/brioche-dev/brioche/branches/main/brioche-x86_64-linux.tar.xz"
                    ;;
                "aarch64 nightly")
                    brioche_url="https://development-content.brioche.dev/github.com/brioche-dev/brioche/branches/main/brioche-aarch64-linux.tar.xz"
                    ;;
                *)
                    echo "::error::Sorry, Brioche isn't currently supported on your architecture"
                    echo "  Detected architecture: $(uname -m)"
                    exit 1
                    ;;
            esac

            case "$install_apparmor" in
                auto)
                    # Detect if we should install an AppArmor profile. AppArmor 4.0
                    # introduced new features to restrict unprivileged user
                    # namespaces, which Ubuntu 23.10 enforces by default. The
                    # Brioche AppArmor policy is meant to lift this restriction
                    # for sandboxed builds, which we only need to do on AppArmor 4+.
                    # So, we only install the policy if AppArmor is enabled and
                    # we find the config file for AppArmor abi 4.0.
                    if type aa-enabled >/dev/null && aa-enabled -q && [ -e /etc/apparmor.d/abi/4.0 ]; then
                        should_install_apparmor=1
                    else
                        should_install_apparmor=
                    fi
                    ;;
                true)
                    should_install_apparmor=1
                    ;;
                false)
                    should_install_apparmor=
                    ;;
                *)
                    echo "::error::Invalid value for \$install_apparmor: $install_apparmor"
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

    if [ "$version" = "nightly" ]; then\
        unpack_dir="$HOME/.local/libexec/brioche"

        rm -rf "$unpack_dir/nightly"
        mkdir -p "$unpack_dir/nightly"
        tar -xJf "$brioche_temp/brioche" --strip-components=1 -C "$unpack_dir/nightly"

        ln -sf nightly "$unpack_dir/current"

        symlink_target="$unpack_dir/current/bin/brioche"
        mkdir -p "$install_dir"
        ln -sfr "$symlink_target" "$install_dir/brioche"

        echo "Installation complete! Brioche installed to $install_dir/brioche (symlink to $unpack_dir/current/bin/brioche)"
    else
        mkdir -p "$install_dir"
        chmod +x "$brioche_temp/brioche"
        mv "$brioche_temp/brioche" "$install_dir/brioche"

        echo "Installation complete! Brioche installed to $install_dir/brioche"
    fi

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

    if [ -n "$should_install_apparmor" ]; then
        echo "::group::Installing AppArmor config"

        export BRIOCHE_INSTALL_PATH="$install_dir/brioche"
        cat "$GITHUB_ACTION_PATH/apparmor.d/brioche-gh-actions.tpl" | envsubst | sudo tee /etc/apparmor.d/brioche-gh-actions
        sudo apparmor_parser -r /etc/apparmor.d/brioche-gh-actions

        echo "::endgroup"
    fi
}

validate_inputs
install_brioche
