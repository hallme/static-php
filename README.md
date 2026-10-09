# Static PHP builds

This repository builds PHP 8.0 through 8.5 CLI binaries with the extensions in [`craft.yml`](craft.yml) for Linux x86_64 and arm64, and macOS Intel and Apple Silicon. PHP 8.0 is an experimental best-effort build because StaticPHP v3 does not list it as a supported version; its failures will not block publishing successful builds. GitHub Actions publishes successful binaries to the configured server when a commit reaches `main`, when a `v*.*.*` tag is pushed, or when the workflow is started manually.

To rebuild one PHP version, open **Actions → Build and deploy PHP binaries → Run workflow** and choose the version in **PHP version to build on all platforms**. For example, choosing `8.4` builds and deploys only PHP 8.4 for the four platforms. Choose `all` to run the full matrix; push and tag runs also build every version.

The server deployment sends one `multipart/form-data` HTTP POST per binary. Each request includes the binary in the `file` field and authenticates with `Authorization: Bearer <API key>`. The upload endpoint must accept that request format and preserve the uploaded filename. Add these repository secrets in **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `DEPLOY_URL` | HTTPS URL that accepts the binary upload POSTs |
| `DEPLOY_API_KEY` | API key sent as a Bearer token |

Each uploaded file is named by PHP version and platform, for example `php-8.5-linux-x86_64` and `php-8.4-macos-aarch64`. Upload requests retry transient failures up to three times.


To build locally, install StaticPHP v3 and run:

```sh
spc doctor --auto-fix
spc craft -v
```

The build output is `buildroot/bin/php`.
