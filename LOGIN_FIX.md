# Mobile login troubleshooting

Open `/health` on your deployed domain from the phone first. Then rebuild the native client with `flutter run --dart-define=API_BASE=https://YOUR-PROJECT.vercel.app`, substituting your actual domain. Web uses its own origin. A physical phone cannot reach your computer via `localhost`; for local Android emulator development use `http://10.0.2.2:8000`.

Use a confirmed Supabase account on Vercel, not the local demo passwords. For recovery, check the exact callback URLs and email settings in [DEPLOYMENT.md](DEPLOYMENT.md).
