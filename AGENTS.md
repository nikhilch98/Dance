# Repository Guidelines

## Project Structure & Modules
- `app/`: FastAPI backend. Entrypoint `app/main.py`; routers in `app/api`; config in `app/config`; services in `app/services`.
- `nachna/`: Flutter iOS app. App code under `nachna/lib`; iOS project in `nachna/ios`.
- Tests: Python scripts at repo root (`test_*.py`) and `nachna/test` for Dart tests.

## Build, Test, and Development
- Backend setup: `python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt`.
- Start MongoDB (local): `docker-compose up -d mongodb` (binds `27017`).
- Run backend (dev): `uvicorn app.main:app --reload --host 127.0.0.1 --port 8002`.
- Flutter iOS: `cd nachna && flutter pub get && flutter analyze`. Run: `flutter run -d ios`. Build: `flutter build ios --release` (open `ios/Runner.xcworkspace` for signing).
- Scripted API tests: `python test_auth_flow.py` (update base URL inside file when testing locally).

## Coding Style & Naming
- Python: 4-space indent, type hints where practical, snake_case for functions/vars, PascalCase for classes. Format with Black: `black app/ utils/`.
- FastAPI: group endpoints by domain in `app/api` (e.g., `auth.py`, `workshops.py`, `rewards.py`). Use clear prefixes: `/api/auth`, `/api/rewards`.
- Dart/Flutter: follow Effective Dart; run `flutter format .` and `flutter analyze` before committing.

## Testing Guidelines
- Backend: use existing HTTP scripts (e.g., `test_auth_flow.py`). Add one negative case per new endpoint. Prefer idempotent tests and a dedicated test user.
- Flutter: place tests in `nachna/test`; run with `flutter test`. Keep network calls mocked for unit tests.

## Breaking Changes & Test User
- Backward compatibility: do not change existing routes, request/response formats, or auth flows; add new functionality additively.
- Test user (for dev): mobile `9999999999`, password `test123`; default API base `https://nachna.com`.

## Commit & Pull Requests
- Commits: imperative, scoped messages, e.g., `api: fix password update`, `ios: update push entitlements`.
- PRs: include summary, linked issue, how-to-test (sample curl/Flutter steps), and screenshots for UI changes.

## Security & Configuration
- Backend env: `.env` read by `app/config/settings.py` (Twilio/Razorpay/APNs). Do not commit real secrets.
- iOS push: configure APNs keys and entitlements per `nachna/IOS_PUSH_NOTIFICATION_SETUP.md`. For local dev, point Flutter services to your dev backend (e.g., update `baseUrl` fields in `nachna/lib/services/*_service.dart`).
 - UI/UX: follow `.cursorrules` for design language, overflow handling, and accessibility.
