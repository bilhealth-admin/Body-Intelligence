#!/usr/bin/env bash

# Sourced by the step-local +8 driver. PRIVATE_UI_DIR must remain below
# RUNNER_TEMP because accessibility dumps can contain private account text.

tree_for() {
  idb ui describe-all --udid "$1" --json > "$PRIVATE_UI_DIR/$1.json"
}

has_marker() {
  local udid="$1"
  local marker="$2"
  tree_for "$udid"
  python3 - "$PRIVATE_UI_DIR/$udid.json" "$marker" <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as handle:
    payload = json.load(handle)
marker = sys.argv[2].casefold()
stack = list(payload if isinstance(payload, list) else [payload])
while stack:
    item = stack.pop()
    if not isinstance(item, dict):
        continue
    text = ' '.join(str(item.get(key) or '') for key in (
        'AXLabel', 'AXValue', 'title', 'placeholder', 'help', 'value', 'label',
    )).casefold()
    if marker in text:
        raise SystemExit(0)
    for value in item.values():
        if isinstance(value, dict):
            stack.append(value)
        elif isinstance(value, list):
            stack.extend(value)
raise SystemExit(1)
PY
}

has_markers() {
  local udid="$1"
  shift
  tree_for "$udid"
  python3 - "$PRIVATE_UI_DIR/$udid.json" "$@" <<'PY'
import json
import sys

with open(sys.argv[1], encoding='utf-8') as handle:
    payload = json.load(handle)
required = [value.casefold() for value in sys.argv[2:]]
stack = list(payload if isinstance(payload, list) else [payload])
all_text = []
while stack:
    item = stack.pop()
    if not isinstance(item, dict):
        continue
    all_text.extend(str(item.get(key) or '') for key in (
        'AXLabel', 'AXValue', 'title', 'placeholder', 'help', 'value', 'label',
    ))
    for value in item.values():
        if isinstance(value, dict):
            stack.append(value)
        elif isinstance(value, list):
            stack.extend(value)
haystack = ' '.join(all_text).casefold()
raise SystemExit(0 if all(marker in haystack for marker in required) else 1)
PY
}

wait_marker() {
  local udid="$1"
  local marker="$2"
  local attempts="${3:-12}"
  for ((attempt = 1; attempt <= attempts; attempt += 1)); do
    if has_marker "$udid" "$marker"; then return 0; fi
    sleep 1
  done
  echo 'Required accessible UI marker was not reached.' >&2
  return 1
}

center_for() {
  local udid="$1"
  local marker="$2"
  tree_for "$udid"
  python3 - "$PRIVATE_UI_DIR/$udid.json" "$marker" <<'PY'
import json
import sys

path, marker = sys.argv[1:]
marker = marker.casefold()
with open(path, encoding='utf-8') as handle:
    payload = json.load(handle)
stack = list(payload if isinstance(payload, list) else [payload])
matches = []
while stack:
    item = stack.pop(0)
    if not isinstance(item, dict):
        continue
    for value in item.values():
        if isinstance(value, dict):
            stack.append(value)
        elif isinstance(value, list):
            stack.extend(value)
    haystack = ' '.join(str(item.get(key) or '') for key in (
        'AXLabel', 'AXValue', 'title', 'placeholder', 'help', 'value', 'label',
    )).casefold()
    frame = item.get('frame')
    if marker in haystack and isinstance(frame, dict):
        width = float(frame.get('width', 0))
        height = float(frame.get('height', 0))
        if width > 0 and height > 0:
            matches.append((
                float(frame.get('x', 0)) + width / 2,
                float(frame.get('y', 0)) + height / 2,
                width * height,
            ))
if not matches:
    raise SystemExit('accessible_marker_missing')
x, y, _ = min(matches, key=lambda match: match[2])
print(round(x), round(y))
PY
}

nearest_for() {
  local udid="$1"
  local anchor="$2"
  local action="$3"
  tree_for "$udid"
  python3 - "$PRIVATE_UI_DIR/$udid.json" "$anchor" "$action" <<'PY'
import json
import math
import sys

path, anchor, action = sys.argv[1:]
anchor = anchor.casefold()
action = action.casefold()
with open(path, encoding='utf-8') as handle:
    payload = json.load(handle)
stack = list(payload if isinstance(payload, list) else [payload])
anchors = []
actions = []
while stack:
    item = stack.pop(0)
    if not isinstance(item, dict):
        continue
    for value in item.values():
        if isinstance(value, dict):
            stack.append(value)
        elif isinstance(value, list):
            stack.extend(value)
    text = ' '.join(str(item.get(key) or '') for key in (
        'AXLabel', 'AXValue', 'title', 'placeholder', 'help', 'value', 'label',
    )).casefold()
    frame = item.get('frame')
    if not isinstance(frame, dict):
        continue
    width = float(frame.get('width', 0))
    height = float(frame.get('height', 0))
    if width <= 0 or height <= 0:
        continue
    point = (
        float(frame.get('x', 0)) + width / 2,
        float(frame.get('y', 0)) + height / 2,
        width * height,
        text,
    )
    if anchor in text:
        anchors.append(point)
    if action in text:
        actions.append(point)
if not anchors or not actions:
    raise SystemExit('accessible_near_marker_missing')
anchor_point = min(anchors, key=lambda point: point[2])
filtered = [
    candidate for candidate in actions
    if anchor not in candidate[3] or candidate[2] < 50000
]
if not filtered:
    filtered = actions
candidate = min(
    filtered,
    key=lambda point: (
        math.hypot(point[0] - anchor_point[0], point[1] - anchor_point[1]),
        point[2],
    ),
)
print(round(candidate[0]), round(candidate[1]))
PY
}

tap_marker() {
  local point
  point="$(center_for "$1" "$2")"
  read -r x y <<< "$point"
  idb ui tap --udid "$1" "$x" "$y"
}

tap_near_marker() {
  local point
  point="$(nearest_for "$1" "$2" "$3")"
  read -r x y <<< "$point"
  idb ui tap --udid "$1" "$x" "$y"
}

scroll_until_marker() {
  local udid="$1"
  local marker="$2"
  local attempts="${3:-24}"
  for ((attempt = 1; attempt <= attempts; attempt += 1)); do
    if has_marker "$udid" "$marker"; then return 0; fi
    idb ui swipe --udid "$udid" --duration 0.45 200 720 200 260
    sleep 0.7
  done
  echo 'Required accessible UI marker was not reachable by scrolling.' >&2
  return 1
}

dismiss_open_prompt() {
  local udid="$1"
  if has_marker "$udid" 'Open'; then
    tap_marker "$udid" 'Open'
    sleep 3
  fi
}

open_link() {
  xcrun simctl openurl "$1" "$2"
  sleep 4
  dismiss_open_prompt "$1"
}

login() {
  local udid="$1"
  local email="$2"
  local password="$3"
  open_link "$udid" 'bil://login'
  tap_marker "$udid" 'Store reviewer access'
  sleep 2
  tap_marker "$udid" 'Email address'
  idb ui text --udid "$udid" "$email"
  tap_marker "$udid" 'Password'
  idb ui text --udid "$udid" "$password"
  tap_marker "$udid" 'Sign in'
  sleep 14
  if has_marker "$udid" 'Authentication failed'; then
    echo 'A private QA account failed to authenticate.' >&2
    return 1
  fi
  has_marker "$udid" 'Today' || has_marker "$udid" 'Dashboard' || {
    echo 'Authenticated startup did not reach the dashboard contract.' >&2
    return 1
  }
}
