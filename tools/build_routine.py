#!/usr/bin/env python3
"""Turn a routine CSV into a JSON resource.

    build_routine.py <csv> <json> [display name]

Connect IQ apps cannot read arbitrary files from the watch at runtime, so every
routine is compiled into the .prg as a JSON resource. Edit the CSV, run this
(via `make routine` / `make build`) and the change ends up in the app. The app
ships two routines; both use this same generator, only with different arguments.
The display name is the title the selection screen shows for the routine.

CSV format (semicolon-separated, because the descriptions are full of commas):

    name;description;type;value

  type  : "time" or "reps"
  value : for time, a duration "m:ss" (e.g. 1:00) or a bare number of seconds,
          or empty -> default 1:00; for reps, a positive whole number.

Validation errors name the offending CSV line and abort, rather than silently
"fixing" the data or dumping a traceback.
"""

import json
import re
import sys

DEFAULT_TITLE = "Daily-Mobility"
DEFAULT_TIME = 60           # seconds, used when a time step leaves value empty
SECONDS_PER_REP = 3         # only for the duration estimate
TRANSITION_SECONDS = 5      # countdown before every step; mirrors ExerciseView.REST_SECONDS

TIME_RE = re.compile(r"^(\d+):([0-5]\d)$")

NAME_WARN = 20
NAME_MAX = 24
DESC_WARN = 60
DESC_MAX = 70


def fail(line_no, message):
    """Print a human-readable error pointing at the CSV line and abort."""
    sys.stderr.write("Error, line {}: {}\n".format(line_no, message))
    sys.exit(1)


def parse_time(value, line_no):
    """Return seconds for a time step, or fail with a clear message."""
    value = value.strip()
    if value == "":
        return DEFAULT_TIME
    m = TIME_RE.match(value)
    if m:
        seconds = int(m.group(1)) * 60 + int(m.group(2))
    elif value.isdigit():
        seconds = int(value)          # bare seconds, tolerated
    else:
        fail(line_no, "'{}' is not a valid duration (expected m:ss, e.g. 1:00)".format(value))
    if seconds <= 0:
        fail(line_no, "duration must be greater than 0")
    return seconds


def parse_reps(value, line_no):
    value = value.strip()
    if not value.isdigit() or int(value) <= 0:
        fail(line_no, "'{}' is not a positive whole number of reps".format(value))
    return int(value)


def build(csv_path):
    steps = []
    warnings = []
    with open(csv_path, encoding="utf-8-sig") as f:
        rows = f.read().splitlines()

    if not rows:
        fail(1, "routine file is empty")

    # Header is line 1; skip it. Data lines keep their real 1-based numbers.
    for line_no, raw in enumerate(rows[1:], start=2):
        if raw.strip() == "":
            continue
        parts = raw.split(";")
        if len(parts) < 4:
            fail(line_no, "expected 4 semicolon-separated columns, got {}".format(len(parts)))

        name = parts[0].strip()
        desc = parts[1].strip()
        step_type = parts[2].strip().lower()
        value = parts[3].strip()

        if name == "":
            fail(line_no, "name must not be empty")
        if len(name) > NAME_WARN:
            warnings.append("line {}: name is {} chars (keep it <= {})".format(
                line_no, len(name), NAME_MAX))
        if len(desc) > DESC_WARN:
            warnings.append("line {}: description is {} chars (keep it <= {})".format(
                line_no, len(desc), DESC_MAX))

        if step_type == "time":
            steps.append({"n": name, "d": desc, "t": 0, "v": parse_time(value, line_no)})
        elif step_type == "reps":
            steps.append({"n": name, "d": desc, "t": 1, "v": parse_reps(value, line_no)})
        else:
            fail(line_no, "type must be 'time' or 'reps', got '{}'".format(step_type))

    if not steps:
        fail(1, "routine has no exercises")

    return steps, warnings


def estimate_seconds(steps):
    total = len(steps) * TRANSITION_SECONDS
    for s in steps:
        total += s["v"] if s["t"] == 0 else s["v"] * SECONDS_PER_REP
    return total


def main():
    csv_path = sys.argv[1] if len(sys.argv) > 1 else "routine.csv"
    out_path = sys.argv[2] if len(sys.argv) > 2 else "resources/routine.json"
    title = sys.argv[3] if len(sys.argv) > 3 else DEFAULT_TITLE

    steps, warnings = build(csv_path)

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({"title": title, "steps": steps}, f, ensure_ascii=False, indent=2)
        f.write("\n")

    for w in warnings:
        sys.stderr.write("Warning, {}\n".format(w))

    total = estimate_seconds(steps)
    print("{} ({}): {} exercises, estimated {}:{:02d} min -> {}".format(
        csv_path, title, len(steps), total // 60, total % 60, out_path))


if __name__ == "__main__":
    main()
