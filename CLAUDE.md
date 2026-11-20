## Commands

- run: `flutter run`
- test: `flutter test --reporter=compact`
- test-changed: `scripts/test_changed.sh`
- lint: `flutter analyze`
- coverage: `flutter test --reporter=compact --coverage`
- coverage-gaps: `coverage-gaps coverage/lcov.info`
- deploy: `git -C ~/src/umbrella pull --ff-only && ~/src/umbrella/scripts/deploy.sh` (builds from the main checkout: phone_deploy refuses a production install from a worktree, exit 49; release build + phone_deploy to the Pixel; never uninstall, never pm clear; exit 0 only when the new versionCode is installed and running)
