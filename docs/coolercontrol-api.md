# CoolerControl API Notes

Reference for the `coolercontrol/` stow package (temperature profiles + Steam/game auto
mode switch, see [omarchy.md](omarchy.md) for the user-facing setup and curve values).
This document is the technical record of how `coolercontrold`'s REST API actually
behaves, reverse-engineered live against v4.3.1-2 since it has no published OpenAPI
spec. Keep it in English on purpose: it's an API reference, not usage docs.

## What's stowed

- `coolercontrol/.local/bin/coolercontrol-provision` — idempotent script that creates/
  updates the `Silencio`/`Rendimiento` functions, profiles and modes via the API.
- `coolercontrol/.local/bin/coolercontrol-mode-watcher` — listens to Hyprland's
  `.socket2.sock` and switches the active mode based on open window classes.
- `coolercontrol/.config/coolercontrol-modes/curves.json` — the only file to edit to
  change curve numbers.
- `coolercontrol/.config/coolercontrol-modes/gaming-classes.conf` — window-class glob
  patterns that trigger `Rendimiento`.
- `coolercontrol/.config/systemd/user/coolercontrol-mode-watcher.service`.

`scripts/bootstrap.sh:ensure_coolercontrol_mode_watcher()` stows the package, runs the
provisioning script and enables the service — but only once the API token below exists.

## Prerequisite: API token

The daemon rejects unauthenticated requests (`{"error":"Invalid Credentials"}`) and has
no CLI for this. Create a token from the GUI (Settings → Access Tokens) **with write
access checked** — a read-only token 403s on every POST/PUT with
`{"error":"This token does not have write access."}`. Save it to:

```sh
install -d -m 700 ~/.local/state/coolercontrol-modes
umask 077; printf '%s' '<TOKEN>' > ~/.local/state/coolercontrol-modes/api-token
```

Sent as `Authorization: Bearer <token>` on every request. No expiry handling needed —
tokens created without an `expires_at` don't expire.

## Discovery technique

No OpenAPI/Swagger endpoint is exposed. The fastest way to find the right HTTP verb for
a route is to send a deliberately wrong one (e.g. `PATCH`) and read the `Allow` response
header — Actix returns it on every 405:

```sh
curl -s -i -H "Authorization: Bearer $TOKEN" -X PATCH "http://127.0.0.1:11987/profiles/$UID" | head -12
# ... allow: DELETE
```

This is how every quirk below was found. `strings -a /usr/bin/coolercontrold | grep -oE '/devices/\{[a-zA-Z_]*\}[a-zA-Z0-9_/{}-]*'` also dumps the actix route table directly from the binary — useful to confirm a path exists before guessing its body.

## Devices (`GET /devices`)

Resolve devices by `name` substring, not `uid` — the uid is a hash of hardware identity
and changes if the Kraken moves USB ports or the GPU changes. On this machine:

| name (as returned by the API) | role |
|---|---|
| `12th Gen Intel(R) Core(TM) i7-12700K` | CPU temp source, `temp1` |
| `NZXT Kraken Z (Z53, Z63 or Z73)` | AIO — channels `pump`, `fan`; temp `liquid` |
| `NZXT RGB & Fan Controller` | fan hub — only `fan3` has anything wired |
| `NVIDIA GeForce RTX 3080` | GPU — channels `fan1`, `fan2`; temp `GPU Temp` (via NVML, no Coolbits needed) |
| `nct6687` (motherboard Super I/O) | present but unused — `fan1` is the Kraken pump's own tachometer wired to CPU_FAN, `fan2`–`fan8` and the hub's `fan1`/`fan2` have nothing connected |

`info.temps` / `info.channels` can come back as either a JSON object (keys) or an array
— handle both defensively.

## Functions (`GET/POST /functions`)

The full schema is wider than the fields you'd actually use for a `Standard` function.
Missing any of these on POST → `422 missing field <name>`:

```json
{
  "uid": "<client-generated UUID>",
  "name": "...",
  "f_type": "Standard",
  "duty_minimum": 15, "duty_maximum": 100,
  "response_delay": 3, "deviance": 2.0, "only_downward": true,
  "step_size_min_decreasing": 0, "step_size_max_decreasing": 0,
  "sample_window": null, "threshold_hopping": true, "bypass_min_at_extremes": false
}
```

The client picks `uid` (a UUID, e.g. from `/proc/sys/kernel/random/uuid`) and the server
keeps it as given — confirmed via `GET /functions` after creating.

## Profiles (`GET/POST /profiles`, update via `PUT /profiles`)

Same "client picks uid, server keeps it" behavior as functions. Full schema, again wider
than a `Graph` profile needs:

```json
{
  "uid": "<client-generated UUID>",
  "name": "...", "p_type": "Graph",
  "speed_profile": [[30, 20], [50, 20]],
  "temp_source": { "temp_name": "temp1", "device_uid": "<cpu device uid>" },
  "function_uid": "<function uid>",
  "speed_fixed": null, "temp_min": null, "temp_max": null,
  "member_profile_uids": [], "mix_function_type": null, "offset_profile": null
}
```

**Updating an existing profile is not `PUT /profiles/{uid}`** — that route only allows
`DELETE` (confirmed via the `Allow` header trick above). The actual update is
`PUT /profiles` (the collection), with `uid` inside the body identifying which one to
replace. `POST /profiles` on a uid that already exists 500s with
`"Profile already exists. Use the patch operation to update it."` — despite the error
text saying "patch", the working verb is `PUT`, not `PATCH` (`PATCH /profiles` 405s).

## Assigning a profile to a channel (`PUT /devices/{device_uid}/settings/{channel_name}/profile`)

```json
{ "channel_name": "fan", "profile_uid": "<profile uid>" }
```

`channel_name` is required in the body even though it's already in the URL path. Without
it the request still returns `200`, but the engine later throws
`500 Internal Error: Profile should be present` when it tries to apply the setting —
this reads like a missing-field validation error but isn't; check the body first before
suspecting the profile itself.

`GET /devices/{device_uid}/settings` returns the currently-applied settings for that
device, each with `channel_name`, `speed_fixed`, `lighting`, `lcd`, `reset_to_default`,
`profile_uid`.

## Modes (`GET/POST /modes`, `GET/POST /modes-active/{uid}`)

Unlike functions/profiles, **the server ignores any `uid` sent in `POST /modes` and
assigns its own** — re-fetch `GET /modes` and match by `name` after creating one.

`POST /modes` already captures the current live state of every device as the mode's
`device_settings` snapshot — there is no separate "save current state into this mode"
endpoint. (`PUT /modes/{uid}/settings` exists per the `Allow` header, but calling it
after creation 404s with `"Mode not found"` — it's for a different purpose, not needed
for this workflow.)

Because profile updates (`PUT /profiles`) keep the same `uid`, a mode's captured
`device_settings` (which only reference `profile_uid`, not the curve itself) stay valid
even after editing `curves.json` and re-running `coolercontrol-provision` — modes never
need to be re-captured after their first creation.

Activate: `POST /modes-active/{uid}` (empty body). Read current: `GET /modes-active` →
`{"current_mode_uid": "...", "previous_mode_uid": "..."}`.

## Rebuilding from scratch (fresh machine / after a CoolerControl reinstall)

```sh
# 1. Package + service already handled by scripts/install-packages.sh:ensure_coolercontrol()
#    and stow_packages (STOW_PACKAGES includes coolercontrol on Omarchy).
cd ~/dotfiles && ./scripts/bootstrap.sh

# 2. Create the API token from the GUI (Settings > Access Tokens, write access ON),
#    then save it — bootstrap checks for this file and skips enabling the watcher
#    until it exists:
install -d -m 700 ~/.local/state/coolercontrol-modes
umask 077; printf '%s' '<TOKEN>' > ~/.local/state/coolercontrol-modes/api-token

# 3. Re-run bootstrap (or do it directly):
coolercontrol-provision
systemctl --user daemon-reload
systemctl --user enable --now coolercontrol-mode-watcher.service

# 4. Verify
curl -s -H "Authorization: Bearer $(cat ~/.local/state/coolercontrol-modes/api-token)" \
  http://127.0.0.1:11987/modes-active | jq .
journalctl --user -u coolercontrol-mode-watcher.service -f
```

If device names changed (new GPU, Kraken on a different USB port), `coolercontrol-provision`
aborts early with `no encontré ningún dispositivo para: <patterns>` and a dump of
`GET /devices` names — update the `resolve_device` patterns in the script, not the
`curves.json` numbers.
