# Umbrella?

One question, once a day: **take an umbrella or not**, and how sure the app is.
No temperature, wind, pressure or week view — just the rain that falls between
the time you leave home (X) and the time you come back (Y).

Android only (`com.kuhy.umbrella`), Flutter 3.47.5 (`.fvmrc`).

## How it decides

- Forecast: [Open-Meteo](https://open-meteo.com) **ensemble** API — free, no
  key, no account. Model `icon_seamless`: 40 forecast variants ("members"),
  and the only Open-Meteo ensemble with truly hourly precipitation (ECMWF and
  GFS spread each 3-hour total over three hours, which hides short showers).
- Rain = `rain + showers` per member. Snowfall is ignored; sleet and freezing
  rain arrive as `rain`.
- A member is **wet** if any hour of the outing has ≥ 0.2 mm. Open-Meteo
  stamps each value with the *end* of its hour, so leaving at 08:30 counts
  the bucket stamped 09:00 (08:00–09:00) onwards.
- Chance of rain = wet members / members. **Umbrella** at ≥ 30 % (setting).
- Home and an optional destination are both checked; the wetter one wins.

## When it notifies

- Per-weekday plan (default Mon–Fri 08:00 → 17:00, weekends off).
- One notification **30 min before leaving** (setting, 10–120 min), computed
  when the alarm fires — never pre-baked the night before.
- A re-check 5 min before leaving notifies again **only if the answer flipped**.
- No network: falls back to the last saved forecast and says how old it is;
  no forecast at all: "Couldn't check the rain" (never silent).
- Exact alarms via `USE_EXACT_ALARM` (granted at install), re-armed on every
  launch, every fire and after reboot.

## Run

```bash
~/.claude/scripts/phone_deploy.sh ~/src/umbrella            # debug on the phone
~/.claude/scripts/phone_deploy.sh ~/src/umbrella --release  # needs android/key.properties
```

## Check a verdict independently

`scripts/crosscheck_verdict.sh` recomputes the chance of rain with curl + jq
only, sharing no code with the app:

```bash
~/src/umbrella/scripts/crosscheck_verdict.sh 52.2342 20.9767 08:00 17:00
# hours=9 usable=40 wet=39 share=98%
```

## Test

```bash
flutter analyze && flutter test --coverage   # or: bash scripts/ci_mirror.sh
```
