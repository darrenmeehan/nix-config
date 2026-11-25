# Docs hub

One Zola site that publishes every project's `docs/` directory, served
read-only on the tailnet at <https://dev-1.fox-porgy.ts.net:8443/>.

The project repositories stay the single source of truth. Nothing is ever
written into this directory by an agent, and the generated site is not in git:
`hub-sync` stages the sources into `$XDG_DATA_HOME/docs-hub` (on dev-1:
`/home/drn/.local/share/docs-hub`) and builds there.

## Layout

| Path | Purpose |
|---|---|
| `sources.toml` | which repositories to aggregate |
| `config.toml` | Zola config — taxonomies `project`, `agent`, `type`, `status`, `tag` |
| `hub-sync.py` | stage + validate + build (run through the `hub-sync` wrapper) |
| `templates/`, `static/` | the site itself |
| `../pkgs/docs-hub.nix` | the `hub-sync` package: python + pyyaml, zola, git |
| `../hosts/dev-1/docs-hub.nix` | sync timer and `tailscale serve` unit |

## Adding a project

Add an entry to `sources.toml` and run `hub-sync`:

```toml
[[sources]]
project = "my-repo"          # slug, also the URL segment
path = "~/code/my-repo"      # a local checkout …

[[sources]]
project = "other-repo"
remote = "git@github.com:me/other.git"   # … or a git remote (shallow clone in .cache/remotes)
branch = "main"
```

Optional `docs` selects a different subdirectory (default `docs`). A missing
local path or a failed fetch is a warning for that project, never fatal — the
same manifest is used on every machine.

A `path` source publishes that checkout's **working tree**, so a document pushed
from another machine shows up once dev-1's checkout is pulled. Use `remote` for a
repository the hub host does not check out: the timer then clones it and fetches
the branch on every run, and pushes appear without anyone logging in.

## Running it

```sh
hub-sync                                  # build the site in the default root
hub-sync --root /tmp/hub --sources x.toml  # alternate root / manifest
nix run .#hub-sync                        # from anywhere, without installing it
```

On dev-1 the systemd timer `docs-hub-sync` runs it every five minutes as `drn`,
and `docs-hub-serve` keeps `tailscale serve` pointed at the built site. Manual
runs write to the same root the service serves, so a manual trigger is
immediately visible.

## What the sync does to each document

Source documents carry YAML frontmatter; Zola parses TOML, so staging rewrites
the frontmatter of every file it copies:

- `project` is always the source slug from `sources.toml` (a differing value in
  the document is reported and overridden).
- `title`, `date`, `type`, `status` default to the first `# heading`, the file's
  mtime, the directory (`specs`→`spec`, `research`→`research`, `runs`→`run`,
  `adr`→`adr`, otherwise `doc`), and `draft`.
- `agent` and `tags` are kept when present.
- A file whose YAML does not parse is reported on stderr and skipped; the rest
  of the site still builds. `zola build` itself is the only fatal step.

The rules agents have to follow when writing documents live in the global agent
instructions: `../pkgs/pi-bolt/AGENTS.md`, section "Documentation & Knowledge
Hub".

## Known limitations

- Images and other non-markdown files next to documents are not staged, so
  relative image links 404 in the hub.
- A source project's broken internal anchors are build warnings
  (`[link_checker] internal_level = "warn"`), not failures, so one repo's stale
  links cannot block the site.
- The hub serves over plain HTTP inside the tailnet TLS tunnel on its own port;
  other `tailscale serve` paths on dev-1 (443, 8080, 9000) are untouched.
