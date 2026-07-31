# API Cutover

## Development On The New API

Use the emulator manifest:

```bash
flutter run --dart-define-from-file=env/new-api-emulator.json
```

For a physical device, supply your LAN host explicitly:

```bash
flutter run \
  --dart-define=FURTAIL_API_BASE_URL=http://<your-lan-ip>:7300/api/v1 \
  --dart-define=FURTAIL_SOCKET_URL=http://<your-lan-ip>:7300 \
  --dart-define=FURTAIL_MEDIA_BASE_URL=http://<your-lan-ip>:9000
```

## Rollback To 7200

Use the rollback emulator manifest:

```bash
flutter run --dart-define-from-file=env/rollback-7200.json
```

For a physical device, point the same variables back at port `7200`:

```bash
flutter run \
  --dart-define=FURTAIL_API_BASE_URL=http://<your-lan-ip>:7200/api/v1 \
  --dart-define=FURTAIL_SOCKET_URL=http://<your-lan-ip>:7200 \
  --dart-define=FURTAIL_MEDIA_BASE_URL=http://<your-lan-ip>:9000
```

## Notes

- `FURTAIL_API_BASE_URL` is preferred.
- `FURTAIL_SOCKET_URL` is only needed if the app uses a live socket endpoint.
- Legacy `API_BASE_URL`, `API_HOST`, `SOCKET_URL`, and `MEDIA_BASE_URL` are
  still accepted for rollback-safe compatibility.

