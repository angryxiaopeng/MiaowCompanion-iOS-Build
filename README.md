# MiaowCompanion iOS code-only build

This proposed public repository contains the generic SwiftUI/WebKit app shell and a loopback-only asset server. It contains no real pet images, videos, Apple IDs, passwords, signing keys, or provisioning profiles.

A standard `macos-latest` GitHub-hosted runner compiles an unsigned ARM64 iPhone binary. The job is skipped if the repository is private. It does not contact Apple signing services or request paid runners. Code-only build results are published as release files, not Actions cache/artifacts.

The build-stage page is intentionally a generic placeholder. The companion's real interface and private media are assembled locally after compilation. The release ZIP is **not an installable final pet app**. The final IPA still needs owner-side signing on Windows or macOS and actual iPhone validation.

The workflow has a20-minute timeout and only one concurrent run for a branch. Compilation success must be verified from the actual run before any installable-app claim.
