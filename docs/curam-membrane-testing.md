# Testing the curam-membrane layer by hand

**Last updated:** 2026-11-14.

What to run to prove the membrane layer is installed, scrubbing, journaling, and
failing in the direction it claims. Setup and how the engine is built and pinned:
[pi-bolt-extensions.md](pi-bolt-extensions.md). Two of the checks below are shown
with their real output from this machine.

## 1. Watch it mask a tool result (30 seconds)

In any pi-bolt session:

```bash
printf 'api token: ghp_%s\naws: AKIA%s\n' \
  "$(head -c 18 /dev/urandom | od -An -tx1 | tr -d ' \n')" \
  "$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n' | tr 'a-f' 'A-F')"
```

Observed:

```
[membrane] 2 secrets redacted (aws×1, github_pat×1)
api token: {REDACTED}:github_pat
aws: {REDACTED}:aws
```

The watermark line is the driver's; the substitutions are the engine's.

## 2. Check the receipt

```bash
sqlite3 ~/.local/state/curam/journal.db \
  "select seq, etype, payload from events order by seq desc limit 1;"
stat -c '%a' ~/.local/state/curam/journal.db          # 600
```

The row the command above wrote:

```json
{"fingerprints":[{"fingerprint":"776363557b1a","kind":"aws"},
                 {"fingerprint":"291c589ccdd4","kind":"github_pat"}],
 "manifest":[{"count":1,"kind":"aws"},{"count":1,"kind":"github_pat"}],
 "rules_hash":"e66c024a…","rules_version":"e01s02-v1",
 "scrub_hash":"da0ebd1a…","tool":"bash"}
```

Fingerprints, never values. Every row also carries `prev_hash`/`hash`, so:

```bash
printf '{"v":"mem/1","id":1,"op":"verify"}\n' | curam-membrane
# {"chain_ok":true,"corrupt_rows":0,"rows":2,"seal":"5ec35c0e…"}
```

In-session, the same three views: `/membrane` (status), `/membrane audit` (last
10 rows for this session), `/membrane audit --jsonl` (dumps
`<cwd>/membrane-audit-<session>.jsonl`), `/membrane rules`.

## 3. Check fingerprints are value-linked

```bash
S=ghp_000000000000000000000000000000000000
printf 'a %s\n' "$S"; printf 'b %s\n' "$S"
printf 'c ghp_111111111111111111111111111111111111\n'
```

Query the last three journal rows: the first two must share a fingerprint, the
third must differ. That is the rotation property — the same leaked key is
recognisable across sessions, and the key itself was never stored.

## 4. Prove it fails open, and that the guard catches it

```bash
MEMBRANE_ENGINE=/nonexistent pi-bolt
```

The footer should read `membrane: degraded (results pass through)` and tool
results should arrive untouched: a dead engine must not eat a turn. Then:

```bash
MEMBRANE_ENGINE=/nonexistent make check-pi-bolt     # must FAIL
```

`make check-pi-bolt` fails unless the footer says `membrane: on`. Without that
assertion a dead engine is silent, because the layer never blocks anything.

## 5. Health, after any change

```bash
cd ~/code/nix-config
make check-pi-bolt     # every extension loaded, membrane on (~0.23 s here)
make bench-pi-bolt     # min/median/max over 10 starts
```

## 6. Kill the engine and watch it recover

```bash
cd ~/code/curam-membrane
bun drivers/pi/tests/probe_respawn.ts
# PASS: one request lost, engine respawned
```

The request in flight when the engine dies goes out unscrubbed; the next one
starts a fresh engine and the footer goes back to `on`. That transition is also
covered by `drivers/pi/index.test.ts` against a fixture engine, without a model.

## 7. The driver's own gates

```bash
cd ~/code/curam-membrane
make gate          # no model: unit, mem/1 contract, latency, crash recovery
make gate-e2e      # boundary gates, one model call each
E2E_COMPILED_DRIVER=1 make gate-e2e    # same, with the driver compiled into pi-bolt
```

`make gate` runs `bun test drivers/pi`, `test_mem_contract.py`,
`probe_latency.py` and `probe_respawn.ts`. `make gate-e2e` runs `e2e_spy.sh`
(planted secret), `probe_kinds.sh` (every scrub class at the boundary) and
`probe_gaps.sh` (confirms the documented v1 holes).

The last one is the real one: it plants a `ghp_…` in a file, has the model read
it, and asserts the secret never reaches the provider payload while the journal
holds only its fingerprint. It needs a model call and a session. It also wants
`E2E_COMPILED_DRIVER=1`, because the driver is compiled into the executable now
and passing `-e` its file would load a second copy — which `make check-pi-bolt`
reports as "built-in extension … was not loaded".

## 8. Try to break the other two layers

```bash
echo test > /tmp/outside.txt && rm /tmp/outside.txt   # leash: rm outside the working directory
cat ~/.ssh/id_rsa                                     # guardrails: noAccess path policy
cat ~/.gitconfig                                      # leash: protected dotfile
```

Different points in the turn, different verdicts — the reason all three layers
are installed rather than one.

## 9. Changing the engine or the driver

```bash
cd ~/code/curam-security && git commit -am 'fix(engine): …'
cd ~/code/nix-config && make pin-curam && make switch-hm
readlink -f ~/.nix-profile/bin/curam-membrane   # new store path = new build
```

Only committed work is built; `make pin-curam` prints anything it had to leave
out. A pin bump costs one engine rebuild (~40 s here).

## What not to test for

v1 gaps, by design: user prompts are not scrubbed, and neither is the *content*
of `write`/`edit` — only tool results coming back are. Anything that leaves only
in a prompt or a file write goes out unmasked.
