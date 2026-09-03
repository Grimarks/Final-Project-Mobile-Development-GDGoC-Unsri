# CampusFlow

**AI academic life manager** untuk mahasiswa — mengubah mata kuliah, tugas, dan deadline
menjadi jadwal belajar terprioritas, dengan identitas visual neo-brutalism.

Dibangun sebagai final project mata kuliah Mobile Development.

---

## 1. Ringkasan

| | |
|---|---|
| **Mobile** | Flutter 3.x + Riverpod + GoRouter + dio + Hive |
| **Backend** | FastAPI (Python 3.11+) + SQLAlchemy 2.0 async + Alembic |
| **Database** | PostgreSQL 15+ (SQLite untuk development) |
| **Auth** | JWT access + refresh token, password di-hash bcrypt |
| **Fitur AI** | Groq API (Llama 3.3 70B) — penyusun jadwal, ringkasan & kuis materi |
| **Testing** | pytest (backend, 73 test), flutter_test unit+widget (mobile, 73 test), plus 1 integration test end-to-end — semuanya hijau |

### Fitur

**Auth & profil:**
- Register (password wajib kuat: huruf besar+kecil, angka, simbol) / login / refresh token
- Login pakai Face ID di iPhone, sekali diaktifkan lewat tab Profile
- Edit nama, email, dan password dari Profile

**Akademik:**
- CRUD mata kuliah dan tugas, dikelompokkan per mata kuliah
- Upload PDF materi kuliah → ekstraksi teks → ringkasan AI + generator kuis (dengan skor)

**AI Planner — 3 cara pakai:**
- **Generate acak** — sebut jam luang, AI susun jadwal blok waktu dari tugas terbuka
- **Adjust plan aktif** — kasih instruksi bebas ("pindahkan sesi pertama ke sore"), AI sesuaikan jadwal yang sedang berjalan
- **Chat bebas** — ngobrol dulu soal beban tugas/mood, lalu "Generate plan from this chat"; AI juga bisa nangkep task baru dari obrolan buat direview & disimpan sebelum jadwal dibuat

**Fokus & progres:**
- Timer Pomodoro (dengan tombol fast-forward buat demo) + feedback pasca-sesi (easy / normal / hard)
- Reminder lokal buat deadline tugas & sesi fokus yang selesai
- Dashboard "Today's Focus" dengan statistik, study streak, dan banner AI
- Haptic feedback di tombol-tombol utama

---

## 2. Menjalankan aplikasi

### 2.1 Backend

```bash
cd backend

# 1. Virtual environment
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate

# 2. Dependensi
pip install -r requirements.txt

# 3. Konfigurasi
cp .env.example .env
```

Buka `.env`. Untuk jalan cepat, biarkan `DATABASE_URL` memakai SQLite —
tabel dibuat otomatis saat server start, tidak perlu install PostgreSQL. Isi
`JWT_SECRET` dengan string acak, dan `GROQ_API_KEY` opsional — lihat catatan di bawah.

```bash
# 4. Jalankan
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Cek `http://127.0.0.1:8000/health` → `{"status":"ok", ...}`
Dokumentasi interaktif Swagger: `http://127.0.0.1:8000/docs`

**Kalau memakai PostgreSQL:**

```bash
createdb campusflow
# ganti DATABASE_URL di .env ke postgresql+asyncpg://user:pass@localhost:5432/campusflow
alembic upgrade head
```

**Catatan soal `GROQ_API_KEY`:** kalau dikosongkan, backend otomatis memakai
penjadwal heuristik lokal dan aplikasi tetap berfungsi penuh (berguna saat demo
tanpa internet). Response field `generated_by` akan bernilai `"heuristic"`
alih-alih `"groq"`, dan aplikasi menampilkannya apa adanya ke user. API key
gratis bisa diambil di console.groq.com.

### 2.2 Mobile

```bash
cd mobile
flutter pub get
```

Backend harus sudah jalan lebih dulu. Alamatnya berbeda tergantung target:

| Target | Perintah |
|---|---|
| Simulator iOS | `flutter run` |
| Emulator Android | `flutter run` (otomatis pakai `10.0.2.2`) |
| **iPhone fisik** | `flutter run --dart-define=API_BASE_URL=http://<IP-LAN-Mac>:8000` |

Untuk iPhone fisik, cari IP Mac dengan `ipconfig getifaddr en0`, dan pastikan
backend dijalankan dengan `--host 0.0.0.0` supaya bisa diakses dari perangkat lain
di jaringan yang sama.

Alur mencoba: **Register** (log in lagi setelah sukses, tidak auto-login) → tab
**Profile** → *+ Add course* → tab **Tasks** → tombol **+** untuk menambah tugas →
tab **AI** → pilih salah satu dari 3 kartu (Generate random / Adjust plan / Talk to
me) → **Accept plan** kembali ke **Home** → tap kartu task di "Today's Focus" untuk
mulai sesi fokus di tab **Study**.

---

## 3. Versi dan dependensi

### Backend (`backend/requirements.txt`)

| Paket | Versi |
|---|---|
| fastapi | 0.115.6 |
| uvicorn[standard] | 0.34.0 |
| sqlalchemy | 2.0.36 |
| alembic | 1.14.0 |
| asyncpg / aiosqlite | 0.30.0 / 0.20.0 |
| pydantic / pydantic-settings | 2.10.4 / 2.7.0 |
| python-jose[cryptography] | 3.3.0 |
| bcrypt | 4.2.1 |
| httpx | 0.28.1 |
| pypdf | 5.1.0 |
| pytest / pytest-asyncio | 8.3.4 / 0.25.0 |

### Mobile (`mobile/pubspec.yaml`)

| Paket | Versi |
|---|---|
| flutter_riverpod | ^2.5.1 |
| go_router | ^14.6.2 |
| dio | ^5.7.0 |
| shared_preferences | ^2.3.3 |
| hive / hive_flutter | ^2.2.3 / ^1.1.0 |
| google_fonts | ^6.2.1 |
| intl | ^0.19.0 |
| local_auth | ^2.3.0 — Face ID/Touch ID login |
| file_picker | ^8.1.2 — pilih PDF materi buat di-upload |
| flutter_local_notifications | ^18.0.1 — reminder deadline & sesi fokus |
| timezone | ^0.9.4 — dipakai flutter_local_notifications buat jadwal absolut |

Font Space Grotesk dan Inter diambil lewat `google_fonts`, artinya butuh koneksi
internet saat pertama kali dijalankan (setelah itu di-cache). Untuk demo offline
penuh, unduh TTF-nya dari Google Fonts, taruh di `mobile/assets/fonts/`, daftarkan
di `pubspec.yaml`, lalu ganti `GoogleFonts.spaceGrotesk(...)` di
`lib/core/theme/text_styles.dart` menjadi `TextStyle(fontFamily: 'SpaceGrotesk', ...)`.

---

## 4. Dokumentasi API

Base URL: `http://<host>:8000`. Semua endpoint selain `/auth/*` dan `/health`
memerlukan header `Authorization: Bearer <access_token>`.

### Auth

| Method | Endpoint | Body | Response |
|---|---|---|---|
| POST | `/auth/register` | `{name, email, password}` | `201` `{user, tokens}` — password wajib huruf besar+kecil, angka, simbol |
| POST | `/auth/login` | `{email, password}` | `200` `{user, tokens}` |
| POST | `/auth/refresh` | `{refresh_token}` | `200` `{access_token, refresh_token}` |
| GET | `/auth/me` | — | `200` profil user saat ini (dipakai Face ID gate buat restore session) |
| PUT | `/auth/me` | `{name?, email?}` | `200` update profil, `409` kalau email sudah dipakai |
| POST | `/auth/change-password` | `{current_password, new_password}` | `204` ganti password |

### Courses

| Method | Endpoint | Body |
|---|---|---|
| GET | `/courses` | — |
| POST | `/courses` | `{name, color}` — color hex 6 digit, mis. `#4C6FFF` |
| PUT | `/courses/{id}` | `{name, color}` |
| DELETE | `/courses/{id}` | — |

### Tasks

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/tasks?status=` | filter opsional: `not_started` / `in_progress` / `done` |
| GET | `/tasks/today` | tugas belum selesai yang jatuh tempo hari ini atau lewat |
| POST | `/tasks` | `{title, course_id?, type, due_date?, difficulty}` |
| PUT | `/tasks/{id}` | partial update |
| DELETE | `/tasks/{id}` | — |

`type` ∈ `assignment | exam | quiz`, `difficulty` ∈ `easy | medium | hard`.
Setiap response task berisi field `priority` (`low`/`medium`/`high`) yang dihitung
server — client tidak menghitung ulang.

### Study Sessions

| Method | Endpoint | Body |
|---|---|---|
| GET | `/study-sessions` | — |
| POST | `/study-sessions` | `{task_id?, planned_start?, planned_end?}` |
| PATCH | `/study-sessions/{id}/complete` | `{feedback, actual_duration?}` — feedback ∈ `easy\|normal\|hard` |

### AI

| Method | Endpoint | Body | Response |
|---|---|---|---|
| POST | `/ai/plan` | `{available_hours, start_hour, preference?}` | `{generated_by, available_hours, open_task_count, blocks[]}` — opsi 1: generate random |
| POST | `/ai/plan/adjust` | `{instruction}` | `{...plan, adjusted, error?}` — opsi 2: sesuaikan plan aktif (ambil row `ai_generated` terakhir), `404` kalau belum pernah generate |
| POST | `/ai/plan/from-chat` | — | `PlanResponse` — opsi 3: generate dari histori chat |
| POST | `/ai/chat/message` | `{message}` | `{reply, generated_by}` — kirim 1 pesan, dapat balasan AI |
| GET | `/ai/chat/history` | — | daftar pesan chat user saat ini |
| DELETE | `/ai/chat/history` | — | `204` hapus histori (tombol "Start over") |
| POST | `/ai/chat/extract-tasks` | — | `{tasks[]}` — AI usulkan course/task baru dari histori chat, belum disimpan |
| POST | `/ai/chat/confirm-tasks` | `{tasks[]}` | daftar `Task` — simpan task yang sudah direview user |
| POST | `/ai/materials/{id}/summarize` | — | `{generated_by, summary, key_points[]}` |
| POST | `/ai/materials/{id}/quiz` | — | `{generated_by, questions[]}` |

### Materials

| Method | Endpoint | Keterangan |
|---|---|---|
| POST | `/materials/upload` | multipart: `file` (PDF, maks 10 MB), `course_id` opsional |
| GET | `/materials` | daftar materi |
| GET | `/materials/{id}` | detail satu materi |

### Contoh alur lengkap

```bash
# Register
curl -X POST localhost:8000/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"name":"Darrell","email":"rel@student.unsri.ac.id","password":"Password123!"}'

TOKEN=<access_token dari response>

# Tambah mata kuliah
curl -X POST localhost:8000/courses \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"name":"CS 301 — Algorithms","color":"#4C6FFF"}'

# Tambah tugas
curl -X POST localhost:8000/tasks \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"title":"Problem Set 4","course_id":1,"difficulty":"hard","due_date":"2026-08-25T18:00:00Z"}'

# Minta AI menyusun jadwal
curl -X POST localhost:8000/ai/plan \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"available_hours":3.5,"start_hour":9}'
```

---

## 5. Bagaimana fitur AI bekerja

Bagian ini penting karena membedakan CampusFlow dari sekadar "kirim prompt ke LLM".

**Skor prioritas dihitung deterministik di server, bukan oleh LLM**
(`backend/app/services/planning_service.py`):

```
urgency  = 1 / (1 + hari_menuju_deadline / 5)      # lewat deadline -> 1.0
weight   = bobot_kesulitan × bobot_tipe            # hard=2.4, exam=1.8, dst.
score    = urgency × weight × (0.4 + 0.6 × sisa_progres)
```

Hasilnya dinormalisasi ke 0–100 lalu dipetakan ke label `low`/`medium`/`high`.
Alasannya: urgensi adalah aturan bisnis yang harus konsisten dan bisa dites —
kalau diserahkan ke LLM, dua panggilan identik bisa memberi urutan berbeda dan
tidak ada yang bisa menjelaskan kenapa.

**LLM dipakai untuk menyusun jadwalnya**, bukan menghitung urgensi. Daftar tugas
yang sudah diberi skor dikirim ke Groq beserta jam yang tersedia dan preferensi
user, lalu Groq mengembalikan blok waktu.

**Respons LLM tidak pernah dipercaya mentah.** JSON dari Groq diparse, lalu tiap
blok divalidasi ulang dengan Pydantic (`PlanBlock`). Kalau ada field hilang, tipe
salah, atau durasi di luar batas wajar, validasi gagal dan sistem otomatis jatuh
ke penjadwal heuristik. Warna mata kuliah tiap blok juga di-override dari database,
bukan diambil dari output model.

**Fallback penuh.** Kalau `GROQ_API_KEY` kosong, API down, atau timeout (dengan 2x
retry), `build_plan_heuristic()` mengambil alih: tugas terpenting dulu, blok 30–90
menit sesuai kesulitan, jeda 15 menit, berhenti saat jatah waktu habis. Aplikasi
tidak pernah menampilkan layar error karena AI-nya bermasalah.

---

## 6. Testing

### 6.1 Backend

```bash
cd backend
pip install -r requirements-dev.txt
pytest -v
```

**Hasil: 73 passed.** (lihat `screenshots/testing/` untuk screenshot hasil run-nya)

| File | Cakupan |
|---|---|
| `test_auth.py` | register (termasuk validasi password kuat), hash password tidak plaintext, email duplikat ditolak, login gagal, refresh token, access token ditolak sebagai refresh, route terproteksi, ganti email/password |
| `test_tasks.py` | CRUD course, validasi hex color, label prioritas, filter status, auto-100% saat done, isolasi antar-user, course orang lain ditolak |
| `test_ai_plan.py` | unit test skor prioritas & penyusun jadwal + integrasi endpoint `/ai/plan` |
| `test_ai_adjust.py` | adjust plan dari instruksi bebas, `404` kalau belum ada plan aktif, fallback saat LLM gagal |
| `test_ai_chat.py` | kirim/terima pesan chat, riwayat chat, hapus riwayat |
| `test_ai_extract_tasks.py` | AI usulkan task dari chat, konfirmasi task tersimpan ke daftar task asli |
| `test_materials.py` | upload PDF, validasi tipe file & ukuran, ringkasan & kuis AI, isolasi antar-user |
| `test_study_sessions.py` | siklus sesi, feedback tidak valid ditolak, sesi tidak dikenal |

Test memakai SQLite in-memory (fixture `db_session` di `conftest.py`) dan
`httpx.AsyncClient` terhadap ASGI app langsung, jadi tidak butuh server berjalan
maupun database eksternal. `GROQ_API_KEY` sengaja dikosongkan saat test supaya
jalur AI diuji secara deterministik lewat heuristik, tanpa memanggil API berbayar.

Dua test yang layak disorot:
- `test_password_is_not_stored_in_plaintext` — membaca langsung ke DB dan
  memastikan hash diawali `$2` (penanda bcrypt).
- `test_cannot_touch_other_users_task` — user B mendapat `404`, bukan `403`,
  saat menyentuh tugas user A, sehingga keberadaan resource pun tidak bocor.

### 6.2 Mobile

```bash
cd mobile
flutter test
```

**Hasil: 73 passed.** (lihat `screenshots/testing/` untuk screenshot hasil run-nya)

| File | Cakupan |
|---|---|
| `test/unit/task_model_test.dart` | parsing JSON task, task tanpa course/deadline, format `dueLabel` (Today/Tomorrow/Overdue), konversi hex warna |
| `test/unit/plan_model_test.dart` | parsing StudyPlan & PlanBlock, label waktu, plan kosong |
| `test/unit/chat_message_model_test.dart`, `task_candidate_model_test.dart`, `material_model_test.dart` | parsing model chat, kandidat task dari AI, dan materi |
| `test/unit/chat_controller_test.dart` | alur kirim pesan, extract task, review, dan generate plan dari chat |
| `test/unit/biometric_setting_test.dart` | toggle Face ID tersimpan/terbaca lewat `TokenStorage` |
| `test/unit/study_streak_test.dart` | perhitungan streak dari riwayat sesi belajar |
| `test/unit/task_notification_test.dart` | reminder terjadwal/batal saat task dibuat, selesai, atau dihapus |
| `test/widget/brutal_widgets_test.dart` | BrutalCard hard shadow `blurRadius: 0`, leftStripe warna mata kuliah, efek tekan tombol menyusut ke 2px, state loading, pemetaan warna PriorityBlock, chip selected/unselected |
| `test/widget/task_card_test.dart` | TasksScreen merender judul, mata kuliah, dan blok prioritas dengan provider di-override (tanpa HTTP) |
| `test/widget/login_register_test.dart` | validasi password kuat, konfirmasi password, redirect ke tab Log In setelah register sukses |
| `test/widget/login_biometric_gate_test.dart` | gerbang Face ID muncul/tidak sesuai setting tersimpan |
| `test/widget/planner_choice_test.dart`, `planner_chat_review_test.dart` | 3 kartu pilihan AI Planner, panel review task hasil chat |
| `test/widget/materials_screen_test.dart` | daftar materi, upload, navigasi ke detail |
| `test/widget/study_screen_notification_test.dart` | reminder sesi terjadwal saat Start, batal saat End session |

### 6.3 Integration test (end-to-end, app asli lawan backend asli)

```bash
cd mobile
flutter test integration_test/app_flow_test.dart -d <device>   # simulator/emulator harus nyala, backend harus jalan
```

`integration_test/app_flow_test.dart` menjalankan app sungguhan (bukan widget test
dengan provider palsu): register → login → tambah mata kuliah → tambah task →
generate plan AI dari opsi random, lalu verifikasi task yang baru dibuat ikut
kejadwal. Hasil: **all tests passed** — lihat `screenshots/testing/mobile_integration_test_output.txt`.

---

## 7. Screenshot

Semua ada di folder [`screenshots/`](screenshots/), diambil langsung dari app (akun demo
`test2@gmail.com`) di iPhone 17 Pro Max Simulator:

| Alur | File |
|---|---|
| Login & Register | `01_login.png`, `02_register.png` |
| Home (setelah login) | `03_home.png` |
| Tasks (daftar + form tambah) | `04_tasks.png`, `05_add_task_sheet.png` |
| AI Planner — pilihan | `06_ai_choice.png` |
| AI Planner — generate random | `07_ai_random_ask.png` → `08_ai_random_reply.png` → `09_ai_random_generated.png` |
| AI Planner — adjust plan aktif | `10_ai_adjust_input.png` → `11_ai_adjust_result.png` |
| AI Planner — chat bebas | `12_ai_chat_empty.png` → `13_ai_chat_reply.png` → `15_ai_chat_generated.png` |
| Study session (timer, fast-forward, feedback) | `16_study_idle.png` → `17_study_running.png` → `18_study_fastforward.png` → `19_study_feedback.png` → `20_tasks_after_session.png` |
| Profile (mata kuliah, Face ID, materials) | `21_profile_full.png`, `22_materials.png`, `23_edit_profile.png`, `24_change_password.png` |
| Hasil testing — unit, widget, & integration test | [`screenshots/testing/`](screenshots/testing/) |

---

## 8. Struktur repo

```
.
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── core/          # config, db, security (JWT + bcrypt)
│   │   ├── models/        # SQLAlchemy: user, course, task, study_session, material, ai_generated, chat_message
│   │   ├── schemas/       # Pydantic request/response
│   │   ├── routers/       # auth, courses, tasks, study_sessions, materials, ai
│   │   ├── services/      # planning_service, groq_service, chat_service, materials_service
│   │   └── alembic/       # migrasi
│   └── tests/             # 73 test, lihat §6.1
├── mobile/
│   ├── lib/
│   │   ├── core/
│   │   │   ├── theme/         # colors, text_styles, brutal_decorations, app_theme
│   │   │   ├── widgets/       # BrutalCard, BrutalButton, BrutalChip, PriorityBlock, AiTag, ...
│   │   │   ├── router/        # app_router.dart (GoRouter + auth guard)
│   │   │   ├── network/       # api_client (interceptor JWT), token_storage, local_cache
│   │   │   └── notifications/ # NotificationService (reminder task & sesi)
│   │   ├── features/      # auth (+biometric), dashboard, tasks, courses, planner, materials, study_session, profile
│   │   └── main.dart
│   └── test/               # 73 test, lihat §6.2
├── screenshots/            # screenshot tiap layar (pakai akun test2@gmail.com) + hasil testing
├── design/                 # mockup HTML desain
└── README.md
```

**Alur backend:** `Router → Service → Model/DB`. Router hanya validasi dan memanggil
service; logika bisnis tinggal di `services/`.

**Alur mobile:** `Widget → Riverpod provider → Repository → dio`. Tidak ada widget
yang memanggil HTTP langsung. Semua token desain tinggal di `core/theme/` sebagai
konstanta, jadi tidak ada hex yang di-hardcode di layar.

---

## 9. Catatan keamanan

Yang sudah diterapkan:
- Password di-hash bcrypt dengan salt per-user; tidak pernah disimpan atau di-log plaintext
- JWT access (30 menit) dan refresh (7 hari) terpisah, dengan klaim `type` sehingga
  access token tidak bisa dipakai sebagai refresh token
- Setiap query difilter `user_id` — user tidak bisa membaca atau mengubah data orang lain
- Pesan error login disamakan untuk email salah dan password salah, supaya tidak
  membocorkan email mana yang terdaftar
- Nama file upload dinormalisasi (`Path(...).name`) untuk mencegah path traversal,
  hanya menerima PDF, maksimal 10 MB
- Semua secret lewat environment variable; `.env` tidak ikut di-commit
- Interceptor dio menangani `401` dengan sekali refresh lalu mengulang request

Yang belum, dan sadar belum:
- Token disimpan di `SharedPreferences`, bukan Keychain/Keystore. Untuk produksi
  ganti ke `flutter_secure_storage` — API `TokenStorage` sengaja dibuat kecil supaya
  penggantiannya cukup di satu file.
- Belum ada rate limiting di endpoint auth
- Belum ada blacklist refresh token saat logout (logout hanya menghapus token di client)

---
