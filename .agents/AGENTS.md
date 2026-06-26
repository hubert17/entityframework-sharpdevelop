# Workspace Rules

## Git & Shell Command Execution
- **High-Resource/Token Cost Actions:** For operations with high token usage or interactive prompts (e.g., `git push`, `git fetch`, `git pull`, `git log`, large `git diff`, or commands requiring network authentication), the AI must NOT run them directly. Instead, prompt the user with the exact commands to run locally.
- **Medium to Low Resource/Token Cost Actions:** For lightweight, local, and non-interactive operations (e.g., `git add`, `git commit` [unless heavy pre-commit hooks are active], unstaging files, simple `git status` checks, or local file updates), the AI is permitted to execute them directly to speed up workflows, provided no manual approval loops are triggered.

## Build & Test Operations
- **Verbosity Constraints:** For successful/routine runs, use minimal verbosity to keep context clean.
- **Exception for Failures:** If a build or test fails, use standard or detailed verbosity to ensure the full error messages, stack traces, and compiler warnings are captured for accurate debugging.

## Code Inspection & Search
- **Precise File Views:** Do not read entire large files at once. Read targeted line ranges (using start/end parameters) to locate class definitions or functions.
- **Scoped Searching:** When searching the codebase via grep or ripgrep, scope the query to specific file paths or extensions (e.g. using `Includes` filters) rather than scanning the entire directory.


