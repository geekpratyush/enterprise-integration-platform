#!/usr/bin/env python3
"""
Injects custom kamlets from the local kamlets directory into the Kaoto
extension's bundled kamelets aggregate catalog so they appear in the
Kaoto visual designer palette.

Re-run this script after updating the Kaoto VS Code extension.
"""

import json
import yaml
import glob
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Kaoto Extension path configuration
KAOTO_EXT_BASE = os.path.expanduser(
    "~/.vscode/extensions/redhat.vscode-kaoto-2.10.2"
    "/dist/webview/editors/kaoto/camel-catalog/camel-main/4.18.0"
)

# Discover the kamelets aggregate file (name contains a hash)
aggregate_files = glob.glob(os.path.join(KAOTO_EXT_BASE, "kamelets-aggregate-*.json"))
if not aggregate_files:
    print(f"ERROR: No kamelets aggregate file found under {KAOTO_EXT_BASE}")
    sys.exit(1)

AGGREGATE_FILE = aggregate_files[0]
print(f"Target catalog: {AGGREGATE_FILE}")

# Load existing catalog
with open(AGGREGATE_FILE, "r", encoding="utf-8") as f:
    catalog = json.load(f)

# Load and inject each local kamlet
# Recursive search for all *.kamelet.yaml files under the platform directory
root_dir = os.path.dirname(SCRIPT_DIR)
kamlet_files = glob.glob(os.path.join(root_dir, "platform/**/*.kamelet.yaml"), recursive=True)

if not kamlet_files:
    print(f"ERROR: No *.kamelet.yaml files found under {os.path.join(root_dir, 'platform')}")
    sys.exit(1)

injected = []
for kamlet_path in sorted(kamlet_files):
    with open(kamlet_path, "r", encoding="utf-8") as f:
        kamlet = yaml.safe_load(f)

    name = kamlet.get("metadata", {}).get("name")
    if not name:
        continue

    catalog[name] = kamlet
    injected.append(name)
    print(f"  + injected: {name}")

# Write back
with open(AGGREGATE_FILE, "w", encoding="utf-8") as f:
    json.dump(catalog, f, indent="\t", ensure_ascii=False)

print(f"\nDone. Injected {len(injected)} kamlet(s): {injected}")
print("Reopen any Kaoto editor tabs to pick up the changes.")
