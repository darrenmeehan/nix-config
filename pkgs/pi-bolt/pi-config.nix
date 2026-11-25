# The pi / pi-bolt extension set and settings, shared by the laptop
# (home/configs/pi-bolt.nix) and dev-1 (hosts/dev-1). One list, two consumers,
# so the machines cannot drift.
#
# `pi-curam-security = false` leaves out the pi-curam-security driver extension and the
# `curam-membrane` engine it spawns. dev-1 gets that variant because it is still
# work in progress.
#
# `pkgs` must carry `pi-bolt`, `pi-extensions` (and `curam-membrane-driver` when
# `pi-curam-security = true`) — the flake's overlay adds them; they are not in nixpkgs.
{ pkgs, pi-curam-security ? true }:
let
  inherit (pkgs) lib;
  curamDriver = "${pkgs.curam-membrane-driver}/drivers/pi";
in
rec {
  # Extensions compiled into the executable (`withExtensions`). Each is named in
  # the manifest, so pi lists it as a built-in extension (`builtin:<name>`) and a
  # run-time copy of the same extension replaces it rather than registering its
  # tools twice.
  #
  # Left out because they read their own files at run time, which a compiled
  # executable does not have (import.meta points into the executable, `$bunfs`):
  # bigpowers scans <package>/skills/ at load; opensec-pi-fff, opensec-pi-todo
  # and opensec-pi-subagents are thin entries that nativeRequire ./core.cjs
  # beside themselves, on every factory call, so /reload and upgrades work (the
  # subagents one also discovers .pi/agents/*.md and ~/.pi/agent/agents/*.md at
  # run time).
  #
  # Left out for other reasons, also loading from their files as before:
  # pi-agent-browser-native, whose entry module's top-level bytecode is over
  # pi-bolt's AOT candidate limit, and @plannotator/pi-extension, whose diagram
  # engine imports node-canvas, a native addon nothing here builds.
  #
  # A compiled-in extension loads whether or not it is enabled, so anything that
  # cannot be compiled in fails the start for every session, not just its own.
  extensions = [
    "${pkgs.pi-extensions}/node_modules/@aliou/pi-guardrails"
    "${pkgs.pi-extensions}/node_modules/@heyhuynhgiabuu/pi-diff"
    "${pkgs.pi-extensions}/node_modules/@melihmucuk/leash"
    "${pkgs.pi-extensions}/node_modules/@mjasnikovs/pi-task"
  ] ++ lib.optional pi-curam-security curamDriver;

  # Pi's own package list, untouched: `pi` loads every entry from its files.
  packages = [
    "npm:bigpowers"
    "npm:@dietrichgebert/ponytail"
    "npm:@plannotator/pi-extension"
    "npm:@mjasnikovs/pi-task"
    "npm:pi-agent-browser-native"
    "npm:@heyhuynhgiabuu/pi-diff"
    "npm:@aliou/pi-guardrails"
    "npm:@melihmucuk/leash"
  ] ++ lib.optional pi-curam-security curamDriver;

  # `piBolt.packages` is an overlay on that list: an exclusion takes out an
  # extension compiled into the executable (a run-time copy would replace it, and
  # be interpreted), and an addition brings in one that only pi-bolt has. `pi`
  # ignores this section. A host that compiles a *different* set must therefore
  # get its exclusions from here too, or it silently drops extensions: see
  # hosts/dev-1/README.md.
  piBoltPackages = [
    "-npm:@mjasnikovs/pi-task"
    "-npm:@heyhuynhgiabuu/pi-diff"
    "-npm:@aliou/pi-guardrails"
    "-npm:@melihmucuk/leash"
  ] ++ lib.optional pi-curam-security "-${curamDriver}" ++ [
    "npm:opensec-pi-todo"
    "npm:opensec-pi-fff"
    "npm:opensec-pi-subagents"
  ];

  # ~/.pi/agent/settings.json. A store file is read-only, so neither pi nor
  # pi-bolt can save settings changes from inside a session (`/model` and the
  # like show the change but do not keep it): edit this and switch.
  # `lastChangelogVersion` and `extensionChangelogVersions` are only bookkeeping
  # and are left to fail. Host-specific keys (e.g. `remoteControl`) are added by
  # the consumer.
  settings = {
    defaultModel = "deepseek/deepseek-v4.1-flash-1017";
    defaultProvider = "openrouter";
    defaultThinkingLevel = "high";
    hideThinkingBlock = true;
    theme = "dark";
    enableInstallTelemetry = false;
    inherit packages;
    piBolt = {
      packages = piBoltPackages;
      packagesOverlay = true;
    };
  };

  # ~/.pi/agent/extensions/guardrails.json — the same file `pi` loads from npm
  # and `pi-bolt` loads compiled in. `gh` writes to GitHub are auto-denied: no
  # prompt, and `terminate` ends the turn so the agent asks instead of retrying.
  # Reads (`gh pr view`/`diff`/`list`/`checks`) and `git` are untouched. `gh api`
  # is denied wholesale, since it is the escape hatch around the verb list.
  #
  # A denylist over the literal command, not a sandbox: `curl` to
  # api.github.com, or any other client, still gets through.
  #
  # `permissionGate.allowedPatterns` is checked before both the auto-deny list
  # and the built-in dangerous-command matchers, so it is the one way to let a
  # command through without a confirmation prompt. Scratch dirs under /tmp are
  # the only delete allowed: every target must be `/tmp/…` or `/var/tmp/…`, no
  # `..` in a target (a traversal would leave /tmp), and no `$(…)`, backticks,
  # quotes or `;`/`&&`/`|` (the whole command is one string here, so anything
  # that could carry a second command stays gated). leash independently
  # realpath-resolves the target and allows /tmp, so this only removes the
  # prompt. `rm -rf /tmp` itself is not covered — that one still asks.
  #
  # `version` is the @aliou/pi-guardrails release this file is written for
  # (pkgs/pi-extensions/npm/package-lock.json). Without it guardrails runs its
  # migrations on every load, stamps the version and tries to save the result —
  # into a read-only store file, so it fails with EACCES and repeats the next
  # session. Bump it when the extension's own migrations change this file.
  guardrails = {
    version = "0.23.0";
    permissionGate.allowedPatterns = [
      {
        pattern = "^(?:rm|rmdir|unlink)\\s+(?:-[A-Za-z]+\\s+)*(?:/(?:tmp|var/tmp)/(?!\\S*\\.\\.)[^\\s;&|$()<>`'\"\\\\]*\\s*)+$";
        regex = true;
        description = "Deletes whose every target is under /tmp or /var/tmp.";
      }
    ];
    permissionGate.autoDenyPatterns = [
      {
        pattern = "\\bgh\\s+(pr|issue|release|repo|secret|variable|workflow|gist|label|ruleset|cache|project|discussion)\\s+(create|edit|merge|comment|close|reopen|ready|review|delete|set|run|sync|upload|download|rename|transfer|pin|unpin|lock|unlock|update|add|remove|clear)\\b";
        regex = true;
        terminate = true;
        description = "GitHub write through the gh CLI. Ask the user to run it.";
      }
      {
        pattern = "\\bgh\\s+api\\b";
        regex = true;
        terminate = true;
        description = "gh api is the bypass around the gh write gate. Ask the user to run it.";
      }
    ];
  };
}
