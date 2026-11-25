#!/usr/bin/env python3
"""hub-sync - stage every source project's docs/ into a Zola site and build it.

    hub-sync [--root DIR] [--sources FILE] [--base-url URL]

The hub root (default ``$XDG_DATA_HOME/docs-hub``) holds the generated site and
is deliberately outside any git repository: the *source* repos keep their own
docs/ and stay the single source of truth. Each run rebuilds the staged content
from scratch, so running it twice in a row produces the same site.

Source frontmatter is YAML, Zola wants TOML, so staging rewrites the frontmatter
of every file it copies: missing keys are filled in (``project`` always,
``title``/``date``/``type``/``status`` from the file when the source has none).
A file whose YAML does not parse is reported and skipped - the rest of the site
still builds, because one bad file must not take the hub down.

shortcut: non-markdown assets (images) next to docs are not staged, so relative
image links render broken in the hub; add colocated-page staging when a source
needs its images published.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tomllib
from datetime import date as Date
from datetime import datetime, timezone
from pathlib import Path

import yaml

# The document is split into YAML frontmatter (optional) and a markdown body.
FRONTMATTER_RE = re.compile(
    r"\A---[ \t]*\r?\n(?P<yaml>.*?)\r?\n---[ \t]*(?:\r?\n|\Z)", re.S
)
# docs/specs/x.md -> type "spec". Anything outside these four is "doc".
TYPE_BY_DIR = {"specs": "spec", "research": "research", "runs": "run", "adr": "adr"}
TYPES = {"spec", "research", "run", "adr"}
STATUSES = {"draft", "verified", "archived"}
DEFAULT_TYPE = "doc"
DEFAULT_STATUS = "draft"

ROOT = Path(os.environ.get("DOCS_HUB_SRC") or Path(__file__).resolve().parent)


def log(message: str) -> None:
    print(message, flush=True)


def warn(message: str) -> None:
    print(f"WARN  {message}", file=sys.stderr, flush=True)


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.strip().lower()).strip("-")


# ── sources.toml ─────────────────────────────────────────────────────────────


def load_sources(path: Path) -> list[dict]:
    """Parse and validate the manifest. Manifest errors are fatal: a typo there
    would silently drop a project from the hub."""
    try:
        with path.open("rb") as handle:
            data = tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError) as error:
        sys.exit(f"hub-sync: cannot read {path}: {error}")

    entries = data.get("sources", [])
    if not isinstance(entries, list):
        sys.exit(f"hub-sync: {path}: `sources` must be a list of tables")

    sources: list[dict] = []
    seen: set[str] = set()
    for index, entry in enumerate(entries, 1):
        if not isinstance(entry, dict):
            sys.exit(f"hub-sync: {path}: source #{index} is not a table")
        project = entry.get("project")
        if not isinstance(project, str) or not project.strip():
            sys.exit(f"hub-sync: {path}: source #{index} needs a `project` slug")
        slug = slugify(project)
        if not slug:
            sys.exit(f"hub-sync: {path}: project `{project}` is not a usable slug")
        if slug in seen:
            sys.exit(f"hub-sync: {path}: project `{slug}` appears twice")
        if ("path" in entry) == ("remote" in entry):
            sys.exit(f"hub-sync: {path}: `{slug}` needs exactly one of `path`/`remote`")
        if "branch" in entry and "remote" not in entry:
            sys.exit(f"hub-sync: {path}: `{slug}`: `branch` only applies to `remote`")
        seen.add(slug)
        sources.append({**entry, "project": slug})
    return sources


def resolve_docs_dir(source: dict, root: Path) -> Path | None:
    """Return the directory to publish for one source, or None to skip it."""
    project = source["project"]
    if "path" in source:
        base = Path(os.path.expandvars(str(source["path"]))).expanduser()
        if not base.is_absolute():
            base = (ROOT / base).resolve()
        if not base.is_dir():
            warn(f"{project}: local path {base} does not exist, skipping")
            return None
    else:
        base = root / ".cache" / "remotes" / project
        branch = source.get("branch")
        try:
            if (base / ".git").is_dir():
                fetch = ["fetch", "--depth", "1", "origin"] + (
                    [str(branch)] if branch else []
                )
                git(fetch, base)
                git(["reset", "--hard", "FETCH_HEAD"], base)
            else:
                base.parent.mkdir(parents=True, exist_ok=True)
                clone = ["clone", "--depth", "1"] + (
                    ["--branch", str(branch)] if branch else []
                )
                git([*clone, str(source["remote"]), str(base)], root)
        except subprocess.CalledProcessError as error:
            warn(f"{project}: git {error.cmd[1]} failed in {base}, skipping")
            return None

    docs = base / str(source.get("docs", "docs"))
    if not docs.is_dir():
        warn(f"{project}: no {source.get('docs', 'docs')}/ in {base}, skipping")
        return None
    return docs


def git(args: list[str], cwd: Path) -> None:
    subprocess.run(
        ["git", *args],
        cwd=str(cwd),
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )


# ── frontmatter ──────────────────────────────────────────────────────────────


def toml_string(value: str) -> str:
    # JSON string escapes are a valid TOML basic string.
    return json.dumps(str(value), ensure_ascii=False)


def toml_array(values: list[str]) -> str:
    return "[" + ", ".join(toml_string(value) for value in values) + "]"


def rfc3339(value: object) -> str | None:
    """Normalise whatever a human wrote as `date:` to Zola's RFC3339 (UTC)."""
    moment: datetime | None
    if isinstance(value, datetime):
        moment = value
    elif isinstance(value, Date):
        moment = datetime(value.year, value.month, value.day)
    elif isinstance(value, str):
        try:
            moment = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
        except ValueError:
            return None
    else:
        return None
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=timezone.utc)
    return moment.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def humanise(stem: str) -> str:
    text = re.sub(r"[-_]+", " ", stem).strip()
    return text[:1].upper() + text[1:] if text else stem


def guess_title(body: str, stem: str) -> str:
    for line in body.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return humanise(stem)


def as_list(value: object) -> list[str]:
    if isinstance(value, (list, tuple)):
        return [str(item) for item in value if str(item).strip()]
    if value is None or str(value).strip() == "":
        return []
    return [str(value)]


def convert(md: Path, project: str, rel: Path) -> tuple[str, list[str], list[str]]:
    """Build the staged page text. Returns (text, warnings, errors)."""
    warnings: list[str] = []
    try:
        text = md.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as error:
        return "", warnings, [f"{md}: cannot read: {error}"]

    match = FRONTMATTER_RE.match(text)
    if match is None:
        meta: dict = {}
        body = text
    else:
        body = text[match.end() :]
        try:
            loaded = yaml.safe_load(match.group("yaml"))
        except yaml.YAMLError as error:
            detail = " ".join(str(error).split())
            return "", warnings, [f"{md}: malformed YAML frontmatter: {detail}"]
        if loaded is None:
            meta = {}
        elif isinstance(loaded, dict):
            meta = loaded
        else:
            return "", warnings, [
                f"{md}: frontmatter is {type(loaded).__name__}, not a mapping"
            ]

    # Directory-derived type, overridable by the frontmatter.
    doc_type = str(meta.get("type") or TYPE_BY_DIR.get(rel.parts[0], DEFAULT_TYPE))
    status = str(meta.get("status") or DEFAULT_STATUS)
    if doc_type not in TYPES and doc_type != DEFAULT_TYPE:
        warnings.append(f"{md}: type `{doc_type}` is not one of spec/research/run/adr")
    if status not in STATUSES:
        warnings.append(f"{md}: status `{status}` is not draft/verified/archived")

    date = rfc3339(meta.get("date")) if meta.get("date") else None
    if meta.get("date") and not date:
        warnings.append(f"{md}: date `{meta['date']}` is not a date, using file mtime")
    if not date:
        date = rfc3339(datetime.fromtimestamp(md.stat().st_mtime, timezone.utc))

    title = str(meta.get("title") or "").strip() or guess_title(body, rel.stem)

    # The manifest decides which project a document belongs to, not the
    # document: a wrong slug there would split one project across two views.
    declared = as_list(meta.get("project"))
    if declared and declared != [project]:
        warnings.append(
            f"{md}: project `{declared[0]}` does not match source `{project}` "
            "(the source slug wins)"
        )

    taxonomies: dict[str, list[str]] = {"project": [project]}
    agent = as_list(meta.get("agent"))
    if agent:
        taxonomies["agent"] = agent
    taxonomies["type"] = [doc_type]
    taxonomies["status"] = [status]
    tags = as_list(meta.get("tags"))
    if tags:
        taxonomies["tag"] = tags

    lines = ["+++", f"title = {toml_string(title)}", f"date = {date}", "[taxonomies]"]
    lines += [f"{kind} = {toml_array(values)}" for kind, values in taxonomies.items()]
    lines += ["+++", ""]
    return "\n".join(lines) + "\n" + body.lstrip("\n"), warnings, []


# ── site ─────────────────────────────────────────────────────────────────────


def stage(
    source: dict, docs: Path, content: Path, stats: dict
) -> None:
    """Copy one project's docs/ into content/projects/<slug>/, rewriting the
    frontmatter of each file on the way."""
    project = source["project"]
    dest = content / project
    dest.mkdir(parents=True, exist_ok=True)
    stats[project] = {"docs": 0, "warnings": [], "errors": []}
    entry = stats[project]

    for md in sorted(docs.rglob("*.md")):
        rel = md.relative_to(docs)
        text, warnings, errors = convert(md, project, rel)
        entry["warnings"] += warnings
        if errors:
            entry["errors"] += errors
            continue
        page = dest / rel.with_suffix("") / "index.md"
        page.parent.mkdir(parents=True, exist_ok=True)
        page.write_text(text, encoding="utf-8")
        entry["docs"] += 1


def ensure_indexes(
    content: Path, titles: dict[Path, str], counts: dict[Path, int]
) -> None:
    """Zola needs an _index.md in every directory it should publish, and the
    hub's index template reads projects/_index.md to list the projects. The
    document count is a section's own pages plus everything below it, which a
    template cannot work out, so the sync writes it into [extra]."""
    content.mkdir(parents=True, exist_ok=True)
    titles.setdefault(content / "projects", "Projects")
    titles.setdefault(content, "Docs Hub")
    for directory, title in titles.items():
        directory.mkdir(parents=True, exist_ok=True)
        if (directory / "index.md").exists():
            # A page bundle (docs/foo.md staged as foo/index.md): zola rejects a
            # section index in the same directory as a page called index.md.
            continue
        index = directory / "_index.md"
        if index.exists():
            continue
        extra = f"\n[extra]\ndocs = {counts[directory]}" if directory in counts else ""
        index.write_text(
            f'+++\ntitle = {toml_string(title)}\nsort_by = "date"{extra}\n+++\n',
            encoding="utf-8",
        )


def write_file(path: Path, data: bytes) -> None:
    """Write with normal permissions: the source files come from the nix store,
    where they are read-only, and the next run has to overwrite them."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        path.chmod(0o644)
    path.write_bytes(data)


def install_site_files(root: Path) -> None:
    """Copy the site definition (config, templates, static) out of the store
    into the writable hub root that zola is pointed at."""
    root.mkdir(parents=True, exist_ok=True)
    write_file(root / "config.toml", (ROOT / "config.toml").read_bytes())
    for name in ("templates", "static"):
        source = ROOT / name
        # Replace, don't merge: a template renamed or deleted upstream must not
        # linger in the hub root and keep being rendered.
        shutil.rmtree(root / name, ignore_errors=True)
        if not source.is_dir():
            continue
        for path in sorted(source.rglob("*")):
            if path.is_file():
                write_file(root / name / path.relative_to(source), path.read_bytes())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="hub-sync",
        description="Stage every project's docs/ into the Zola hub and build it.",
    )
    parser.add_argument(
        "--root",
        help="hub root directory (default $DOCS_HUB_ROOT or $XDG_DATA_HOME/docs-hub)",
    )
    parser.add_argument(
        "--sources", help="manifest to read (default <hub>/sources.toml in this repo)"
    )
    parser.add_argument(
        "--base-url", help="override the site base URL (default DOCS_HUB_BASE_URL)"
    )
    args = parser.parse_args(argv)

    root = Path(
        args.root
        or os.environ.get("DOCS_HUB_ROOT")
        or Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
        / "docs-hub"
    ).expanduser()
    sources_file = Path(args.sources).expanduser() if args.sources else ROOT / "sources.toml"
    base_url = args.base_url or os.environ.get("DOCS_HUB_BASE_URL")

    sources = load_sources(sources_file)
    install_site_files(root)

    content = root / "content" / "projects"
    shutil.rmtree(content, ignore_errors=True)

    stats: dict[str, dict] = {}
    skipped: list[str] = []
    for source in sources:
        docs = resolve_docs_dir(source, root)
        if docs is None:
            skipped.append(source["project"])
            continue
        stage(source, docs, content, stats)
        # Keep the project directory even when it has no documents, so the hub
        # lists every configured source.
        (content / source["project"]).mkdir(parents=True, exist_ok=True)

    # Every staged directory becomes a section (docs/specs/ gets its own listing
    # page inside a project).
    titles: dict[Path, str] = {}
    for directory in sorted(path for path in content.rglob("*") if path.is_dir()):
        parts = directory.relative_to(content).parts
        titles[directory] = parts[0] if len(parts) == 1 else humanise(parts[-1])
    counts = {
        content / project: entry["docs"]
        for project, entry in stats.items()
        if (content / project).is_dir()
    }
    ensure_indexes(content.parent, titles, counts)

    log(f"docs hub root: {root}")
    total = warnings = errors = 0
    for project, entry in stats.items():
        total += entry["docs"]
        warnings += len(entry["warnings"])
        errors += len(entry["errors"])
        log(f"  {project:<20} {entry['docs']:>4} docs")
    for project in skipped:
        log(f"  {project:<20}    - skipped (no docs/ found)")
    for entry in stats.values():
        for message in entry["warnings"] + entry["errors"]:
            warn(message)
    log(
        f"  {total} docs from {len(stats)} projects, "
        f"{warnings} warnings, {errors} files skipped"
    )

    if shutil.which("zola") is None:
        sys.exit("hub-sync: zola is not on PATH")

    build = ["zola", "--root", str(root), "build"]
    if base_url:
        build += ["--base-url", base_url]
    result = subprocess.run(build, text=True)
    if result.returncode != 0:
        return result.returncode
    log(f"built {root / 'public'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
