# setup-brioche

![GitHub release (latest by date)](https://img.shields.io/github/v/release/brioche-dev/setup-brioche) ![GitHub](https://img.shields.io/github/license/brioche-dev/setup-brioche)

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
        uses: actions/checkout@v3

      - name: Setup Brioche
        uses: brioche-dev/setup-brioche@v1
        with:
          version: 'v0.1.4'  # Optional, specify a version or use the default (v0.1.4)
          install-dir: '/custom/install/path'  # Optional, specify a custom installation path

      - name: Verify Brioche installation
        run: brioche --version  # Check that Brioche is available
```

## Inputs

- `version`: (Optional) The version of Brioche to install. Defaults to `v0.1.4` (the latest version).
- `install-dir`: (Optional) The directory where Brioche should be installed. Defaults to `$HOME/.local/bin`.
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
        uses: actions/checkout@v4

      - name: Setup Brioche
        uses: brioche-dev/setup-brioche@v1
        # with:
        #   version: 'v0.1.4' # Optional
        #   install-dir: '$HOME/custom/install/path' # Optional

      - name: Build package
        run: brioche build -o output

      - name: Install "Hello world"
        run: |
          brioche install -r hello_world
          hello-world
```

## Logs and Debugging

This Action uses GitHub's [logging groups](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#grouping-log-lines) to make output more readable. You will see collapsible log groups for stages like downloading, validating, and installing Brioche, making it easier to debug if needed.

## Troubleshooting

- Ensure the version specified in the `version` input is valid and available.
- If Brioche isn't recognized in your shell, make sure the install path is correctly set in your environment.

## License

This project is licensed under the [MIT License](https://github.com/brioche-dev/setup-brioche/blob/main/LICENSE).

## Support and Contact

For issues, feature requests, or questions, please open an issue in this repository or visit the [Brioche GitHub page](https://github.com/brioche-dev/brioche).
