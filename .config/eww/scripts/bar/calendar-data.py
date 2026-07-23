#!/usr/bin/env python3
"""Month-grid JSON for the kw-calendar popover.

Usage: calendar-data.py [print|reset|prev|next]
  print  - emit JSON for the stored month offset to stdout
  reset  - jump back to the current month, push via `eww update`
  prev   - go one month back, push via `eww update`
  next   - go one month forward, push via `eww update`

Weeks start on Sunday and the grid is always padded to 6 rows so the
popover height never jumps while navigating.
"""

import calendar
import datetime
import json
import os
import subprocess
import sys

STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "kw-calendar.offset")


def read_offset() -> int:
    try:
        with open(STATE) as f:
            return int(f.read().strip())
    except (OSError, ValueError):
        return 0


def build(offset: int) -> str:
    today = datetime.date.today()
    year, month0 = divmod(today.year * 12 + (today.month - 1) + offset, 12)
    month = month0 + 1

    weeks = calendar.Calendar(firstweekday=6).monthdatescalendar(year, month)
    while len(weeks) < 6:  # pad to a stable 6-row grid
        last = weeks[-1][-1]
        weeks.append([last + datetime.timedelta(days=i) for i in range(1, 8)])

    # Weekday header, Sunday-first; `now` lights up today's column while the
    # current month is shown. Iraq weekend = Fri/Sat (weekday() 4/5).
    names = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    today_col = (today.weekday() + 1) % 7  # Mon=0 → Sunday-first index
    days = [
        {"n": n, "now": offset == 0 and i == today_col}
        for i, n in enumerate(names)
    ]

    return json.dumps(
        {
            "month": calendar.month_name[month],
            "year": str(year),
            "sub": f"{calendar.day_name[today.weekday()]}, {calendar.month_name[today.month]} {today.day}",
            "off": offset,
            "days": days,
            "weeks": [
                [
                    {
                        "d": d.day,
                        "cur": d.month == month,
                        "today": d == today,
                        "we": d.weekday() in (4, 5),
                    }
                    for d in week
                ]
                for week in weeks
            ],
        },
        separators=(",", ":"),
    )


def main() -> None:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "print"
    offset = read_offset()
    if cmd == "reset":
        offset = 0
    elif cmd == "prev":
        offset -= 1
    elif cmd == "next":
        offset += 1

    with open(STATE, "w") as f:
        f.write(str(offset))

    data = build(offset)
    if cmd == "print":
        print(data)
    else:
        subprocess.run(["eww", "update", f"kw-cal={data}"], check=False)


if __name__ == "__main__":
    main()
