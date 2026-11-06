#!/usr/bin/python3
"""Install or remove the per-user Chain repair LaunchAgent."""

import argparse
import hashlib
from pathlib import Path
import os
import plistlib
import shutil
import subprocess
import tempfile


LABEL = "com.lursetawet.chain.auto-repair"
HELPER_ID = "com.lursetawet.chain.auto-build"
STATE_DIR = Path.home() / "Library/Application Support/ChainAutoRepair"


def build_launcher(script):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=STATE_DIR) as temporary:
        root = Path(temporary)
        bundle = root / "Chain Auto Build.app"
        executable = bundle / "Contents/MacOS/Chain Auto Build"
        executable.parent.mkdir(parents=True)
        info = {
            "CFBundleIdentifier": HELPER_ID,
            "CFBundleName": "Chain Auto Build",
            "CFBundleDisplayName": "Chain Auto Build",
            "CFBundleExecutable": "Chain Auto Build",
            "CFBundlePackageType": "APPL",
            "CFBundleVersion": "1",
            "CFBundleShortVersionString": "1.0",
            "LSUIElement": True,
            "LSMinimumSystemVersion": "14.0",
        }
        icon = Path("/Applications/Chain.app/Contents/Resources/AppIcon.icns")
        if icon.exists():
            resources = bundle / "Contents/Resources"
            resources.mkdir()
            shutil.copy2(icon, resources / "AppIcon.icns")
            info["CFBundleIconFile"] = "AppIcon.icns"
        (bundle / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
        subprocess.run(["/usr/bin/xcrun", "swiftc", "-O", "-o", str(executable),
                        str(script.with_name("ChainAutoBuild.swift"))], check=True)
        # Reuse the installed app's signing identity for background-item attribution.
        certificate = root / "certificate"
        subprocess.run(["/usr/bin/codesign", "-d", "--extract-certificates=" +
                        str(certificate), "/Applications/Chain.app"], check=True)
        identity = hashlib.sha1(certificate.with_name("certificate0").read_bytes()).hexdigest()
        subprocess.run(["/usr/bin/codesign", "--force", "--sign", identity,
                        "--timestamp=none", str(bundle)], check=True)
        subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict",
                        str(bundle)], check=True)
        destination = STATE_DIR / bundle.name
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(bundle, destination)
    subprocess.run([
        "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
        "-f", str(destination)], check=True)
    return destination / "Contents/MacOS/Chain Auto Build"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--uninstall", action="store_true")
    parser.add_argument("--team", help="Apple development Team ID for this Mac")
    args = parser.parse_args()
    agent = Path.home() / "Library/LaunchAgents" / (LABEL + ".plist")
    domain = "gui/" + str(os.getuid())
    if args.uninstall:
        subprocess.run(["/bin/launchctl", "bootout", domain + "/" + LABEL],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        agent.unlink(missing_ok=True)
        print("Automatic repair disabled; Chain remains installed.")
        return
    script = Path(__file__).resolve().with_name("chain_auto_repair.py")
    # Bootstrap a fresh clone before extracting a signing identity from Chain.app.
    command = ["/usr/bin/python3", str(script), "--force"]
    if args.team:
        command.extend(["--team", args.team])
    subprocess.run(command, check=True)
    launcher = build_launcher(script)
    logs = Path.home() / "Library/Logs/ChainAutoRepair"
    logs.mkdir(parents=True, exist_ok=True)
    agent.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "Label": LABEL,
        "ProgramArguments": [str(launcher), str(script)],
        "AssociatedBundleIdentifiers": [HELPER_ID],
        "RunAtLoad": True,
        "StartInterval": 1800,
        "ProcessType": "Background",
        "StandardOutPath": str(logs / "repair.log"),
        "StandardErrorPath": str(logs / "error.log"),
        "EnvironmentVariables": {"PATH": "/usr/bin:/bin:/usr/sbin:/sbin"},
    }
    subprocess.run(["/bin/launchctl", "bootout", domain + "/" + LABEL],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    agent.write_bytes(plistlib.dumps(payload))
    subprocess.run(["/usr/bin/plutil", "-lint", str(agent)], check=True)
    subprocess.run(["/bin/launchctl", "bootstrap", domain, str(agent)], check=True)
    print("Enabled automatic repair at login and expiry checks every 30 minutes.")
    print("Logs:", logs)


if __name__ == "__main__":
    main()
