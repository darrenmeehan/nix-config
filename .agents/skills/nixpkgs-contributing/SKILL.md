---
name: nixpkgs-contributing
description: Prepare and self-review a nixpkgs PR from this repo's nixpkgs clone (nixpkgs-pr/). Lists the checks that are runnable locally, the shallow-clone git traps, and the steps that must be handed back to Darren instead of done by the agent. Use when working on the nixpkgs PR, a package under nixpkgs-pr/, or when asked to prepare, verify or review a nixpkgs contribution.
---

# Contributing to nixpkgs

Work happens in `~/code/nix-config/nixpkgs-pr`: a **shallow** clone, `origin` = `NixOS/nixpkgs`,
`fork` = `darrenmeehan/nixpkgs`, PR branch `pi-bolt-nixpkgs` = PR **#586143**. Keep
`~/code/nix-config/pkgs/pi-bolt/package.nix` in sync — that copy is what this machine runs.

Formatting is **nixfmt** (nixpkgs), not this repo's `nixpkgs-fmt`. Never run `nix fmt` in the
clone; format the one file.

## Checks that run locally

```bash
cd ~/code/nix-config/nixpkgs-pr
PKG=pkgs/by-name/pi/pi-bolt/package.nix

nix-shell -p nixfmt --run "nixfmt --check $PKG"
nix-instantiate --parse "$PKG" >/dev/null

# build + versionCheckHook + passthru.tests.aot (~75 s)
nix-build -A pi-bolt.passthru.tests --no-out-link

# whole-tree formatting (~1.5 min). Attr is fmt.check, NOT treefmt.
nix-build ci -A fmt.check

# nixpkgs-vet: needs an explicit base checkout at the current master tip
git worktree add -q /tmp/nixpkgs-base origin/master
nix-build ci -A nixpkgs-vet --arg base /tmp/nixpkgs-base --arg head "$PWD"

# package-set review. Always --no-shell, or it hangs in an interactive shell.
nix run nixpkgs#nixpkgs-review -- rev HEAD --no-shell   # pre-push
nix run nixpkgs#nixpkgs-review -- pr 586143 --no-shell # post-push
```

OfBorg has no local mode — it is a hosted bot. The build half is what `nixpkgs-review` does; the
eval half is `.github/workflows/eval.yml`. Do not claim it was "run locally".

## PR template (`.github/PULL_REQUEST_TEMPLATE.md`)

Keep the template's headings and link block: the checkboxes are markdown reference links and render
broken without the definitions at the bottom. Body draft: `docs/pi-bolt-nixpkgs-pr-body.md`.

- *Fits CONTRIBUTING / pkgs / maintainers READMEs* → by-name layout plus the
  `maintainers/maintainer-list.nix` entry, both already in the branch.
- *Follows the automation/AI policy* → `Assisted-by:` trailer on every commit, **and Darren reads the
  final diff before the push**. The agent cannot tick or self-certify this: hand it over.
- *Built on platform* → tick only what was actually built here (`x86_64-linux`).
- *Basic functionality of `./result/bin/`* → `nix-build -A pi-bolt`, then
  `HOME=$(mktemp -d) ./result/bin/pi-bolt --version` and `doctor` (a plain `doctor` can hang).
- *Ran `nixpkgs-review` on this PR* → only tickable after the push
  (`nixpkgs-review pr 586143`); paste its "N packages built" into the body.
- *Package tests at `passthru.tests`* → the `pi-bolt.passthru.tests` build above.
- *NixOS tests, lib tests, release notes* → N/A for a new package; leave unchecked.

## Version bump

Run the package's own script from the nixpkgs root — it bumps version, source, `npmDepsHash`, the
three runtime hashes and `RUNTIME_STAMP`:

```bash
NIX_PATH=nixpkgs=$PWD ./pkgs/by-name/pi/pi-bolt/update.sh
```

`NIX_PATH` is required (no channel on this machine; the shebang's `nix-shell` cannot find
`<nixpkgs>` without it). Then: build `-A pi-bolt.passthru.tests`, rebuild the extensions/native
variant, fix any comment that names the old version, update the commit message (version, Pi version,
changelog URL) and ask Darren to retitle the PR — `gh pr edit --title` is a `gh` write.
If `RUNTIME_STAMP` changed, the engine layout changed: say so, it is the interesting part of the bump.

## Git traps in this clone

- `git fetch origin master` never completes (shallow, 3.1 G `.git`). Use
  `git fetch --depth=1 --no-tags origin master` — seconds.
- `git rebase origin/master` fails with add/add conflicts on the whole tree (no usable merge
  base). Use `git rebase --onto origin/master <old-base-sha> <branch>`.
- Keep the PR at two commits (`maintainers: add …`, package init): amend locally, never add
  fixup commits — the force-push is Darren's.
- Re-run vet whenever master has moved; a stale base produces false findings both ways.
- Rebasing this branch is unreliable: plain `rebase`, `rebase --onto` and `cherry-pick` of the init
  commit all misbehave (whole-tree add/add conflicts that revert upstream). The working recipe:
  `git checkout -B <new> origin/master`, then recreate the two files with
  `git show <old-sha>:pkgs/by-name/pi/pi-bolt/<file> > <file>`, re-insert the `darrenmeehan` block
  into `maintainers/maintainer-list.nix` by hand, and commit with `-C <old-sha>` to keep the
  messages. `git checkout <sha> -- <path>` is guard-blocked; the `git show` redirect is not.

## Do not do — hand over instead

- **No `git push` of any kind** (including `--force-with-lease`), nothing to `fork`.
- **No `gh` writes**: `gh pr create|edit|ready|comment|review|merge`, `gh api`, `gh release …`.
  `home/configs/pi-bolt.nix` installs guardrails that auto-deny these; do not route around the
  guard (no `curl`, no alternative client, no retry).
- **No ofBorg pings** on the PR — `@ofborg build pi-bolt` is Darren's comment to post.
- No `nix flake update`, no `home-switch`, no edits to tracked files outside the PR's package and
  the `maintainers` entry, no writes to `origin`/`master`.

## Handover

Report what changed, paste the check output, then hand back these for Darren to run:

```bash
cd ~/code/nix-config/nixpkgs-pr
git push --force-with-lease fork <branch>:pi-bolt-nixpkgs
gh pr ready 586143
gh pr edit 586143 --body-file ~/code/nix-config/docs/pi-bolt-nixpkgs-pr-body.md
gh pr comment 586143 --body '@ofborg build pi-bolt'
```
