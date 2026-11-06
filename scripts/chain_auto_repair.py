#!/usr/bin/python3
"""Renew the local development build after a reboot or before profiles expire."""

import argparse
from datetime import datetime, timedelta
import fcntl
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import time


APP = Path("/Applications/Chain.app")
STATE_DIR = Path.home() / "Library/Application Support/ChainAutoRepair"


def run(command, **kwargs):
    return subprocess.run(command, check=True, **kwargs)


def team_id(value):
    if not re.fullmatch(r"[A-Z0-9]{10}", value):
        raise argparse.ArgumentTypeError("Team ID must contain 10 uppercase letters or digits")
    return value


def build_command(repo, state_dir, team=None):
    command = ["/usr/bin/xcodebuild", "-project", str(repo / "Chain.xcodeproj"),
               "-scheme", "Chain", "-configuration", "Debug",
               "-allowProvisioningUpdates", "-derivedDataPath",
               str(state_dir / "DerivedData")]
    if team:
        command.append("DEVELOPMENT_TEAM=" + team_id(team))
    command.append("build")
    return command


def boot_id():
    output = run(["/usr/sbin/sysctl", "-n", "kern.boottime"],
                 capture_output=True, text=True).stdout
    match = re.search(r"sec\s*=\s*(\d+)", output)
    if not match:
        raise RuntimeError("Cannot determine the current boot time")
    return match.group(1)


def profile_expiration(bundle):
    data = run(["/usr/bin/security", "cms", "-D", "-i",
                str(bundle / "Contents/embedded.provisionprofile")],
               capture_output=True).stdout
    expires = plistlib.loads(data).get("ExpirationDate")
    if not isinstance(expires, datetime):
        raise RuntimeError("Missing provisioning profile expiration")
    return expires


def repair_reason(current_boot, previous_boot, expirations, now, force=False,
                  last_repair=None):
    if force:
        return "manual rebuild"
    if current_boot != previous_boot:
        return "first successful repair of this boot"
    if not expirations or min(expirations) <= now:
        return "provisioning profile missing or expired"
    if min(expirations) <= now + timedelta(days=2):
        # Xcode may reuse a still-valid profile. Avoid rebuilding every check.
        if last_repair and now - last_repair < timedelta(hours=6):
            return None
        return "provisioning profile missing or expires within two days"
    return None


def installed_expirations():
    try:
        return [profile_expiration(APP), profile_expiration(
            APP / "Contents/PlugIns/ChainExtension.appex")]
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError):
        return []


def verify(bundle):
    run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(bundle)])
    expirations = [profile_expiration(bundle), profile_expiration(
        bundle / "Contents/PlugIns/ChainExtension.appex")]
    if min(expirations) <= datetime.utcnow() + timedelta(minutes=5):
        raise RuntimeError("Xcode did not supply valid provisioning profiles")


def extension_identifier(bundle):
    info = bundle / "Contents/PlugIns/ChainExtension.appex/Contents/Info.plist"
    identifier = plistlib.loads(info.read_bytes()).get("CFBundleIdentifier")
    if not isinstance(identifier, str) or not identifier:
        raise RuntimeError("Missing Finder extension bundle identifier")
    return identifier


def repair(repo, state_dir, team=None):
    products = state_dir / "DerivedData/Build/Products/Debug/Chain.app"
    log_path = state_dir / "build.log"
    print("Building Chain; log:", log_path, flush=True)
    with log_path.open("w") as log:
        run(build_command(repo, state_dir, team), cwd=repo,
            stdout=log, stderr=subprocess.STDOUT, timeout=1200)
    verify(products)

    # Prepare the entire replacement before removing the installed app.
    staging = state_dir / "staging/Chain.app"
    backup = state_dir / "previous/Chain.app"
    for path in (staging, backup):
        if path.exists():
            shutil.rmtree(path)
        path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(products, staging)
    verify(staging)
    if APP.is_symlink():
        raise RuntimeError("Refusing to replace a symlink at /Applications/Chain.app")
    had_app = APP.exists()
    if had_app:
        shutil.copytree(APP, backup)
    for process in ("Chain", "ChainExtension"):
        subprocess.run(["/usr/bin/pkill", "-x", process], check=False)
    try:
        if APP.exists():
            shutil.rmtree(APP)
        shutil.copytree(staging, APP)
        verify(APP)
        run(["/usr/bin/open", str(APP)])
        time.sleep(2)
        run(["/usr/bin/pluginkit", "-a",
             str(APP / "Contents/PlugIns/ChainExtension.appex")])
        run(["/usr/bin/pluginkit", "-e", "use", "-i", extension_identifier(APP)])
        run(["/usr/bin/killall", "Finder"])
        time.sleep(3)
        run(["/usr/bin/pgrep", "-x", "Chain"], stdout=subprocess.DEVNULL)
    except Exception:
        if APP.exists():
            shutil.rmtree(APP)
        if had_app:
            shutil.copytree(backup, APP)
            subprocess.run(["/usr/bin/open", str(APP)], check=False)
        raise
    shutil.rmtree(staging)
    if backup.exists():
        shutil.rmtree(backup)
    print("Installed and started /Applications/Chain.app", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--state-dir", type=Path, default=STATE_DIR)
    parser.add_argument("--team", type=team_id, help="Use and remember this Apple development team")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--check", action="store_true", help="Print status without changes")
    args = parser.parse_args()
    config_file = args.state_dir / "config.json"
    config = json.loads(config_file.read_text()) if config_file.exists() else {}
    team = args.team or config.get("development_team")
    if team:
        team_id(team)
    current_boot = boot_id()
    state_file = args.state_dir / "state.json"
    if args.check:
        state = json.loads(state_file.read_text()) if state_file.exists() else {}
        expirations = installed_expirations()
        last_repair = datetime.fromisoformat(state["last_repair_utc"]) if state.get(
            "last_repair_utc") else None
        reason = repair_reason(current_boot, state.get("boot_id"), expirations,
                               datetime.utcnow(), args.force or bool(args.team), last_repair)
        print(json.dumps({"repair_needed": bool(reason), "reason": reason,
                          "development_team": team or "Xcode project default",
                          "profile_expirations_utc": [d.isoformat() for d in expirations]},
                         indent=2))
        return
    args.state_dir.mkdir(parents=True, exist_ok=True)
    with (args.state_dir / "repair.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print("Another repair is already running", flush=True)
            return
        state = json.loads(state_file.read_text()) if state_file.exists() else {}
        last_repair = datetime.fromisoformat(state["last_repair_utc"]) if state.get(
            "last_repair_utc") else None
        reason = repair_reason(current_boot, state.get("boot_id"), installed_expirations(),
                               datetime.utcnow(), args.force or bool(args.team), last_repair)
        if reason:
            print(datetime.now().isoformat(), reason, flush=True)
            repair(args.repo, args.state_dir, team)
            if args.team:
                temporary_config = config_file.with_suffix(".tmp")
                temporary_config.write_text(json.dumps({"development_team": args.team}))
                temporary_config.replace(config_file)
            temporary = state_file.with_suffix(".tmp")
            temporary.write_text(json.dumps({"boot_id": current_boot,
                                            "last_repair_utc": datetime.utcnow().isoformat()}))
            temporary.replace(state_file)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("Chain auto repair failed:", error, file=sys.stderr, flush=True)
        sys.exit(1)
