"""Pick (or create) the simulator a CI job runs on, from `xcrun simctl list --json` output."""
import argparse
import json
import re
import subprocess
import sys

FAMILIES = {
    # Preferred device names first; any available device of the family is the fallback.
    "iphone": (["iPhone 17 Pro", "iPhone 18 Pro"], lambda name: name.startswith("iPhone") and "Duo" not in name),
    "ipad": (["iPad Pro 13-inch (M5)", "iPad Pro 11-inch (M5)"], lambda name: name.startswith("iPad Pro")),
    "duo": ([], lambda name: "iPhone Duo" in name),
}


def runtime_version(identifier):
    match = re.search(r"iOS-(\d+)-(\d+)(?:-(\d+))?$", identifier)
    return tuple(int(part or 0) for part in match.groups()) if match else None


def choose(devices, family, minimum):
    """Returns the UDID of the best available device on the newest iOS runtime at or above `minimum`."""
    preferred, matches = FAMILIES[family]
    runtimes = sorted(
        ((version, identifier) for identifier in devices
         if (version := runtime_version(identifier)) and version >= minimum),
        reverse=True,
    )
    for _, identifier in runtimes:
        available = [d for d in devices[identifier] if d.get("isAvailable") and matches(d["name"])]
        for name in preferred:
            for device in available:
                if device["name"] == name:
                    return device["udid"]
        if available:
            return available[0]["udid"]
    return None


def creatable(devicetypes, runtimes, family, minimum):
    """Returns (device type, runtime) identifiers to create a missing device, or None."""
    preferred, matches = FAMILIES[family]
    kinds = sorted((t for t in devicetypes if matches(t["name"])),
                   key=lambda t: preferred.index(t["name"]) if t["name"] in preferred else len(preferred))
    ios = sorted(
        ((version, r["identifier"]) for r in runtimes
         if r.get("isAvailable") and (version := runtime_version(r["identifier"])) and version >= minimum),
        reverse=True,
    )
    if not kinds or not ios:
        return None
    return kinds[0]["identifier"], ios[0][1]


def simctl(*arguments):
    return json.loads(subprocess.run(["xcrun", "simctl", "list", "--json", *arguments],
                                     check=True, capture_output=True, text=True).stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("family", choices=sorted(FAMILIES))
    parser.add_argument("--minimum", default="27.1", help="lowest iOS runtime, for example 27.1")
    args = parser.parse_args()
    minimum = tuple(int(part) for part in args.minimum.split("."))
    minimum += (0,) * (3 - len(minimum))
    udid = choose(simctl("devices", "available")["devices"], args.family, minimum)
    if udid is None:
        listing = simctl()
        pair = creatable(listing["devicetypes"], listing["runtimes"], args.family, minimum)
        if pair is None:
            sys.exit(f"No {args.family} simulator or device type with iOS {args.minimum} or later is installed.")
        udid = subprocess.run(["xcrun", "simctl", "create", f"Acute CI {args.family}", *pair],
                              check=True, capture_output=True, text=True).stdout.strip()
    print(udid)


if __name__ == "__main__":
    main()
