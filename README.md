# Static PHP builds

This repository builds PHP 8.0 through 8.5 CLI and FPM binaries with the extensions in [`craft.yml`](craft.yml) for Linux x86_64 and arm64, and macOS Intel and Apple Silicon. Both SAPIs share the dependency build in each version/platform job. PHP 8.0 is an experimental best-effort build because StaticPHP v3 does not list it as a supported version; its failures will not block publishing successful builds. GitHub Actions publishes successful binaries to the configured server when a commit reaches `main`, when a `v*.*.*` tag is pushed, or when the workflow is started manually.

To rebuild specific binaries, open **Actions → Build and deploy PHP binaries → Run workflow** and choose a PHP version and platform. For example, choose PHP `8.4` and platform `macos-aarch64` to build and deploy the PHP 8.4 Apple Silicon CLI and FPM binaries. Choose `all` for either input to include every version or platform. Push and tag runs always build the full matrix.

The server deployment sends one `multipart/form-data` HTTP POST per binary. Each request includes the binary in the `file` field and authenticates with `Authorization: Bearer <API key>`. The upload endpoint must accept that request format and preserve the uploaded filename. Add these repository secrets in **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `DEPLOY_URL` | HTTPS URL that accepts the binary upload POSTs |
| `DEPLOY_API_KEY` | API key sent as a Bearer token |

Each uploaded file is named by the exact built PHP version, SAPI, and platform, for example `php-8.5.8-cli-linux-x86_64` and `php-8.5.8-fpm-linux-x86_64`. CLI and FPM are stored as separate GitHub Actions artifacts. The deploy job uploads each available binary to the server, even when another matrix build fails. Upload requests retry transient failures up to three times.


Local builds use the same [`scripts/build.sh`](scripts/build.sh) as CI. PHP 8.0 excludes Protobuf; PHP 8.1–8.5 include every extension in `craft.yml`.

For Linux builds, install Docker and build the Ubuntu 24.04 builder once:

```sh
docker build -f docker/Dockerfile -t static-php-builder .
docker run --rm -it -v "$PWD:/workspace" static-php-builder 8.0
```

Run the second command again after making changes. Downloads, sources, dependencies, and the StaticPHP executable remain in `.build/8.0-linux-x86_64/` (or `linux-aarch64` on ARM). Each PHP version and platform has its own directory. The first build compiles dependencies; subsequent builds reuse the existing workspace. Docker creates files as root on Linux; use `sudo chown -R "$(id -u):$(id -g)" .build` if you need to edit those files on the host.

On a Mac, install Homebrew and Xcode command line tools, then run the native build:

```sh
bash scripts/build.sh 8.0
```

This builds for the Mac's current architecture and applies the same macOS settings as CI. Docker on a Mac produces Linux binaries; macOS binaries require the native build. On a Linux host with development tools installed, the same script also works without Docker. StaticPHP's `doctor --auto-fix` checks and prepares the native environment.

The script accepts a minor version such as `8.0` or an exact version such as `8.0.30`. Within `.build/<version>-<platform>/`, inspect:

- `console.log` for the latest run's console output.
- `log/spc.shell.log` for compiler commands and errors.
- `craft.yml` for the generated version-specific configuration.
- `dist/` for the named CLI and FPM binaries.

For example, follow a Linux build from another terminal:

```sh
tail -f .build/8.0-linux-x86_64/console.log
```

Set `SPC_REFRESH=1` to replace the cached StaticPHP executable with the current nightly, or `SKIP_DOCTOR=1` to skip the environment check on a prepared machine. Pass these into Docker with `-e SPC_REFRESH=1` or `-e SKIP_DOCTOR=1` before the image name. `SPC_URL` can select a specific executable URL. By default, local runs keep the downloaded executable until explicitly refreshed; fresh CI workspaces download the nightly.

FPM requires a `php-fpm.conf` when started; pass its path with `-y /path/to/php-fpm.conf`.
