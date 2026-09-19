# Windows setup with WSL

GuardRail's hooks run in a Bash environment. On Windows, use WSL 2 with a Linux distribution such as Ubuntu, and run both GuardRail and Claude Code in that same Linux environment.

## 1. Prepare the WSL environment

Open your WSL distribution and install the required tools:

```bash
sudo apt update
sudo apt install -y bash jq openssl nodejs npm
```

GuardRail requires Bash 4+, `jq`, and `openssl`. Node.js and npm are needed for the `npx` installer. Check the installed versions with `bash --version`, `jq --version`, `openssl version`, and `node --version`.

## 2. Install GuardRail inside WSL

Run the installer from the WSL shell:

```bash
npx guardrail-agent init
guardrail status
```

The installer registers Claude Code hooks in `~/.claude/settings.json` and installs their files under `~/.claude/hooks/guardrail`. `guardrail status` confirms whether the guards are active.

If Claude Code uses a non-default configuration directory, set `GUARDRAIL_CLAUDE_DIR` to that directory before installing and when running GuardRail commands:

```bash
export GUARDRAIL_CLAUDE_DIR="$HOME/.claude"
npx guardrail-agent init
guardrail status
```

## 3. Keep Claude Code and its hooks on the same side

Install and run Claude Code inside WSL as well. Installing GuardRail in WSL while launching a Windows-native Claude Code points the app at Windows settings, not the Linux hook paths written by the installer. In that mixed setup, the hooks will not run.

Keep your project in the WSL Linux filesystem (for example, under `~/projects`) for better filesystem performance. Accessing projects under `/mnt/c` can be slower.

## 4. Verify enforcement

Run `guardrail status` to inspect the installed guards. To verify a specific guard blocks an action, test it in a disposable repository and confirm the command is denied before execution. `guardrail pentest` exercises the installed copy, so it does not validate uninstalled changes in a source checkout.

## Troubleshooting

- If `guardrail` is not found after installation, start a new WSL shell and check that npm's global binary directory is on `PATH`.
- If Claude Code does not run hooks, confirm that Claude Code itself is running in WSL and that its configuration directory matches `GUARDRAIL_CLAUDE_DIR` (or the default `~/.claude`).
- If dependency commands are missing, install `bash`, `jq`, `openssl`, Node.js, and npm in the WSL distribution; Windows-installed tools are not automatically available as Linux commands.
