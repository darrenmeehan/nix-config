# curam-membrane — what it is and how to live with it

**Last updated:** 2026-11-14.

A plain-language guide to the layer that sits between your coding agent and the
model provider. For the mechanics (how it is built, pinned and compiled in) see
[pi-bolt-extensions.md](pi-bolt-extensions.md); for checks you can run yourself,
[curam-membrane-testing.md](curam-membrane-testing.md).

## The one-paragraph version

Your agent reads files, runs commands, and sends what it read to a model
provider. membrane looks at each tool result on the way out. If it sees something
that looks like a credential or personal data, it swaps the value for
`{REDACTED}:kind` before the provider sees it, and writes a receipt. You notice it
as one line above the tool output, and as `membrane: on` in the footer. Nothing
asks you to approve anything, and nothing gets blocked.

## Why you have it

An agent doing ordinary work — `grep -r`, `cat .env`, `env`, reading
`~/.aws/credentials`, opening a config file — sends everything it reads to the
provider. Your other two extensions do not look at that traffic: they decide what
the agent may *touch* and what shell commands may *do*. Nobody was watching what
*leaves*.

membrane watches that. Its rule classes include AWS keys, OpenAI/OpenRouter keys,
GitHub tokens (classic and fine-grained), Slack and Google tokens, JWTs, private
keys, `KEY=value` pairs, email addresses and internal domains.

## What you will actually see

**The footer** — `membrane: on · e01s02-v1`. On means the engine is live;
`e01s02-v1` is the rules version, so you can tell when the rules changed.

**One line above a tool result**, when something matched:

```
[membrane] 2 secrets redacted (aws×1, github_pat×1)
api token: {REDACTED}:github_pat
aws: {REDACTED}:aws
```

The line is the driver telling you what it did; the replacements are the engine's.
The model received the redacted text, not the values.

**Three commands**, typed like any other:

| command | what it shows |
|---|---|
| `/membrane` | status: engine, rules version, journal file, seal |
| `/membrane audit` | the last ten receipts for this session |
| `/membrane audit --jsonl` | the same, written to `membrane-audit-<session>.jsonl` |
| `/membrane rules` | the rule classes and their version |

## Day to day, you do nothing

It is on by default and has no approval step. The habits worth having:

- **When the watermark appears, take it seriously.** The model is now working
  from `{REDACTED}:aws` instead of your key. If the task genuinely needed the
  value — "use this token to call the API" — the model will fail, and that is the
  feature, not a bug.
- **Check the receipts after a session that touched real credentials:**
  `/membrane audit`. Useful for the question "did my key go out?".
- **Rotating a leaked key.** Every receipt carries a 12-character
  **fingerprint** — the first 12 characters of a SHA-256 of the secret, not the
  secret. The same value always produces the same fingerprint, so a key you
  already rotated is recognisable in old rows without the key ever being stored.

## Where the receipts live

One SQLite file: `~/.local/state/curam/journal.db`, mode 0600 (`CUSEC_JOURNAL`
moves it). One row per event; a scrub writes a `pii_scrubbed` row with counts,
fingerprints, and the versions of the rules and pattern set that decided it.

Rows are chained: each row's hash covers the row before it, and the newest hash
is the **seal**. Change an old row and the chain stops matching — that is what
`op verify` checks (`chain_ok: true`, `corrupt_rows: 0`). It is not
cryptographically strong proof, it is evidence that the file was not quietly
edited.

## The three layers, in plain words

| | question it answers | when it acts | if it cannot act |
|---|---|---|---|
| **guardrails** | may the agent touch this path? | before the tool runs | blocks, or asks |
| **leash** | may this shell command do that? | before the tool runs | blocks |
| **membrane** | may this text reach the model? | after the tool ran | passes it through, and says so |

All three are installed because they fail differently on purpose. The first two
are seatbelts: they stop things. membrane is a filter: it lets the turn continue
and tells you what it could not scrub.

## When the footer says something else

**`membrane: off (no engine found)`** — the engine binary is not on `PATH`, so
nothing is scrubbed. Check `command -v curam-membrane`; if it is missing, run
`make switch-hm` in `~/code/nix-config`.

**`membrane: degraded (results pass through)`** — the engine was there but stopped
answering: it crashed, or missed its 3-second budget. While it is down, results go
out unscrubbed. It is not fatal. The driver starts a fresh engine on the next tool
result, and the footer returns to `on` as soon as one succeeds — so the cost is the
results that happened while it was down, usually one. No restart needed. If it
stays degraded, the engine binary is the problem: run `curam-membrane` by hand and
read what it prints.

Both states mean **results reached the model unscrubbed**. membrane never fails a
turn over its own problems — a dead scrubbing engine blocking everything would be
worse than a leak you were told about — so the footer is the only warning you get,
and `make check-pi-bolt` fails on both.

## What it does not do

- It never blocks a tool. A blocked agent is guardrails' and leash's job.
- It does **not** scrub what *you* write. Prompts you type, the contents of
  `write`/`edit` calls, and the commands the agent runs are not inspected in this
  version. A secret the agent puts *into* a shell command ("curl with this token")
  leaves with that command. Do not paste a live secret into a prompt expecting it
  to be hidden — it will not be.
- It does not inspect images.
- It does not look for prompt injection.

It is a filter on one direction of one channel: tool results on their way to the
model.

## If you want to change the rules

The rules live in the engine (`curam-security`'s `curam-core`), not in the
extension — that split is deliberate, so the same detection improves every harness
at once and the drivers stay dumb pipes. To change them: edit and commit in
`~/code/curam-security`, then in `~/code/nix-config`:

```bash
make pin-curam && make switch-hm    # engine rebuilds from the new commit (~40 s)
```

`make pin-curam` prints anything a dirty checkout left out, and only committed
work is built.

## Try it in three commands

In a session:

```bash
printf 'token: ghp_%s\n' "$(head -c 18 /dev/urandom | od -An -tx1 | tr -d ' \n')"
```

Expect the watermark and `{REDACTED}:github_pat` in the result, then `/membrane
audit` to see the receipt it just wrote. Everything deeper — journal rows, chain
verification, the fail-open test, the driver's own gates — is in
[curam-membrane-testing.md](curam-membrane-testing.md).
