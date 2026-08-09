# Daily-Mobility - Garmin Forerunner 255 Music

Monkey C **device app** that guides you through a daily mobility & stretching routine and records it as a normal Garmin activity.

## Features

- **Guided routine**: steps through your exercises one by one with name, description and a large countdown.
- **Two exercise types**: **time** steps count down and auto-advance at 0; **rep** steps show the target (e.g. `20 ×`) and wait for you to press **Select**.
- **Editable in a CSV**: exercises, descriptions and durations live in `routine.csv` — no Monkey C needed.
- **Activity recording**: records time, heart rate and calories as a flexibility-training activity named **Daily Mobility Routine** (instead of Garmin's default "Lunch Workout") that syncs to Strava through Garmin Connect.
- **No GPS**: no positioning, no map data, no distance — nothing to wait for at the start.

---

## Editing the routine

The routine is a semicolon-separated CSV. **Semicolons** are the separator because the descriptions are full of commas.

```csv
name;description;type;value
Tiefe Hocke;Fersen am Boden, Oberkörper aufrecht, leicht wiegen;time;1:00
Fußkreisen vorwärts;Rückenlage, Füße anziehen und volle Kreise ziehen;reps;15
Wade rechts;Bein durchgestreckt, Gewicht auf die Wade, Ferse zum Boden;time;0:30
```

- `name` — keep it ≤ 24 characters or it gets cramped on the display.
- `description` — ≤ 70 characters, shown as up to 3 wrapped lines.
- `type` — `time` or `reps`.
- `value` — for `time` a duration `m:ss` (e.g. `1:00`, `0:30`); a bare number is read as seconds, and an empty value defaults to `1:00`. For `reps` a whole number.

Two routines ship with the project:

- `routine.csv` — the full routine (~21 min).
- `routine-15min.csv` — a trimmed morning version (~15 min).

`routine.csv` is the one that gets built into the app. To use the short one, either copy it over `routine.csv` or build with `make build ROUTINE_CSV=routine-15min.csv`.

After editing, rebuild and redeploy:

```bash
make deploy
```

`tools/build_routine.py` validates the CSV (it names the offending line on any error) and prints the estimated total duration, so you can see whether you are landing near your target time.

---

## Adding the app to your Garmin watch

### Prerequisites

- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) installed via the SDK Manager, with the **Forerunner 255 Music** device and an SDK downloaded (includes compiler and simulator).
- A developer key (see below).
- Your Forerunner 255 Music.

### 1. Generate a developer key

Building for a device needs a developer key. `make` creates one for you the first time:

```bash
make key
```

This writes `developer_key.pem` / `developer_key.der` (both are gitignored). You can also generate one from VS Code: Command Palette → **Monkey C: Generate a Developer Key**.

### 2. Build the app

```bash
make build
```

This regenerates `resources/routine.json` from the CSV and compiles `bin/Daily-Mobility.prg` for `fr255m`. The build finds the SDK from the SDK Manager's current-SDK setting, so there is no need to put `monkeyc` on your `PATH`.

### 3. Run in the simulator

```bash
make sim
```

Opens the Connect IQ simulator with the Forerunner 255 Music profile and loads the app. Testing here is much faster than sideloading — do it before every install.

### 4. Install on your physical watch

On the watch, set **Settings → System → USB Mode → Garmin** (not MTP), then connect it by USB. It mounts as a drive, and:

```bash
make deploy
```

copies the `.prg` into `GARMIN/APPS/`. Eject the watch and disconnect. If the watch does not mount as a drive (USB mode still on MTP), use [OpenMTP](https://openmtp.ganeshrvel.com/) to copy `bin/Daily-Mobility.prg` into `GARMIN/APPS/` manually.

After installing, the app appears in the watch's app list.

---

## Strava sync

There is nothing to configure in the app. Link **Garmin Connect ↔ Strava** once in your Garmin Connect account settings; after that every recorded activity is pushed to Strava automatically, named **Daily Mobility Routine** (change `SESSION_NAME` in `source/SessionManager.mc` to rename it). It shows up as a *Workout*; to make it appear as *Weight Training* instead, change `SUB_SPORT` in the same file to `SUB_SPORT_STRENGTH_TRAINING`.

---

## Project layout

```
daily-mobility/
├── Makefile                    # routine / build / sim / deploy
├── routine.csv                 # the routine you edit (full, ~21 min)
├── routine-15min.csv           # trimmed morning version (~15 min)
├── manifest.xml                # watch-app, fr255m, Fit + Sensor permissions
├── monkey.jungle
├── tools/
│   └── build_routine.py        # CSV -> resources/routine.json (validated)
├── resources/
│   ├── resources.xml           # references routine.json as a jsonData resource
│   ├── strings.xml
│   ├── routine.json            # generated; do not commit
│   └── drawables/
│       ├── drawables.xml
│       └── launcher_icon.png
└── source/
    ├── DailyMobilityApp.mc     # app entry, session lifecycle
    ├── RoutineModel.mc         # exercise list, index, progress
    ├── SessionManager.mc       # activity recording (name + sport mapping)
    ├── StartView.mc            # start screen
    ├── ExerciseView.mc         # exercise screen: countdown, reps, pause, HR
    ├── ExerciseDelegate.mc     # button handling + finish menu
    └── SummaryView.mc          # end summary + save
```

## Permissions

The manifest requests only `Fit` and `Sensor`:

```xml
<iq:permissions>
  <iq:uses-permission id="Fit"/>
  <iq:uses-permission id="Sensor"/>
</iq:permissions>
```

No `Positioning` (no GPS search on start) and no `Communications` (no backend).

## Button mapping (Forerunner 255 Music)

- **Select** – on a time step: **pause / resume**; on a rep step: **finish the exercise and continue**.
- **Down** – next exercise (also acts as *skip*).
- **Up** – previous exercise.
- **Back** – finish menu: **Save & Finish**, **Discard** or **Cancel**.

## Technical notes

- **View–Delegate pattern**: `StartView`/`StartDelegate`, `ExerciseView`/`ExerciseDelegate`, `SummaryView`/`SummaryDelegate`.
- **Timer**: `Timer.Timer` every 1000 ms with `WatchUi.requestUpdate()`; stopped in `onHide` and restarted in `onShow` so it never runs in the background.
- **Routine as a resource**: Connect IQ apps cannot read files from the watch at runtime, so `routine.csv` is compiled into the `.prg` as a JSON resource at build time.
- **Heart rate**: `Activity.getActivityInfo().currentHeartRate`, shown as `--` until the sensor is ready.
- **Session safety**: a running session is saved on app exit so a workout is never lost.
