# Materi booth

| File | Isi |
|---|---|
| `qr-download-android.png` / `.svg` | QR code unduh APK Android. SVG untuk dicetak besar (tidak pecah) |

QR mengarah ke link tetap:

```
https://github.com/Grimarks/Final-Project-Mobile-Development-GDGoC-Unsri/releases/latest/download/campusflow.apk
```

Link ini selalu menunjuk ke file `campusflow.apk` di **release terbaru**, jadi QR yang
sudah dicetak tidak perlu diganti walau APK-nya di-update.

## Menerbitkan / memperbarui APK

1. Build APK yang mengarah ke server online:

   ```bash
   cd mobile
   flutter build apk --release --dart-define=API_BASE_URL=https://campusflow-api-wbu7.onrender.com
   cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/campusflow.apk
   ```

2. Di GitHub repo: **Releases → Draft a new release** → buat tag baru (mis. `v1.0.0`) →
   lampirkan `campusflow.apk` (nama file harus persis ini) → **Publish release**
   (jangan dicentang *pre-release*, karena link `latest` melewati pre-release).
3. Scan QR untuk memastikan unduhan langsung jalan.

## Akun demo

Isi/reset data contoh sebelum acara (lihat README utama, bagian deploy):

```bash
cd backend
python scripts/seed_demo.py --base-url https://campusflow-api-wbu7.onrender.com \
    --email demo@campusflow.app --password '<password-demo>'
```
