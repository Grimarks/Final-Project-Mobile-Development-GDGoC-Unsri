# Branding CampusFlow

| File | Isi |
|---|---|
| `logo.svg` | **Sumber utama** ikon app: kartu tugas + centang + sudut kuning AI di atas biru `#4C6FFF`. Full-bleed, tanpa sudut membulat (dipakai iOS apa adanya). |
| `logo-wordmark.svg` / `.png` | Logo + tulisan "CampusFlow" (Space Grotesk Bold, sudah jadi path) |
| `icon-android-foreground.svg` | Layer foreground adaptive icon Android, latar transparan, semua elemen di safe zone (lingkaran radius ±313px dari tengah kanvas 1024) |
| `icon-android-monochrome.svg` | Themed icon Android 13+ (cuma alpha yang dipakai sistem) |
| `export_icons.sh` | Export SVG di atas → PNG di `mobile/assets/icon/` (+ `logo-wordmark.png`) |
| `concepts/`, `preview.html`, `preview.png` | 4 konsep awal + halaman perbandingan (29–1024px, mask iOS/Android, wallpaper terang/gelap) |

## Mengganti ikon

1. Edit `logo.svg` (dan kalau bentuknya berubah, juga `icon-android-foreground.svg`
   & `icon-android-monochrome.svg` — elemen penting tetap di safe zone).
2. Export PNG:
   ```bash
   ./branding/export_icons.sh
   ```
3. Generate ikon iOS & Android:
   ```bash
   cd mobile
   dart run flutter_launcher_icons
   git checkout ios/Runner.xcodeproj/project.pbxproj   # bug v0.14.4, lihat flutter_launcher_icons.yaml
   ```
4. Warna latar adaptive Android ada di `mobile/flutter_launcher_icons.yaml`
   (`adaptive_icon_background`). Logo di dalam app (`AppLogo`, halaman login & layar
   kunci) memakai `mobile/assets/icon/app_icon.png`, jadi ikut berubah di langkah 2.
5. Video booth (`../campusflow-booth-video`) memakai salinan `public/logo.svg` —
   salin ulang lalu `npm run render`.
