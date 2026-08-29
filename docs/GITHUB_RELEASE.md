# GitHub Publication and Release Requirements

## Goal

The finished DropClock work should not remain only as an untracked local prototype.

After implementation and validation, publish the project to the configured GitHub repository.

## Before Push

Verify:

- repository builds successfully
- 1280×720 canonical behavior works
- resize/maximize/restore does not break layout
- Sakura pattern satisfies docs/SAKURA_PATTERN.md
- no third-party images are accidentally bundled
- no secrets, tokens, local paths, or credentials are committed
- .gitignore excludes build cache and temporary files
- README.md reflects the current state
- documentation is current

## Git Workflow

Use a normal non-destructive workflow.

Example:

```bash
git status
git add .
git commit -m "Implement full-width gravity-driven Sakura water sequence"
git push
```

Do not force-push unless explicitly requested.

If working on a feature branch, push the feature branch and use the repository's normal merge/PR workflow.

## GitHub Release

When a usable Windows build is ready:

1. produce the Windows build
2. verify it launches on the target environment
3. create a GitHub Release
4. attach the appropriate Windows artifact
5. include short release notes

Suggested release-note structure:

```text
DropClock vX.Y.Z

Highlights
- ...
- ...

Target
- Windows
- transparent display
- 1280×720

Known limitations
- ...
```

## Required Publication Behavior for Coding Agents

If the user asks for implementation and GitHub publication:

- implement locally
- test locally
- commit
- push to the configured GitHub remote
- create/update the release when requested and appropriate

If publication cannot be completed because credentials, remote configuration, or repository permissions are unavailable:

do not pretend it was uploaded.

Clearly report:

- local implementation status
- exact blocker
- exact action required from the user

## Repository Safety

Never commit:

- API keys
- GitHub tokens
- credentials
- machine-specific secrets
- private user data

Do not rewrite public history without explicit approval.
