## Commands

- run: `flutter run`
- test: `flutter test --reporter=compact`
- test-changed: `scripts/test_changed.sh`
- lint: `flutter analyze`
- coverage: `flutter test --reporter=compact --coverage`
- coverage-gaps: `coverage-gaps coverage/lcov.info`
- deploy: `scripts/deploy.sh` (release build of this checkout + phone_deploy to the Pixel; never uninstall, never pm clear; exit 0 only when the new versionCode is installed and running)
