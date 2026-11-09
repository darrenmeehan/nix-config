# pi-messenger-bridge crashes Pi-Bolt

**Status:** upstream Pi-Bolt/Bun bug; workaround is to remove or lazy-load the
extension.
**Last checked:** 2026-11-09.

## Environment

- Fedora x86_64, Nix Home Manager.
- Pi-Bolt 1.0.8, source-built (`linux-x64-baseline`, JIT off, Pi 1.4.0).
- Reproduced with the same extension on:
  - the official prebuilt Pi-Bolt 1.0.8 (`pi-bolt-linux-x64-baseline`);
  - the official prebuilt Pi-Bolt 1.1.7 (Pi 1.5.0) — still crashes.
- `pi-messenger-bridge` 0.4.0, the latest on npm as of 2026-11-09.
- Node `pi` 1.4.0 with the full extension: works.

## Symptom

With a trivial prompt, after roughly 25–30 seconds:

```text
panic(main thread): Segmentation fault at address 0x8
```

Exit code 139. Crash reports:

- Pi-Bolt 1.0.8:
  <https://pi-bolt.opensec.in/crash/1.4.3/la294dd80dkhEugggCy9qu8Cs00q/Cy5pr8Cstzq/Cyiyq/Cymuq/C8jtq/Cussq/Cgrk8wDktg8wD6n87wD8v77wDkvwixDox5/vDiy967Cm3wg7C45lilDk110uDowr0uDms8ruDA2AQ>
- Pi-Bolt 1.1.7:
  <https://pi-bolt.opensec.in/crash/1.4.3/la28bfc8a6khEugggCy9qu8Cs20q/Cy5pr8Csvzq/Cykyq/Cyouq/C8ltq/Cuusq/Cgrn8wDktj8wD6n/7wD8v+7wDkvzixDox8/vDiy967Cm3wg7C47lilDk140uDowu0uDms/ruDA2AQ>

## Reproduction

```bash
pi-bolt -p --no-session --no-tools --no-extensions \
  -e ~/.pi/agent/npm/node_modules/pi-messenger-bridge \
  --model <configured-model> \
  "Reply with exactly: OK"
```

The same command with Node `pi` succeeds.

## Bisect

| Case | Result |
| --- | --- |
| `pi-messenger-bridge` alone | crash (139) |
| the other 12 extensions together | OK |
| the full set | crash |
| official Pi-Bolt 1.0.8 / 1.1.7 | crash |
| Node `pi` | OK |
| Discord / Matrix / Slack / Telegram imports alone | OK |
| WhatsApp import alone | crash |
| all transports except WhatsApp | OK |
| WhatsApp + any other transport | crash |

The extension's `index.js` and `ui/main-menu.js` import all transports
statically, so "importing `main-menu`" also loads WhatsApp.

## Root cause

Two Pi-Bolt/Bun-specific problems, both in `dist/transports/whatsapp.js`:

1. **Literal dynamic import.** `loadBaileys` contains:

   ```js
   async function loadBaileys() {
     const baileys = await import("@whiskeysockets/baileys");
     return baileys;
   }
   ```

   A no-op extension that imports this module crashes Pi-Bolt even though
   `loadBaileys` is never called. A static import of `@whiskeysockets/baileys`
   works, and changing the specifier to a variable works:

   ```js
   const baileysPackage = "@whiskeysockets/baileys";
   const baileys = await import(baileysPackage);
   ```

   This fixes WhatsApp alone.

2. **Module combination.** With the variable fix in place, WhatsApp alone works,
   but **WhatsApp plus any other transport** still crashes (same crash link as
   the full extension). All transports without WhatsApp work.

The Matrix native module
(`@matrix-org/matrix-sdk-crypto-nodejs`) is not the cause; it loads fine on its
own. `qrcode-terminal` alone also loads fine.

## Workaround

Removed `npm:pi-messenger-bridge` from `~/.pi/agent/settings.json` `packages` on
2026-10-31.

Backup: `~/.pi/agent/settings.json.bak-20261031172549`.

After removal, a normal `pi-bolt -p …` call with the remaining extensions
returns successfully. Node `pi` also no longer loads the extension.

For the extension itself, the practical workaround is to lazy-load the WhatsApp
provider only when `config.whatsapp` is present, and to use the variable
specifier for Baileys. That avoids the crash for users not using WhatsApp; a
user who configures WhatsApp alongside another transport still needs the
Pi-Bolt/Bun fix.

## Next

- Report to `opensec-git/Pi-Bolt` with the two crash links and the minimal
  import-only reproduction; this is in the AOT module loader, not the package.
- Report to the `pi-messenger-bridge` repository with the variable-specifier and
  lazy-load patches.
- Re-test after a Pi-Bolt or extension release. `pi-messenger-bridge` 0.4.0 is
  still the latest.
