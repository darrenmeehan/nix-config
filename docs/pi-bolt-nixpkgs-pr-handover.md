# Handover: finishing nixpkgs PR #586143 (`pi-bolt: init at 1.3.1`)

Written 2026-11-14; updated after the Pi-Bolt 1.3.1 bump. The remaining steps are yours to run — the
agent is blocked from `git push` and from `gh` writes by design (see
`.agents/skills/nixpkgs-contributing/`).

## State

| | |
| --- | --- |
| PR | **#586143** — head `darrenmeehan:pi-bolt-nixpkgs` @ `481f5e04326e` (**1.2.1**, the old head), still **draft**, title still says `init at 1.2.1` |
| Local branch | **`pi-bolt-131`** @ **`fd8178f40c7e`** — `pi-bolt: init at 1.3.1`, rebased onto master `ede7a10003f8`; **not pushed** |
| Version bump | `./update.sh` only: source and the three runtime hashes. `RUNTIME_STAMP` (`13ef7565ee8ee6b5`) and `npmDepsHash` unchanged — patch release, no engine or dependency change. No derivation logic changed |
| Local builds of 1.3.1 | ✅ `-A pi-bolt.passthru.tests` → `1.6.0 (Pi-Bolt 1.3.1, linux-x64-baseline, JIT off)`, re-run on the rebased head (`0pk28a8…`); ✅ four extensions + `.override { jitSupport = true; cpu = "native"; }` → `1.6.0 (Pi-Bolt 1.3.1, linux-x64-jit, JIT on)` |
| Local lints | ✅ `nix-build ci -A nixpkgs-vet` on `fd8178f` against `ede7a10` → `Validated successfully`, zero findings; ✅ `nix-build ci -A fmt.check` → 50 019 files, 0 changed; ✅ `nixfmt --check` |
| Local `nixpkgs-review` | ✅ `rev HEAD --no-shell` on the full clone: **1 package built: `pi-bolt`**, 0 failed. The derivation was already in the store from the earlier build, so it was not recompiled — same drv hash, so the same artifact is what CI would produce |
| Clone | converted to a **full** clone on 2026-11-25 (`git fetch --unshallow`, 6.3 GB, ~40 min). This is what makes `nixpkgs-review rev HEAD` and plain `git rebase` work at all |
| nix-config | `pkgs/pi-bolt/package.nix` mirrored to 1.3.1 (nixpkgs-fmt), **switched on the laptop**: `pi-bolt --version` → `1.6.0 (Pi-Bolt 1.3.1, linux-x64-jit, JIT on)`; dev-1 still needs its own pull+switch after the push |
| CI / review on 1.3.1 | ❌ none — the PR still serves `481f5e0`, so every check must be re-run after the push |
| PR body | 1.3.1 draft at `docs/pi-bolt-nixpkgs-pr-body.md`, **not applied**; the live body still claims `JITI_FS_CACHE=true` |
| Reviewer | none yet (`reviewDecision` empty; `7.no default reviewers`) |
| ofBorg | never built — it doesn't build drafts |
| Local clone | `~/code/nix-config/nixpkgs-pr` (**full**, 6.3 GB; `origin` = NixOS/nixpkgs, `fork` = darrenmeehan/nixpkgs) |

Carried in earlier heads: five duplicated `chmod -R u+rwX $TMPDIR/plugins` blocks removed,
redundant `versionCheckProgram` / `versionCheckProgramArg` dropped, `passthru.tests.version` + the
`testers` input dropped, `RUNTIME_STAMP`/biome comments made version-neutral. Every commit carries
the `Assisted-by:` trailer.

## Steps

Nothing from the earlier head carries over — the head moved to 1.3.1.

```bash
cd ~/code/nix-config/nixpkgs-pr
```

**1. Read the final diff.** This is the AI-policy "responsible person in the loop"; it cannot be
delegated or auto-ticked. It now contains a version bump, so read it again.

```bash
git log --oneline origin/master..HEAD
git diff origin/master..HEAD -- pkgs/by-name/pi/pi-bolt maintainers/maintainer-list.nix
```

**2. Push.** `fork/pi-bolt-nixpkgs` is at `481f5e04326e`, so the lease holds; expect `fd8178f40c7e`
on the PR. Note the new branch name:

```bash
git push --force-with-lease fork pi-bolt-131:pi-bolt-nixpkgs
```

**3. Retitle the PR** to `pi-bolt: init at 1.3.1` — the commit headline and the body already say
1.3.1; the title is the last place still on 1.2.1:

```bash
gh pr edit 586143 --title 'pi-bolt: init at 1.3.1'
```

Then confirm GitHub took the push and CI started (expect `fd8178f40c7e`):

```bash
gh pr view 586143 --json headRefOid,isDraft,state
gh pr checks 586143 --watch          # minutes, not a hang
```

**4. Run nixpkgs-review on the pushed 1.3.1 PR.** Results for the old head are void.

```bash
nix run nixpkgs#nixpkgs-review -- pr 586143 --no-shell
```

**5.** Once step 4 is green, tick `- [ ] Ran \`nixpkgs-review\`` in
`docs/pi-bolt-nixpkgs-pr-body.md`, replace the `<!-- re-run pending … -->` comment with the report's
"1 package built: `pi-bolt`" line, then apply the body:

```bash
gh pr edit 586143 --body-file ~/code/nix-config/docs/pi-bolt-nixpkgs-pr-body.md
```

**6.** Out of draft (this is also what lets ofBorg build it), then ask ofBorg:

```bash
gh pr ready 586143
gh pr comment 586143 --body '@ofborg build pi-bolt'
```

**7.** Close the loop with the reviewer (their complaint was accurate for the old commits; the
trailer is on both). Then ask for a review — the PR has no default reviewers.

```bash
gh pr comment 586143 --body 'You were right — the trailers were missing on those commits. The branch is now two clean commits (maintainer entry + squashed init at 1.2.1), both carrying the `Assisted-by:` trailer, and the description no longer claims checks that had not been run. Thanks for the nudge.'
```

## Already verified (no need to repeat)

Local runs, sandbox on, x86_64-linux. Nothing here is CI — CI has not seen 1.3.1 at all yet:

| Check | Command | Result |
| --- | --- | --- |
| format | `nixfmt --check pkgs/by-name/pi/pi-bolt/package.nix` | clean |
| build + tests | `nix-build -A pi-bolt.passthru.tests --no-out-link` | ✅ `versionCheckHook` + `passthru.tests.aot` pass |
| whole tree | `nix-build ci -A fmt.check` | ✅ 50 019 files, 0 changed |
| nixpkgs-vet | `nix-build ci -A nixpkgs-vet --arg base /tmp/nixpkgs-base --arg head $PWD` | ✅ `Validated successfully`, zero findings (base `ede7a10`, head `fd8178f` descends from it) |
| package-set review | `nixpkgs-review rev HEAD --no-shell` | ✅ 1 package built: `pi-bolt`, 0 failed |
| extensions | `pi-bolt.withExtensions [guardrails, leash, pi-diff, pi-task]` | ✅ builds, 13 built-ins in `doctor` |
| daily driver | same + `.override { jitSupport = true; cpu = "native"; }` | ✅ `1.6.0 (Pi-Bolt 1.3.1, linux-x64-jit, JIT on)` on 1.3.1; 1.3.0 was the same string with `1.3.0` |

These were run by subagents against the rebased head, so they replace the 1.2.1 results entirely
(those were verified against a base the old head no longer sits on). If master moves before you
push, redo vet against the new tip — the base must be a commit the branch descends from:

```bash
git fetch --depth=1 --no-tags origin master
git worktree remove /tmp/nixpkgs-base
git worktree add -q /tmp/nixpkgs-base origin/master
nix-build ci -A nixpkgs-vet --arg base /tmp/nixpkgs-base --arg head "$PWD"
```

## Local noise you can ignore

In `nixpkgs-review` output: `unknown setting 'eval-cores'/'lazy-trees'/'bash-prompt-prefix'`
(Determinate Systems settings the pinned tools don't read), `ignoring the client-specified setting
'sandbox' … not a trusted user` (`trusted-users = root`, so the daemon's `sandbox = true` applied —
the build was more isolated than asked), and `build log of '…pi-bolt-1.2.1.drv^*' is not available`(the derivation was substituted from the eval-results cache rather than built here, so there is no
local log).

## Traps in this clone

- The clone must stay full: as a shallow clone, plain `git fetch`/`git rebase` and `nixpkgs-review rev` all fail. Never re-clone with `--depth`.
- `git rebase origin/master` produces add/add conflicts across the whole tree (no usable merge
  base). Use `git rebase --onto origin/master <old-base-sha> <branch>`.
- Keep the PR at two commits — amend, never add fixups.
- ofBorg has no local mode; the build half is `nixpkgs-review`, the eval half is
  `.github/workflows/eval.yml`.
