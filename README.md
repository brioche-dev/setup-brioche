# setup-brioche

[![Latest release](https://img.shields.io/github/v/release/brioche-dev/setup-brioche)](https://github.com/brioche-dev/setup-brioche/releases/latest)

Official GitHub Action to install [Brioche](https://brioche.dev/), a delicious package manager.

## Overview

`setup-brioche` installs Brioche on GitHub-hosted or self-hosted runners, enabling your workflows to seamlessly use Brioche for managing packages and scripts. This Action sets up the environment quickly, ensuring that Brioche is ready for use in subsequent steps of your workflow.

## Usage

Add the `setup-brioche` Action to your workflow to install Brioche:

```yaml
jobs:
  setup-brioche:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v5

      - name: Setup Brioche
        uses: brioche-dev/setup-brioche@v1
        with:
          version: "stable" # Optional, specify a version or a release channel

      - name: Verify Brioche installation
        run: brioche --version  # Check that Brioche is available
```

## Inputs

- `version`: (Optional) The version of Brioche to install. It can be either a specific version (`v0.1.5`) or a release channel (`stable`, `nightly`). Defaults to `stable`.
- `install-bin-dir`: (Optional) A directory where a symlink to the current Brioche version will be added. Defaults to '$HOME/.local/bin'.
- `install-root`: (Optional) The directory where the installer will unpack Brioche versions. Defaults to '$HOME/.local/share/brioche-install'.
- `install-apparmor`: (Optional) Enable or disable installation of an AppArmor profile for Brioche. Defaults to `auto`, which will automatically install it if required (e.g. on Ubuntu 24.04).

## How It Works

This Action runs a shell script that:

1. Downloads the specified version of Brioche based on the runner's OS and architecture.
2. Installs Brioche into the install directory (defaults to `$HOME/.local/bin`).
3. Updates `$PATH` so Brioche and any installed packages are available in subsequent steps.

### Example Workflow

Here's a complete workflow example:

```yaml
name: CI with Brioche
on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v5

      - name: Setup Brioche
        uses: brioche-dev/setup-brioche@v1
        # with:
        #   version: "stable" # Optional
        #   install-bin-dir: "$HOME/.local/bin" # Optional
        #   install-root: "$HOME/.local/share/brioche-install" # Optional

      - name: Build package
        run: brioche build -o output

      - name: Install "Hello world"
        run: |
          brioche install -r hello_world
          hello-world
```

## License

This project is licensed under the [MIT License](https://github.com/brioche-dev/setup-brioche/blob/main/LICENSE).

## Support and Contact

For issues, feature requests, or questions, please open an issue in this repository or visit the [Brioche GitHub page](https://github.com/brioche-dev/brioche).
