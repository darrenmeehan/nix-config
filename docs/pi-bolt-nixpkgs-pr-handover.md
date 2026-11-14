# Handover: finishing nixpkgs PR #586143 (`pi-bolt: init at 1.2.1`)

Written 2026-11-14, updated after the force-push. The remaining steps are yours to run — the agent
is blocked from `git push` and from `gh` writes by design (see
`.agents/skills/nixpkgs-contributing/`).

## State

| | |
| --- | --- |
| PR | **#586143** `pi-bolt: init at 1.2.1` — head `darrenmeehan:pi-bolt-nixpkgs` @ **`481f5e04326e`** (pushed), still **draft** |
| Local branch | `pi-bolt-121-clean` @ `481f5e04326e` — 2 commits, equal to the PR head, per-package content rebased onto `aab3d70` |
| CI on `481f5e0` | ✅ all green: `Lint / commits`, `parse`, `nixpkgs-vet`, `treefmt`; `Eval / x86_64-linux`, `aarch64-linux`, `aarch64-darwin`, `misc`, `compare`; `no PR failures`. Summary: package added 1, linux rebuild 1, darwin 0 |
| `nixpkgs-review pr 586143` | ✅ 1 package built: `pi-bolt`, 0 failed (evaluated with import-from-derivation disabled) |
| PR body | **still the old one** — the live description claims `JITI_FS_CACHE=true`; the corrected draft at `docs/pi-bolt-nixpkgs-pr-body.md` is **not applied yet** |
| Reviewer | none yet (`reviewDecision` empty; the PR has `7.no default reviewers`) |
| ofBorg | never built — it doesn't build drafts; no build status on the PR |
| Local clone | `~/code/nix-config/nixpkgs-pr` (shallow; `origin` = NixOS/nixpkgs, `fork` = darrenmeehan/nixpkgs) |

Fixes carried in `481f5e0` (on top of the old `520a19b` head): five duplicated
`chmod -R u+rwX $TMPDIR/plugins` blocks removed, redundant `versionCheckProgram` /
`versionCheckProgramArg` dropped, `passthru.tests.version` + the `testers` input dropped.
Every commit carries the `Assisted-by:` trailer (`Lint / commits` accepts it).

## Steps

Steps 2–4 are done; 1 was yours before the push (the push is the sign-off). 5–7 remain.

```bash
cd ~/code/nix-config/nixpkgs-pr
```

**1. Read the final diff.** This is the AI-policy "responsible person in the loop"; it cannot be
delegated or auto-ticked. *(You pushed, so treat this as signed off.)*

```bash
git log --oneline origin/master..HEAD
git diff origin/master..HEAD -- pkgs/by-name/pi/pi-bolt maintainers/maintainer-list.nix
```

**2. ✅ Done — pushed.** PR head is now `481f5e04326e`. Kept for reference:

```bash
git push --force-with-lease fork pi-bolt-121-clean:pi-bolt-nixpkgs
```

**3. ✅ Done — CI green on `481f5e0`** (see the table above). Reference:

```bash
gh pr view 586143 --json headRefOid,isDraft,state
gh pr checks 586143 --watch          # minutes, not a hang
```

**4. ✅ Done — 1 package built, 0 failed.** Reference:

```bash
nix run nixpkgs#nixpkgs-review -- pr 586143 --no-shell
```

**5. ← do now.** In `docs/pi-bolt-nixpkgs-pr-body.md`, change `- [ ] Ran \`nixpkgs-review\`` to
`- [x]` and replace the `<!-- re-run pending … -->` comment with the report's "1 package built:
`pi-bolt`" line. Then apply it — the live body is still the old one:

```bash
gh pr edit 586143 --body-file ~/code/nix-config/docs/pi-bolt-nixpkgs-pr-body.md
```

**6. ← do now.** Out of draft (this is also what lets ofBorg build it), then ask ofBorg:

```bash
gh pr ready 586143
gh pr comment 586143 --body '@ofborg build pi-bolt'
```

**7. ← do now.** Close the loop with the reviewer (their complaint was accurate for the old commits;
the trailer is on both pushed ones). Then ask for a review — the PR has no default reviewers.

```bash
gh pr comment 586143 --body 'You were right — the trailers were missing on those commits. The branch is now two clean commits (maintainer entry + squashed init at 1.2.1), both carrying the `Assisted-by:` trailer, and the description no longer claims checks that had not been run. Thanks for the nudge.'
```

## Already verified (no need to repeat)

Local runs against `481f5e04326e`, sandbox on, x86_64-linux — and CI re-ran the first four on the
pushed head, all green:

| Check | Command | Result |
| --- | --- | --- |
| format | `nixfmt --check pkgs/by-name/pi/pi-bolt/package.nix` | clean |
| build + tests | `nix-build -A pi-bolt.passthru.tests --no-out-link` | ✅ `versionCheckHook` + `passthru.tests.aot` pass |
| whole tree | `nix-build ci -A fmt.check` | ✅ 49 836 files, 0 changed |
| nixpkgs-vet | `nix-build ci -A nixpkgs-vet --arg base /tmp/nixpkgs-base --arg head $PWD` | ✅ `Validated successfully` (base `aab3d70`) |
| package-set review | `nixpkgs-review rev HEAD --no-shell` | ✅ 1 package built: `pi-bolt`, 0 failed |
| extensions | `pi-bolt.withExtensions [guardrails, leash, pi-diff, pi-task]` | ✅ builds, 13 built-ins in `doctor` |
| daily driver | same + `.override { jitSupport = true; cpu = "native"; }` | ✅ `1.5.2 (Pi-Bolt 1.2.1, linux-x64-jit, JIT on)` |

CI's `Lint / nixpkgs-vet` and `Lint / treefmt` have since passed against the real merge base
(`49dd1e9b`), so the `aab3d70` tie no longer matters. For a future push, redo the vet run against
the current tip:

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
the build was more isolated than asked), and `build log of '…pi-bolt-1.2.1.drv^*' is not available`
(the derivation was substituted from the eval-results cache rather than built here, so there is no
local log).

## Traps in this clone

- `git fetch origin master` never completes (shallow, 3.1 G `.git`). Use `--depth=1 --no-tags`.
- `git rebase origin/master` produces add/add conflicts across the whole tree (no usable merge
  base). Use `git rebase --onto origin/master <old-base-sha> <branch>`.
- Keep the PR at two commits — amend, never add fixups.
- ofBorg has no local mode; the build half is `nixpkgs-review`, the eval half is
  `.github/workflows/eval.yml`.
