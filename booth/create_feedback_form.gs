/**
 * Buat Google Form feedback booth CampusFlow — Tech Expo Booth SRIFOTON 2026.
 *
 * Cara pakai:
 *   1. Buka https://script.google.com → New project.
 *   2. Hapus isi Code.gs, paste seluruh file ini, lalu Save.
 *   3. Pilih fungsi `createFeedbackForm` di toolbar → Run → izinkan akses (Review permissions).
 *   4. Buka View → Logs (Execution log): di sana ada link form untuk responden,
 *      link edit, dan link spreadsheet hasil respons.
 *
 * Kalau MOVE_TO_PANITIA_FOLDER = true, file form langsung dipindah ke folder
 * Google Drive panitia. Kalau akunmu tidak punya akses edit ke folder itu,
 * form tetap dibuat di My Drive dan log akan memberi tahu.
 */

const CONFIG = {
  title: 'Feedback Booth CampusFlow — Tech Expo SRIFOTON 2026',
  presenter: 'Darrell Satriano',
  // Folder "pengumpulan form feedback & PPT" dari panitia SRIFOTON 2026.
  panitiaFolderId: '1wwOdTG7xPX77GmcT2TgyrBxg_yU0ZmTB',
  MOVE_TO_PANITIA_FOLDER: true,
};

function createFeedbackForm() {
  const form = FormApp.create(CONFIG.title);
  form
    .setDescription(
      'Halo! 👋 Terima kasih sudah mampir ke booth CampusFlow.\n\n' +
        'CampusFlow adalah AI academic life manager untuk mahasiswa: mengubah mata kuliah, ' +
        'tugas, dan deadline menjadi jadwal belajar terprioritas — lengkap dengan AI Planner, ' +
        'Snap & Go (foto pengumuman → jadi tugas), ringkasan & kuis materi PDF, dan timer Pomodoro.\n\n' +
        'Isi form ini cuma ±2 menit. Masukanmu sangat membantu pengembangan aplikasi ini 🙏\n\n' +
        'Presenter: ' + CONFIG.presenter + ' · Final Project Mobile Development GDGoC UNSRI'
    )
    .setConfirmationMessage(
      'Terima kasih atas feedback-nya! 🙌 Sampai jumpa lagi di SRIFOTON 2026 ✨'
    )
    .setCollectEmail(false)
    .setAllowResponseEdits(false)
    .setLimitOneResponsePerUser(false) // pengunjung tidak wajib login Google
    .setProgressBar(true)
    .setShowLinkToRespondAgain(false);

  // ── Bagian 1: Tentang kamu ────────────────────────────────────────────────
  form.addSectionHeaderItem().setTitle('Tentang Kamu');

  form.addTextItem().setTitle('Nama').setHelpText('Boleh nama panggilan.').setRequired(true);

  form
    .addMultipleChoiceItem()
    .setTitle('Status')
    .setChoiceValues(['Mahasiswa', 'Dosen / Staf', 'Pelajar SMA/SMK', 'Umum / Industri'])
    .showOtherOption(true)
    .setRequired(true);

  form
    .addTextItem()
    .setTitle('Asal instansi / jurusan')
    .setHelpText('Contoh: Teknik Informatika UNSRI')
    .setRequired(false);

  // ── Bagian 2: Presentasi booth ────────────────────────────────────────────
  form.addPageBreakItem().setTitle('Presentasi Booth');

  form
    .addGridItem()
    .setTitle('Seberapa setuju kamu dengan pernyataan berikut?')
    .setRows([
      'Penjelasan presenter mudah dipahami',
      'Demo aplikasi berjalan lancar',
      'Masalah yang diselesaikan relevan dengan kehidupan mahasiswa',
      'Tampilan booth menarik',
    ])
    .setColumns(['Sangat tidak setuju', 'Tidak setuju', 'Netral', 'Setuju', 'Sangat setuju'])
    .setRequired(true);

  // ── Bagian 3: Aplikasi CampusFlow ─────────────────────────────────────────
  form.addPageBreakItem().setTitle('Aplikasi CampusFlow');

  form
    .addScaleItem()
    .setTitle('Secara keseluruhan, seberapa bagus aplikasi CampusFlow menurutmu?')
    .setBounds(1, 5)
    .setLabels('Kurang', 'Sangat bagus')
    .setRequired(true);

  const features = [
    'AI Planner (generate / adjust jadwal / chat)',
    'Snap & Go (foto / screenshot / teks → tugas)',
    'Input suara (voice note → tugas)',
    'Ringkasan & kuis dari PDF materi',
    'Timer Pomodoro + feedback sesi',
    'Notifikasi deadline',
    'Dashboard Today\'s Focus & study streak',
    'Login biometrik (Face ID / sidik jari)',
  ];

  form
    .addCheckboxItem()
    .setTitle('Fitur apa saja yang kamu lihat atau coba?')
    .setChoiceValues(features)
    .setRequired(false);

  form
    .addMultipleChoiceItem()
    .setTitle('Fitur mana yang paling berguna buat kamu?')
    .setChoiceValues(features)
    .showOtherOption(true)
    .setRequired(true);

  form
    .addScaleItem()
    .setTitle('Bagaimana tampilan (UI) gaya neo-brutalism CampusFlow?')
    .setBounds(1, 5)
    .setLabels('Kurang menarik', 'Sangat menarik')
    .setRequired(true);

  form
    .addScaleItem()
    .setTitle('Seberapa membantu fitur AI-nya dalam mengatur tugas & jadwal belajar?')
    .setBounds(1, 5)
    .setLabels('Tidak membantu', 'Sangat membantu')
    .setRequired(true);

  form
    .addMultipleChoiceItem()
    .setTitle('Apakah kamu akan memakai CampusFlow untuk kuliah sehari-hari?')
    .setChoiceValues(['Ya, pasti', 'Mungkin', 'Belum / tidak'])
    .setRequired(true);

  form
    .addScaleItem()
    .setTitle('Seberapa besar kemungkinan kamu merekomendasikan CampusFlow ke teman?')
    .setBounds(0, 10)
    .setLabels('Tidak mungkin', 'Pasti')
    .setRequired(true);

  form
    .addMultipleChoiceItem()
    .setTitle('Sudah install APK CampusFlow lewat QR di booth?')
    .setChoiceValues(['Sudah', 'Belum, tapi mau', 'Tidak (pakai iPhone / tidak tertarik)'])
    .setRequired(false);

  // ── Bagian 4: Saran ───────────────────────────────────────────────────────
  form.addPageBreakItem().setTitle('Kritik & Saran');

  form
    .addParagraphTextItem()
    .setTitle('Apa yang paling kamu suka dari CampusFlow?')
    .setRequired(false);

  form
    .addParagraphTextItem()
    .setTitle('Apa yang perlu diperbaiki, atau fitur apa yang ingin kamu tambahkan?')
    .setRequired(false);

  form
    .addParagraphTextItem()
    .setTitle('Pesan / kesan untuk presenter')
    .setRequired(false);

  // ── Spreadsheet respons ───────────────────────────────────────────────────
  const sheet = SpreadsheetApp.create(CONFIG.title + ' (Respons)');
  form.setDestination(FormApp.DestinationType.SPREADSHEET, sheet.getId());

  // ── Pindahkan ke folder panitia ───────────────────────────────────────────
  let folderNote = 'Form disimpan di My Drive (MOVE_TO_PANITIA_FOLDER = false).';
  if (CONFIG.MOVE_TO_PANITIA_FOLDER) {
    try {
      const folder = DriveApp.getFolderById(CONFIG.panitiaFolderId);
      DriveApp.getFileById(form.getId()).moveTo(folder);
      folderNote = 'Form sudah dipindah ke folder panitia: ' + folder.getUrl();
    } catch (e) {
      folderNote =
        'Gagal memindah ke folder panitia (' + e.message + '). ' +
        'Form tetap ada di My Drive — upload/pindahkan manual.';
    }
  }

  const publishedUrl = form.getPublishedUrl();
  Logger.log('✅ Form berhasil dibuat');
  Logger.log('Link untuk responden : ' + form.shortenFormUrl(publishedUrl));
  Logger.log('Link lengkap         : ' + publishedUrl);
  Logger.log('Link edit form       : ' + form.getEditUrl());
  Logger.log('Spreadsheet respons  : ' + sheet.getUrl());
  Logger.log(folderNote);
  Logger.log(
    'QR code (buka di browser, lalu simpan gambarnya): ' +
      'https://api.qrserver.com/v1/create-qr-code/?size=600x600&data=' +
      encodeURIComponent(publishedUrl)
  );
}
