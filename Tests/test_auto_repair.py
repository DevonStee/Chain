from datetime import datetime, timedelta
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from scripts import chain_auto_repair as repair
from scripts import install_auto_repair as installer


class AutoRepairTests(unittest.TestCase):
    def test_team_override_is_passed_to_all_xcode_targets(self):
        command = repair.build_command(Path("/repo with spaces"), Path("/state"), "ABCDE12345")
        self.assertIn("DEVELOPMENT_TEAM=ABCDE12345", command)
        self.assertEqual(command[command.index("-project") + 1],
                         "/repo with spaces/Chain.xcodeproj")

    def test_installer_bootstraps_app_before_building_named_launcher(self):
        events = []

        class CommandCompleted(Exception):
            pass

        def run(command, **kwargs):
            events.append(command)

        def launcher(script):
            self.assertEqual(events[0][0], "/usr/bin/python3")
            self.assertTrue(events[0][1].endswith("chain_auto_repair.py"))
            self.assertEqual(events[0][-2:], ["--team", "ABCDE12345"])
            raise CommandCompleted()

        with patch("sys.argv", ["install_auto_repair.py", "--team", "ABCDE12345"]), \
                patch.object(installer.subprocess, "run", side_effect=run), \
                patch.object(installer, "build_launcher", side_effect=launcher):
            with self.assertRaises(CommandCompleted):
                installer.main()

    def test_boot_and_expiry_decisions(self):
        now = datetime(2026, 10, 7)
        fresh = [now + timedelta(days=7), now + timedelta(days=6)]
        self.assertIsNone(repair.repair_reason("boot", "boot", fresh, now))
        self.assertIsNotNone(repair.repair_reason("new", "old", fresh, now))
        self.assertIsNotNone(repair.repair_reason("boot", "boot", [], now))
        self.assertIsNotNone(repair.repair_reason(
            "boot", "boot", [fresh[0], now + timedelta(days=1)], now))
        self.assertIsNotNone(repair.repair_reason("boot", "boot", fresh, now, True))

    def test_failed_build_keeps_installed_app(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app = root / "Chain.app"
            app.mkdir()
            original = app / "original"
            original.write_text("installed")
            with patch.object(repair, "APP", app), patch.object(
                    repair, "run", side_effect=subprocess.CalledProcessError(1, "xcodebuild")):
                with self.assertRaises(subprocess.CalledProcessError):
                    repair.repair(root, root)
            self.assertEqual(original.read_text(), "installed")

    def test_recent_rebuild_throttles_renewal_but_not_expiration_or_reboot(self):
        now = datetime(2026, 10, 7)
        recent = now - timedelta(hours=1)
        near = [now + timedelta(days=1)]
        self.assertIsNone(repair.repair_reason("boot", "boot", near, now,
                                             last_repair=recent))
        self.assertIsNotNone(repair.repair_reason("new", "boot", near, now,
                                                 last_repair=recent))
        self.assertIsNotNone(repair.repair_reason("boot", "boot", [now], now,
                                                 last_repair=recent))

    def test_failed_install_restores_previous_app(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app = root / "Chain.app"
            app.mkdir()
            (app / "original").write_text("installed")
            products = root / "DerivedData/Build/Products/Debug/Chain.app"
            products.mkdir(parents=True)
            (products / "replacement").write_text("new")
            with patch.object(repair, "APP", app), patch.object(repair, "run"), \
                    patch.object(repair.subprocess, "run"), patch.object(repair, "verify",
                    side_effect=[None, None, RuntimeError("bad installed signature")]):
                with self.assertRaises(RuntimeError):
                    repair.repair(root, root)
            self.assertEqual((app / "original").read_text(), "installed")
            self.assertFalse((app / "replacement").exists())


if __name__ == "__main__":
    unittest.main()
