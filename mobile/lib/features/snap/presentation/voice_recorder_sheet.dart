import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/brutal_button.dart';
import '../data/snap_repository.dart';

const _maxDuration = Duration(seconds: 60);

// rekam voice note, balikin bytes m4a-nya (null = batal). langsung mulai
// ngerekam begitu sheet kebuka, biar cukup sekali tap
Future<Uint8List?> showVoiceRecorder(BuildContext context) {
  return showModalBottomSheet<Uint8List>(
    context: context,
    isDismissible: false, // nutup mesti lewat Cancel/Done biar rekaman diberesin
    enableDrag: false,
    // default sheet cuma 9/16 layar, di HP kecil isinya kepotong
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceRecorderSheet(),
  );
}

class _VoiceRecorderSheet extends ConsumerStatefulWidget {
  const _VoiceRecorderSheet();

  @override
  ConsumerState<_VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends ConsumerState<_VoiceRecorderSheet> {
  late final AudioRecorder _recorder = ref.read(audioRecorderFactoryProvider)();
  StreamSubscription<Amplitude>? _amplitude;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  double _level = 0; // 0..1, buat gedein lingkaran mic
  bool _recording = false;
  bool _finishing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'Microphone access is off. Turn it on in Settings to use voice.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/snap_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      // mono 16 kHz udah cukup buat Whisper, file-nya kecil (~240 KB/menit).
      // noise suppression penting, booth/kelas itu berisik
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 32000,
          autoGain: true,
          noiseSuppress: true,
        ),
        path: path,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _recording = true);
      _amplitude = _recorder.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((a) {
        // dBFS: -45 (sepi) .. 0 (keras) -> 0..1
        if (mounted) setState(() => _level = ((a.current + 45) / 45).clamp(0.0, 1.0));
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(seconds: 1));
        if (_elapsed >= _maxDuration) _finish(); // auto stop
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start recording: $e');
    }
  }

  Future<void> _finish() async {
    if (_finishing || !_recording) return;
    _finishing = true;
    _ticker?.cancel();
    await _amplitude?.cancel();
    final path = await _recorder.stop();
    Uint8List? bytes;
    if (path != null) {
      final file = File(path);
      bytes = await file.readAsBytes();
      await file.delete(); // gak usah numpuk rekaman di HP
    }
    if (mounted) Navigator.of(context).pop(bytes);
  }

  Future<void> _cancel() async {
    _ticker?.cancel();
    await _amplitude?.cancel();
    if (_recording) await _recorder.cancel(); // cancel = stop + hapus file
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _amplitude?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final micSize = 92 + 36 * _level;
    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: Brutal.box(shadowOffset: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error != null ? 'Voice note' : 'Listening…', style: AppText.display(19)),
              const SizedBox(height: 6),
              Text(
                _error ??
                    'Say your tasks and deadlines, e.g. “Besok kuis Basis Data bab 3, '
                        'laporan modul 4 dikumpul Jumat jam 5 sore.”',
                textAlign: TextAlign.center,
                style: AppText.body(12,
                    color: _error != null ? AppColors.danger : AppColors.inkMuted(0.6),
                    weight: _error != null ? FontWeight.w700 : FontWeight.w500),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 132,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: micSize,
                    height: micSize,
                    decoration: BoxDecoration(
                      color: _recording ? AppColors.danger : AppColors.surface,
                      shape: BoxShape.circle,
                      border: Brutal.border(),
                    ),
                    child: const Icon(Icons.mic, size: 40, color: AppColors.ink),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('${_fmt(_elapsed)} / ${_fmt(_maxDuration)}',
                  style: AppText.display(14, weight: FontWeight.w700)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: BrutalButton(
                      label: 'Cancel',
                      fill: AppColors.surface,
                      labelColor: AppColors.ink,
                      fontSize: 12,
                      onPressed: _cancel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: BrutalButton(
                      label: 'Done',
                      fill: AppColors.ink,
                      labelColor: AppColors.accent,
                      fontSize: 12,
                      loading: _finishing,
                      enabled: _recording,
                      onPressed: _finish,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
