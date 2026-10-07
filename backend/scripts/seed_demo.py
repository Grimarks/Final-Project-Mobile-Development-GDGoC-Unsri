"""Isi (atau reset) akun demo booth dengan data contoh yang realistis, lewat API
publik — jadi bisa dipake ke server mana aja (lokal / Render) tanpa akses DB.

    python scripts/seed_demo.py --base-url https://campusflow-api-wbu7.onrender.com \\
        --email demo@campusflow.app --password 'DemoBooth2026!'

Dijalanin ulang = reset: task, course, materi, sama chat akun itu dihapus dulu, terus
diisi lagi dengan deadline yg dihitung dari HARI INI. Riwayat sesi belajar gak bisa
dihapus lewat API, jadi cuma ditambah (streak tetep keitung bener).
"""
from __future__ import annotations

import argparse
import sys
import zlib
from datetime import datetime, time, timedelta
from zoneinfo import ZoneInfo

import httpx

WIB = ZoneInfo("Asia/Jakarta")

COURSES = [
    ("Basis Data Terdistribusi", "#4C6FFF"),
    ("Pemrograman Mobile", "#FF8A3D"),
    ("Kecerdasan Buatan", "#3DDC84"),
    ("Rekayasa Perangkat Lunak", "#FF4C4C"),
    ("Statistika", "#FFD23F"),
]

# (course, judul, tipe, kesulitan, deadline: (hari dari sekarang, jam WIB) / None,
#  status, progres %)
TASKS = [
    ("Basis Data Terdistribusi", "Laporan praktikum modul 3", "assignment", "hard",
     (0, time(23, 59)), "not_started", 0),
    ("Kecerdasan Buatan", "Kuis searching algorithm", "quiz", "medium",
     (1, time(10, 0)), "not_started", 0),
    ("Pemrograman Mobile", "Final project: demo aplikasi", "assignment", "hard",
     (3, time(13, 0)), "in_progress", 70),
    ("Rekayasa Perangkat Lunak", "UTS Rekayasa Perangkat Lunak", "exam", "hard",
     (2, time(8, 0)), "not_started", 0),
    ("Statistika", "Latihan soal distribusi normal", "assignment", "easy",
     (4, time(23, 59)), "not_started", 0),
    ("Kecerdasan Buatan", "Resume paper machine learning", "assignment", "medium",
     (9, time(23, 59)), "not_started", 0),
    ("Basis Data Terdistribusi", "Baca materi replikasi data", "assignment", "easy",
     None, "not_started", 0),
    ("Statistika", "Tugas uji hipotesis", "assignment", "medium",
     (-2, time(23, 59)), "done", 100),
    ("Pemrograman Mobile", "Mockup UI di Figma", "assignment", "medium",
     (-1, time(17, 0)), "done", 100),
]

MATERIAL_LINES = [
    "Normalisasi Basis Data",
    "",
    "Normalisasi adalah proses mengorganisasi tabel dalam basis data relasional untuk",
    "mengurangi redundansi data dan mencegah anomali insert, update, dan delete.",
    "",
    "Bentuk Normal Pertama (1NF): setiap kolom berisi nilai atomik dan tidak ada",
    "kelompok data yang berulang dalam satu baris.",
    "",
    "Bentuk Normal Kedua (2NF): memenuhi 1NF dan setiap atribut non-kunci bergantung",
    "penuh pada seluruh primary key, bukan hanya sebagian dari kunci komposit.",
    "",
    "Bentuk Normal Ketiga (3NF): memenuhi 2NF dan tidak ada ketergantungan transitif,",
    "yaitu atribut non-kunci tidak boleh bergantung pada atribut non-kunci lain.",
    "",
    "Boyce-Codd Normal Form (BCNF): versi yang lebih ketat dari 3NF, di mana setiap",
    "determinan dalam ketergantungan fungsional harus merupakan candidate key.",
    "",
    "Denormalisasi kadang dilakukan secara sengaja pada sistem terdistribusi untuk",
    "mempercepat query baca, dengan konsekuensi data duplikat harus dijaga konsistensinya.",
    "",
    "Contoh: tabel Mahasiswa(NIM, Nama, KodeProdi, NamaProdi) melanggar 3NF karena",
    "NamaProdi bergantung pada KodeProdi. Solusinya memecah menjadi tabel Mahasiswa",
    "(NIM, Nama, KodeProdi) dan tabel Prodi(KodeProdi, NamaProdi).",
]


def build_text_pdf(lines: list[str]) -> bytes:
    """PDF 1 halaman berisi teks (Helvetica), tanpa library tambahan. Cukup buat
    pypdf di backend bisa ekstrak teksnya -> ringkasan & kuis AI jalan."""

    def esc(text: str) -> str:
        return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")

    ops = ["BT", "/F1 11 Tf", "14 TL", "56 780 Td"]
    for i, line in enumerate(lines):
        size = "16" if i == 0 else "11"
        ops.append(f"/F1 {size} Tf ({esc(line)}) Tj T*")
    ops.append("ET")
    stream = zlib.compress("\n".join(ops).encode("latin-1"))

    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
        b"/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
        b"<< /Length %d /Filter /FlateDecode >>\nstream\n" % len(stream)
        + stream
        + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica "
        b"/Encoding /WinAnsiEncoding >>",
    ]
    out = bytearray(b"%PDF-1.4\n")
    offsets = []
    for number, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += b"%d 0 obj\n" % number + body + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objects) + 1)
    for offset in offsets:
        out += b"%010d 00000 n \n" % offset
    out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (
        len(objects) + 1,
        xref,
    )
    return bytes(out)


def _check(resp: httpx.Response, *expected: int) -> httpx.Response:
    if resp.status_code not in (expected or (200,)):
        sys.exit(f"Gagal {resp.request.method} {resp.request.url.path}: "
                 f"{resp.status_code} {resp.text[:300]}")
    return resp


def login_or_register(client: httpx.Client, name: str, email: str, password: str) -> None:
    resp = client.post("/auth/login", json={"email": email, "password": password})
    if resp.status_code == 401:
        resp = _check(
            client.post("/auth/register", json={"name": name, "email": email, "password": password}),
            201,
        )
        print(f"Akun demo dibuat: {email}")
    else:
        _check(resp)
        print(f"Akun demo sudah ada, di-reset: {email}")
    client.headers["Authorization"] = f"Bearer {resp.json()['tokens']['access_token']}"


def wipe(client: httpx.Client) -> None:
    for material in _check(client.get("/materials")).json():
        _check(client.delete(f"/materials/{material['id']}"), 204)
    # hapus course ikut ngehapus task-nya; task tanpa course dihapus sendiri
    for course in _check(client.get("/courses")).json():
        _check(client.delete(f"/courses/{course['id']}"), 204)
    for task in _check(client.get("/tasks")).json():
        _check(client.delete(f"/tasks/{task['id']}"), 204)
    _check(client.delete("/ai/chat/history"), 204)


def seed(client: httpx.Client, now: datetime) -> None:
    course_ids = {}
    for name, color in COURSES:
        course = _check(client.post("/courses", json={"name": name, "color": color}), 201).json()
        course_ids[name] = course["id"]

    first_task_id = None
    for course, title, kind, difficulty, due, status, progress in TASKS:
        due_at = None
        if due is not None:
            days, at = due
            due_at = datetime.combine(now.date() + timedelta(days=days), at, tzinfo=WIB)
        task = _check(
            client.post(
                "/tasks",
                json={
                    "title": title,
                    "course_id": course_ids[course],
                    "type": kind,
                    "difficulty": difficulty,
                    "due_date": due_at.isoformat() if due_at else None,
                },
            ),
            201,
        ).json()
        first_task_id = first_task_id or task["id"]
        if status != "not_started" or progress:
            _check(client.put(f"/tasks/{task['id']}", json={"status": status, "progress_pct": progress}))
    print(f"{len(COURSES)} mata kuliah, {len(TASKS)} task")

    # sesi fokus 4 hari terakhir + hari ini -> streak 5 hari di Home
    for days_ago in range(4, -1, -1):
        start = datetime.combine(now.date() - timedelta(days=days_ago), time(19, 30), tzinfo=WIB)
        if start > now:
            start = now - timedelta(minutes=30)
        session = _check(
            client.post(
                "/study-sessions",
                json={
                    "task_id": first_task_id,
                    "planned_start": start.isoformat(),
                    "planned_end": (start + timedelta(minutes=25)).isoformat(),
                },
            ),
            201,
        ).json()
        _check(
            client.patch(
                f"/study-sessions/{session['id']}/complete",
                json={"feedback": ["normal", "easy", "hard"][days_ago % 3], "actual_duration": 25},
            )
        )
    print("5 sesi fokus (streak 5 hari)")

    material = _check(
        client.post(
            "/materials/upload",
            files={"file": ("Normalisasi Basis Data.pdf", build_text_pdf(MATERIAL_LINES), "application/pdf")},
            data={"course_id": str(course_ids["Basis Data Terdistribusi"])},
        ),
        201,
    ).json()
    print(f"Materi PDF: {material['filename']} ({material['text_length']} karakter teks)")

    # jadwal hari ini yg udah di-accept, biar "Today's Plan" di Home langsung keisi.
    # mulai jam berikutnya (minimal 08:00, maksimal 20:00 biar muat 3 jam)
    start_hour = min(max(now.hour + 1, 8), 20)
    plan = _check(
        client.post("/ai/plan", json={"available_hours": 3, "start_hour": start_hour}),
        200,
    ).json()
    if plan["blocks"]:
        _check(client.post(f"/ai/plan/{plan['plan_id']}/accept"))
        print(f"Plan hari ini: {len(plan['blocks'])} sesi mulai {plan['start_time']} "
              f"(dibuat oleh {plan['generated_by']})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    parser.add_argument("--email", default="demo@campusflow.app")
    parser.add_argument("--password", required=True)
    parser.add_argument("--name", default="Demo CampusFlow")
    args = parser.parse_args()

    with httpx.Client(base_url=args.base_url.rstrip("/"), timeout=120) as client:
        _check(client.get("/health"))  # sekalian bangunin server Render
        login_or_register(client, args.name, args.email, args.password)
        wipe(client)
        seed(client, datetime.now(WIB))
    print("Selesai.")


if __name__ == "__main__":
    main()
