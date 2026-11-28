## Commands

- run: `flutter run`
- test: `flutter test --reporter=compact`
- test-changed: `scripts/test_changed.sh`
- lint: n/a: dropped (kuhy, 2026-11-27)
- coverage: n/a: dropped (kuhy, 2026-11-27)
- coverage-gaps: n/a: dropped (kuhy, 2026-11-27)
- deploy: `git -C ~/src/umbrella pull --ff-only && ~/src/umbrella/scripts/deploy.sh` (builds from the main checkout: phone_deploy refuses a production install from a worktree, exit 49; release build + phone_deploy to the Pixel; never uninstall, never pm clear; exit 0 only when the new versionCode is installed and running)
