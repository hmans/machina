# Releasing Scrapbot

Scrapbot uses release-please for release PRs and GitHub releases. Published releases contain self-contained macOS archives for Apple Silicon and Intel Macs. The separate `scrapbotengine/homebrew-tap` repository watches those releases and updates its formula after both archives are available.

## Release Flow

1. Merge feature and fix PRs into `main` using Conventional Commit titles.
2. Let the `Release Please` workflow open or update its release PR.
3. Review the generated changelog, `version.txt`, Odin version constant, and release manifest.
4. Merge the release PR when the release is ready.
5. Confirm the workflow creates a GitHub release and uploads both archives:
   - `scrapbot-<version>-macos-arm64.tar.gz`
   - `scrapbot-<version>-macos-x86_64.tar.gz`
6. Confirm the Homebrew tap's `Publish Scrapbot` workflow updates `Formula/scrapbot.rb`. It also runs hourly and can be started manually if an immediate update is needed.

## Verification

Download and smoke-test the archive for the current Mac:

```sh
gh release download v<version> --repo scrapbotengine/scrapbot --pattern 'scrapbot-*-macos-*.tar.gz'
tar -xzf scrapbot-<version>-macos-<arch>.tar.gz
./scrapbot-<version>-macos-<arch>/scrapbot version
```

Verify the tap after its publishing workflow completes:

```sh
brew update
brew reinstall scrapbotengine/tap/scrapbot
brew test scrapbotengine/tap/scrapbot
```

## Repository Settings

The Scrapbot repository must allow GitHub Actions to create pull requests. The release workflow uses only its repository-scoped `GITHUB_TOKEN`.

The Homebrew updater runs inside `scrapbotengine/homebrew-tap` and commits with that repository's `GITHUB_TOKEN`. This avoids a cross-repository personal access token. The tap repository must allow workflows read/write access to contents.

The docs website deploys through Cloudflare Workers Builds from `docs-website/`. Keep the Cloudflare build root set to `docs-website`; the project-local `wrangler.jsonc` and `deploy` script are the deployment contract.
