import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/ai_tag.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/brutal_text_field.dart';
import '../../planner/domain/task_candidate.dart';
import '../data/snap_repository.dart';
import 'snap_controller.dart';
import 'voice_recorder_sheet.dart';

// Snap & Go: foto pengumuman / screenshot grup kelas / paste teks -> AI baca ->
// review -> masuk Tasks. layar full tanpa bottom nav, masuknya dari Tasks & Home
class SnapScreen extends ConsumerWidget {
  const SnapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(snapControllerProvider);
    final busy = state.status == SnapStatus.reading || state.status == SnapStatus.saving;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
          children: [
            GestureDetector(
              onTap: busy ? null : () => context.canPop() ? context.pop() : context.go('/tasks'),
              child: Text('← Back',
                  style: AppText.body(12, weight: FontWeight.w700, color: AppColors.inkMuted(0.6))),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('Snap & Go', style: AppText.display(24)),
                const SizedBox(width: 10),
                const AiTag(),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Snap a class announcement, say it out loud, or drop a group-chat '
              'screenshot. AI turns it into tasks with deadlines.',
              style: AppText.body(12.5, color: AppColors.inkMuted(0.65)),
            ),
            const SizedBox(height: 20),
            if (state.error != null) ...[
              BrutalCard(
                fill: AppColors.danger,
                padding: const EdgeInsets.all(14),
                child: Text(state.error!, style: AppText.body(12.5, weight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),
            ],
            switch (state.status) {
              SnapStatus.pick => const _PickPanel(),
              SnapStatus.reading => _ReadingPanel(state: state),
              SnapStatus.review || SnapStatus.saving => _ReviewPanel(state: state),
            },
          ],
        ),
      ),
    );
  }
}

class _PickPanel extends ConsumerWidget {
  const _PickPanel();

  Future<void> _pick(BuildContext context, WidgetRef ref, ImageSource source) async {
    try {
      // dikecilin di HP: hemat kuota & di bawah batas 3 MB backend
      final file = await ref
          .read(imagePickerProvider)
          .pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
      if (file == null) return; // batal milih
      final bytes = await file.readAsBytes();
      await ref.read(snapControllerProvider.notifier).extract(image: bytes);
    } on PlatformException catch (e) {
      // izin kamera/galeri ditolak, atau kamera gak ada (simulator)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(e.message ?? 'Camera / gallery is not available',
              style: AppText.body(13)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SourceCard(
          icon: Icons.photo_camera_outlined,
          title: 'Take a photo',
          subtitle: 'Whiteboard, slide, or printed announcement',
          fill: AppColors.accent,
          onTap: () => _pick(context, ref, ImageSource.camera),
        ),
        const SizedBox(height: 12),
        _SourceCard(
          icon: Icons.mic_none_outlined,
          title: 'Say it',
          subtitle: 'Voice note: “besok kuis Basis Data bab 3…”',
          onTap: () async {
            final audio = await showVoiceRecorder(context);
            if (audio != null && audio.isNotEmpty) {
              await ref.read(snapControllerProvider.notifier).extractVoice(audio);
            }
          },
        ),
        const SizedBox(height: 12),
        _SourceCard(
          icon: Icons.image_outlined,
          title: 'Pick a screenshot',
          subtitle: 'WhatsApp / Line group chat, e-learning page',
          onTap: () => _pick(context, ref, ImageSource.gallery),
        ),
        const SizedBox(height: 12),
        _SourceCard(
          icon: Icons.content_paste_outlined,
          title: 'Paste text',
          subtitle: 'Copied a message from the class group? Paste it here',
          onTap: () async {
            final text = await showDialog<String>(
              context: context,
              barrierColor: AppColors.ink.withOpacity(0.55),
              builder: (_) => const _PasteTextDialog(),
            );
            if (text != null && text.trim().isNotEmpty) {
              await ref.read(snapControllerProvider.notifier).extract(text: text);
            }
          },
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.fill = AppColors.surface,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      fill: fill,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: Brutal.flat(),
            child: Icon(icon, size: 24, color: AppColors.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.display(15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppText.body(11.5,
                        weight: FontWeight.w600, color: AppColors.inkMuted(0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasteTextDialog extends StatefulWidget {
  const _PasteTextDialog();

  @override
  State<_PasteTextDialog> createState() => _PasteTextDialogState();
}

class _PasteTextDialogState extends State<_PasteTextDialog> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    // langsung ambil isi clipboard: alur biasanya copy pesan WA -> buka sini
    Clipboard.getData(Clipboard.kTextPlain).then((data) {
      final copied = data?.text;
      if (mounted && copied != null && _text.text.isEmpty) _text.text = copied;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: Brutal.box(shadowOffset: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paste text', style: AppText.display(19)),
                  const SizedBox(height: 14),
                  BrutalTextField(
                    label: 'Announcement',
                    controller: _text,
                    hint: 'e.g. Kuis Basis Data Rabu depan, laporan modul 3 dikumpul besok',
                    maxLines: 6,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: BrutalButton(
                          label: 'Cancel',
                          fill: AppColors.surface,
                          labelColor: AppColors.ink,
                          fontSize: 12,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: BrutalButton(
                          label: 'Read with AI',
                          fill: AppColors.ink,
                          labelColor: AppColors.accent,
                          fontSize: 12,
                          onPressed: () => Navigator.of(context).pop(_text.text),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// foto/teks yg lagi dibaca + loading
class _ReadingPanel extends StatelessWidget {
  const _ReadingPanel({required this.state});

  final SnapState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SourcePreview(state: state),
        const SizedBox(height: 24),
        const Center(child: CircularProgressIndicator(color: AppColors.ink)),
        const SizedBox(height: 14),
        Center(
          child: Text(state.voice ? 'Listening to your voice note…' : 'AI is reading it…',
              style: AppText.display(14, weight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _SourcePreview extends StatelessWidget {
  const _SourcePreview({required this.state, this.height = 220});

  final SnapState state;
  final double height;

  @override
  Widget build(BuildContext context) {
    final image = state.image;
    if (state.voice) return _VoicePreview(transcript: state.transcript);
    return Container(
      constraints: BoxConstraints(maxHeight: height),
      decoration: Brutal.box(shadowOffset: 3),
      clipBehavior: Clip.antiAlias,
      child: image != null
          ? Image.memory(image, fit: BoxFit.cover, width: double.infinity)
          : Padding(
              padding: const EdgeInsets.all(14),
              child: Text(state.text ?? '',
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(12.5, color: AppColors.inkMuted(0.75))),
            ),
    );
  }
}

// voice note: tampilin transkrip Whisper biar user tau AI dengernya apa
class _VoicePreview extends StatelessWidget {
  const _VoicePreview({required this.transcript});

  final String? transcript;

  @override
  Widget build(BuildContext context) {
    final text = transcript;
    return BrutalCard(
      shadowOffset: 3,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mic, size: 22, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text == null
                  ? 'Transcribing your voice note…'
                  : text.isEmpty
                      ? "Couldn't hear anything — try again a bit closer to the mic."
                      : '“$text”',
              style: AppText.body(12.5,
                  weight: FontWeight.w600, color: AppColors.inkMuted(0.8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPanel extends ConsumerWidget {
  const _ReviewPanel({required this.state});

  final SnapState state;

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final saved = await ref.read(snapControllerProvider.notifier).save();
    if (saved == 0 || !context.mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text('$saved ${saved == 1 ? 'task' : 'tasks'} added',
          style: AppText.body(13, weight: FontWeight.w600)),
    ));
    context.go('/tasks');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(snapControllerProvider.notifier);
    final saving = state.status == SnapStatus.saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SourcePreview(state: state, height: 120),
        const SizedBox(height: 20),
        if (state.candidates.isEmpty) ...[
          Text('No tasks found', style: AppText.display(16)),
          const SizedBox(height: 6),
          Text(
            "AI couldn't spot any assignment or deadline here. Try a clearer photo, "
            'or paste the text instead.',
            style: AppText.body(12.5, color: AppColors.inkMuted(0.65)),
          ),
        ] else ...[
          Text('Found ${state.candidates.length} '
              '${state.candidates.length == 1 ? 'task' : 'tasks'}',
              style: AppText.display(16)),
          const SizedBox(height: 6),
          Text('Uncheck anything that is not right, then add them to your tasks.',
              style: AppText.body(12, color: AppColors.inkMuted(0.6))),
          const SizedBox(height: 14),
          for (var i = 0; i < state.candidates.length; i++) ...[
            _CandidateRow(
              candidate: state.candidates[i],
              selected: !state.deselected.contains(i),
              onTap: saving ? null : () => controller.toggle(i),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          BrutalButton(
            label: state.selectedCount == 0
                ? 'Select at least one'
                : 'Add ${state.selectedCount} to tasks',
            fill: AppColors.ink,
            labelColor: AppColors.accent,
            loading: saving,
            enabled: state.selectedCount > 0,
            onPressed: () => _save(context, ref),
          ),
        ],
        const SizedBox(height: 14),
        Center(
          child: GestureDetector(
            onTap: saving ? null : controller.reset,
            child: Text('Snap another',
                style: AppText.body(12, weight: FontWeight.w700, color: AppColors.inkMuted(0.6))),
          ),
        ),
      ],
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.candidate, required this.selected, required this.onTap});

  final TaskCandidate candidate;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final due = candidate.dueDate?.toLocal();
    return BrutalCard(
      onTap: onTap,
      shadowOffset: 3,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: Brutal.flat(fill: selected ? AppColors.primary : AppColors.surface),
            child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(candidate.title, style: AppText.display(13.5, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${candidate.course} · ${candidate.type}',
                  style: AppText.body(11, weight: FontWeight.w600, color: AppColors.inkMuted(0.6)),
                ),
                const SizedBox(height: 2),
                Text(
                  due == null ? 'No deadline' : 'Due ${DateFormat('EEE, MMM d · HH:mm').format(due)}',
                  style: AppText.body(11,
                      weight: FontWeight.w700,
                      color: due == null ? AppColors.inkMuted(0.45) : AppColors.danger),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
