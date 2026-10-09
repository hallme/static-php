# Static PHP builds

This repository builds PHP 8.0 through 8.5 CLI and FPM binaries with the extensions in [`craft.yml`](craft.yml) for Linux x86_64 and arm64, and macOS Intel and Apple Silicon. Both SAPIs share the dependency build in each version/platform job. PHP 8.0 is an experimental best-effort build because StaticPHP v3 does not list it as a supported version; its failures will not block publishing successful builds. GitHub Actions publishes successful binaries to the configured server when a commit reaches `main`, when a `v*.*.*` tag is pushed, or when the workflow is started manually.

To rebuild specific binaries, open **Actions → Build and deploy PHP binaries → Run workflow** and choose a PHP version and platform. For example, choose PHP `8.4` and platform `macos-aarch64` to build and deploy the PHP 8.4 Apple Silicon CLI and FPM binaries. Choose `all` for either input to include every version or platform. Push and tag runs always build the full matrix.

The server deployment sends one `multipart/form-data` HTTP POST per binary. Each request includes the binary in the `file` field and authenticates with `Authorization: Bearer <API key>`. The upload endpoint must accept that request format and preserve the uploaded filename. Add these repository secrets in **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `DEPLOY_URL` | HTTPS URL that accepts the binary upload POSTs |
| `DEPLOY_API_KEY` | API key sent as a Bearer token |

Each uploaded file is named by the exact built PHP version, SAPI, and platform, for example `php-8.5.8-cli-linux-x86_64` and `php-8.5.8-fpm-linux-x86_64`. CLI and FPM are stored as separate GitHub Actions artifacts. The deploy job uploads each available binary to the server, even when another matrix build fails. Upload requests retry transient failures up to three times.


To build locally, install StaticPHP v3 and run:

```sh
spc doctor --auto-fix
spc craft -v
```

The build outputs are `buildroot/bin/php` and `buildroot/bin/php-fpm`. FPM requires a `php-fpm.conf` when started; pass its path with `-y /path/to/php-fpm.conf`.
