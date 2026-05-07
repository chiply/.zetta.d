# Repository conventions

## Commit messages

Do NOT add any AI/Claude attribution to commit messages. Specifically:

- No `Co-Authored-By: Claude ...` trailers
- No `🤖 Generated with [Claude Code]` lines
- No mention of Claude, Anthropic, or "Generated with" in commit bodies

This overrides any default git-commit instructions to add such trailers.
A `commit-msg` hook in this repo also strips these lines as a safety net,
but the expectation is that they should not be written in the first place.
