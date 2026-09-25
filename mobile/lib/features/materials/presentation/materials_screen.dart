import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/brutal_chip.dart';
import '../../courses/data/course_repository.dart';
import '../../courses/domain/course.dart';
import '../data/material_repository.dart';
import '../domain/material_item.dart';
import 'material_detail_screen.dart';

class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(materialListProvider);
    final courses = ref.watch(courseListProvider).valueOrNull ?? const <Course>[];

    return Scaffold(
      floatingActionButton: _UploadFab(onTap: () => _showUploadSheet(context, ref)),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text('Materials', style: AppText.display(24)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Upload notes, get an AI summary and a quiz.',
                  style: AppText.body(12.5, weight: FontWeight.w600, color: AppColors.inkMuted(0.55))),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: materialsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: AppColors.ink)),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(error.toString(), textAlign: TextAlign.center, style: AppText.body(13)),
                  ),
                ),
                data: (materials) {
                  if (materials.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No materials yet — upload a PDF to get started.',
                            textAlign: TextAlign.center,
                            style: AppText.body(13, weight: FontWeight.w600, color: AppColors.inkMuted(0.5))),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.ink,
                    onRefresh: () async => ref.refresh(materialListProvider.future),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: materials.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _MaterialCard(
                        material: materials[i],
                        courseName: _courseName(courses, materials[i].courseId),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _courseName(List<Course> courses, int? courseId) {
    if (courseId == null) return null;
    for (final c in courses) {
      if (c.id == courseId) return c.name;
    }
    return null;
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.material, required this.courseName});

  final MaterialItem material;
  final String? courseName;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      shadowOffset: 3,
      padding: const EdgeInsets.all(13),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MaterialDetailScreen(material: material)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: Brutal.flat(fill: AppColors.accent),
            child: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(material.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(13.5, weight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  '${courseName ?? 'No course'} · ${DateFormat('MMM d').format(material.uploadedAt)}',
                  style: AppText.body(11, weight: FontWeight.w600, color: AppColors.inkMuted(0.55)),
                ),
                if (!material.hasExtractableText) ...[
                  const SizedBox(height: 4),
                  Text('No extractable text (scanned PDF?)',
                      style: AppText.body(11, weight: FontWeight.w600, color: AppColors.warning)),
                ],
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _confirmDelete(context, material),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 4, 8),
              child: Icon(Icons.delete_outline, size: 20, color: AppColors.inkMuted(0.5)),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.ink),
        ],
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, MaterialItem material) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.ink.withOpacity(0.55),
    builder: (_) => _DeleteDialog(material: material),
  );
}

class _DeleteDialog extends ConsumerStatefulWidget {
  const _DeleteDialog({required this.material});

  final MaterialItem material;

  @override
  ConsumerState<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends ConsumerState<_DeleteDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(materialListProvider.notifier).remove(widget.material.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: Brutal.box(shadowOffset: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delete Material?', style: AppText.display(19)),
                  const SizedBox(height: 12),
                  Text(
                    '"${widget.material.filename}" will be removed permanently.',
                    style: AppText.body(12.5, weight: FontWeight.w600, color: AppColors.inkMuted(0.65)),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: AppText.body(12, color: AppColors.danger, weight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 20),
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
                          label: 'Delete',
                          fill: AppColors.danger,
                          fontSize: 12,
                          loading: _deleting,
                          onPressed: _delete,
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

class _UploadFab extends StatelessWidget {
  const _UploadFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: Brutal.box(fill: AppColors.primary),
        child: const Icon(Icons.upload_file_outlined, color: Colors.white, size: 24),
      ),
    );
  }
}

Future<void> _showUploadSheet(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.ink.withOpacity(0.55),
    builder: (_) => const _UploadDialog(),
  );
}

class _UploadDialog extends ConsumerStatefulWidget {
  const _UploadDialog();

  @override
  ConsumerState<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends ConsumerState<_UploadDialog> {
  PlatformFile? _picked;
  int? _courseId;
  bool _uploading = false;
  String? _error;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _picked = result.files.single;
        _error = null;
      });
    }
  }

  Future<void> _upload() async {
    final file = _picked;
    if (file == null || file.path == null) {
      setState(() => _error = 'Pick a PDF file first');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await ref.read(materialListProvider.notifier).upload(
            filePath: file.path!,
            filename: file.name,
            courseId: _courseId,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(courseListProvider).valueOrNull ?? const <Course>[];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: Brutal.box(shadowOffset: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upload Material', style: AppText.display(19)),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Text(_error!, style: AppText.body(12, color: AppColors.danger, weight: FontWeight.w600)),
                    const SizedBox(height: 10),
                  ],
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: Brutal.flat(),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.ink),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _picked?.name ?? 'Choose a PDF file…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.body(12.5,
                                  weight: FontWeight.w600,
                                  color: _picked == null ? AppColors.inkMuted(0.5) : AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (courses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('COURSE (OPTIONAL)',
                        style: AppText.body(11, weight: FontWeight.w700).copyWith(letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final course in courses)
                          BrutalChip(
                            label: course.name,
                            selected: _courseId == course.id,
                            onTap: () => setState(
                                () => _courseId = _courseId == course.id ? null : course.id),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
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
                          label: 'Upload',
                          fontSize: 12,
                          loading: _uploading,
                          onPressed: _upload,
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
