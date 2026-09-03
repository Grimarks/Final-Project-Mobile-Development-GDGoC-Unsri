import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/ai_tag.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/brutal_text_field.dart';
import '../data/planner_repository.dart';
import '../domain/chat_message.dart';
import '../domain/plan.dart';
import '../domain/task_candidate.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(plannerModeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('AI Planner', style: AppText.display(24)),
                  const SizedBox(width: 8),
                  const AiTag(),
                ],
              ),
              const SizedBox(height: 20),
              switch (mode) {
                PlannerMode.none => const _ChoicePanel(),
                PlannerMode.random => const _RandomPlanPanel(),
                PlannerMode.adjust => const _AdjustPlanPanel(),
                PlannerMode.chat => const _ChatModePanel(),
              },
            ],
          ),
        ),
      ),
    );
  }
}

// ikon petir simpel
class _BoltIcon extends StatelessWidget {
  const _BoltIcon({this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.bolt_outlined, size: size, color: AppColors.ink);
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Text('← Back',
            style: AppText.body(12, weight: FontWeight.w700, color: AppColors.inkMuted(0.6))),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: BrutalCard(
          fill: AppColors.danger,
          padding: const EdgeInsets.all(14),
          child: Text(message, style: AppText.body(12.5, weight: FontWeight.w600)),
        ),
      );
}

// --- kartu pilihan awal, 3 alur ---
class _ChoicePanel extends ConsumerWidget {
  const _ChoicePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final select = ref.read(plannerModeProvider.notifier).select;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How do you want to plan today?',
            style: AppText.body(13, weight: FontWeight.w600, color: AppColors.inkMuted(0.6))),
        const SizedBox(height: 14),
        _ChoiceCard(
          icon: Icons.bolt_outlined,
          iconFill: AppColors.accent,
          title: 'Let me generate a random plan based on your free time',
          description: "Tell me how many hours you're free today and I'll build a schedule.",
          onTap: () => select(PlannerMode.random),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          icon: Icons.tune,
          iconFill: AppColors.primary,
          title: 'Adjust my plan right now',
          description: 'Tweak your currently active plan with a free-form instruction.',
          onTap: () => select(PlannerMode.adjust),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          icon: Icons.chat_bubble_outline,
          iconFill: AppColors.ink,
          title: 'Talk to me',
          description: 'Chat freely about your workload, mood, or study preferences first.',
          onTap: () => select(PlannerMode.chat),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.iconFill,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color iconFill;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = iconFill == AppColors.ink ? AppColors.accent : AppColors.ink;
    return BrutalCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: Brutal.flat(fill: iconFill),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.display(15)),
                const SizedBox(height: 4),
                Text(description,
                    style: AppText.body(12, color: AppColors.inkMuted(0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 1. random plan: tanya jam luang, generate ---
class _RandomPlanPanel extends ConsumerWidget {
  const _RandomPlanPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(randomPlanControllerProvider);
    final controller = ref.read(randomPlanControllerProvider.notifier);
    final modeNotifier = ref.read(plannerModeProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(onTap: modeNotifier.reset),
        const SizedBox(height: 14),
        if (state.error != null) _ErrorBanner(message: state.error!),
        switch (state.phase) {
          RandomPlanPhase.askingHours => _AskHoursPanel(state: state, controller: controller),
          RandomPlanPhase.generating => const _GeneratingPanel(),
          RandomPlanPhase.generated => _GeneratedPanel(
              plan: state.plan!,
              onAdjust: () => modeNotifier.select(PlannerMode.adjust),
            ),
        },
      ],
    );
  }
}

// langkah tanya jam: user nyebutin jam luang + preferensi, dikirim ke backend
// jadi field `preference`
class _AskHoursPanel extends StatefulWidget {
  const _AskHoursPanel({required this.state, required this.controller});

  final RandomPlanState state;
  final RandomPlanController controller;

  @override
  State<_AskHoursPanel> createState() => _AskHoursPanelState();
}

class _AskHoursPanelState extends State<_AskHoursPanel> {
  String? _reply;

  static const _quickReplies = [
    ('3.5 hours free, mornings work best', 3.5),
    ('Just use my tasks and deadlines', 3.5),
    ('Only 2 hours today', 2.0),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AiBubble(
          text: _reply == null
              ? 'Hi! Before I plan your day — how many hours do you have free today, and any preferences?'
              : 'Got it — building a schedule around that now.',
        ),
        const SizedBox(height: 14),
        if (_reply == null)
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (text, hours) in _quickReplies) ...[
                  GestureDetector(
                    onTap: () {
                      widget.controller.setPreference(text, hours: hours);
                      setState(() => _reply = text);
                    },
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                      decoration: Brutal.flat(),
                      child: Text(text,
                          style: AppText.body(12.5, weight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          )
        else ...[
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: Brutal.flat(fill: AppColors.primary),
              child: Text(_reply!,
                  style: AppText.body(13,
                      weight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
          BrutalButton(
            label: 'Generate plan',
            fill: AppColors.ink,
            labelColor: AppColors.accent,
            onPressed: widget.controller.generate,
          ),
        ],
      ],
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: Brutal.flat(fill: AppColors.accent),
          child: const _BoltIcon(size: 15),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: Brutal.flat(),
            child: Text(text, style: AppText.body(13)),
          ),
        ),
      ],
    );
  }
}

class _GeneratingPanel extends StatelessWidget {
  const _GeneratingPanel();

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      fill: AppColors.accent,
      padding: const EdgeInsets.symmetric(vertical: 44),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.ink),
          const SizedBox(height: 18),
          Text('Building your schedule…', style: AppText.display(16)),
        ],
      ),
    );
  }
}

// panel hasil plan, dipake bareng sama alur random/adjust/chat
class _GeneratedPanel extends StatelessWidget {
  const _GeneratedPanel({required this.plan, required this.onAdjust});

  final StudyPlan plan;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    // biar user tau ini jadwal dari LLM apa fallback lokal
    final source = plan.generatedBy == 'groq' ? 'Groq AI' : 'local planner';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Generated from ${plan.openTaskCount} open tasks · '
          '${plan.availableHours} hrs available · $source',
          style: AppText.body(11.5,
              weight: FontWeight.w600, color: AppColors.inkMuted(0.55)),
        ),
        const SizedBox(height: 14),
        if (plan.blocks.isEmpty)
          BrutalCard(
            child: Text('Tidak ada task terbuka untuk dijadwalkan.',
                style: AppText.body(13)),
          )
        else
          for (final block in plan.blocks) ...[
            _PlanBlockCard(block: block),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: BrutalButton(
                label: 'Adjust',
                fill: AppColors.surface,
                labelColor: AppColors.ink,
                fontSize: 12.5,
                onPressed: onAdjust,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: BrutalButton(
                label: 'Accept plan',
                fontSize: 12.5,
                // accept plan = balik ke Home, biar user milih sendiri task mana
                // yg mau dikerjain duluan dari kartu Today's Focus
                onPressed: () => context.go('/home'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlanBlockCard extends StatelessWidget {
  const _PlanBlockCard({required this.block});

  final PlanBlock block;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      shadowOffset: 3,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(block.timeLabel,
                style: AppText.display(12, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Container(width: 2, height: 36, color: AppColors.ink.withOpacity(0.15)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(block.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(13.5, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: block.color,
                        border: Brutal.border(width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(block.course ?? 'No course',
                        style: AppText.body(11,
                            weight: FontWeight.w600,
                            color: AppColors.inkMuted(0.6))),
                  ],
                ),
              ],
            ),
          ),
          Text('${block.durationMinutes} min',
              style: AppText.body(11,
                  weight: FontWeight.w600, color: AppColors.inkMuted(0.55))),
        ],
      ),
    );
  }
}

// --- 2. adjust plan aktif pake instruksi bebas ---
class _AdjustPlanPanel extends ConsumerStatefulWidget {
  const _AdjustPlanPanel();

  @override
  ConsumerState<_AdjustPlanPanel> createState() => _AdjustPlanPanelState();
}

class _AdjustPlanPanelState extends ConsumerState<_AdjustPlanPanel> {
  final _instructionController = TextEditingController();

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adjustPlanControllerProvider);
    final notifier = ref.read(adjustPlanControllerProvider.notifier);
    final modeNotifier = ref.read(plannerModeProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(onTap: modeNotifier.reset),
        const SizedBox(height: 14),
        switch (state.phase) {
          AdjustPlanPhase.noActivePlan => _NoActivePlanCard(
              message: state.error ?? 'Belum ada plan aktif.',
              onGenerateInstead: () => modeNotifier.select(PlannerMode.random),
            ),
          AdjustPlanPhase.result => _AdjustResultView(
              result: state.result!,
              onAdjustAgain: notifier.reset,
            ),
          AdjustPlanPhase.input || AdjustPlanPhase.submitting => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.error != null) _ErrorBanner(message: state.error!),
                Text('What should change?', style: AppText.display(16)),
                const SizedBox(height: 8),
                Text(
                  'e.g. "move the CS 301 session to the afternoon" or '
                  '"I only have 1 hour now, trim it down"',
                  style: AppText.body(12, color: AppColors.inkMuted(0.6)),
                ),
                const SizedBox(height: 14),
                BrutalTextField(
                  label: 'Instruction',
                  controller: _instructionController,
                  hint: 'Type your instruction…',
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                BrutalButton(
                  label: 'Adjust plan',
                  loading: state.phase == AdjustPlanPhase.submitting,
                  onPressed: () {
                    final text = _instructionController.text.trim();
                    if (text.isEmpty) return;
                    notifier.submit(text);
                  },
                ),
              ],
            ),
        },
      ],
    );
  }
}

class _NoActivePlanCard extends StatelessWidget {
  const _NoActivePlanCard({required this.message, required this.onGenerateInstead});

  final String message;
  final VoidCallback onGenerateInstead;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      fill: AppColors.danger,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Belum ada plan aktif',
              style: AppText.display(15, color: Colors.white)),
          const SizedBox(height: 6),
          Text(message, style: AppText.body(12.5, color: Colors.white)),
          const SizedBox(height: 16),
          BrutalButton(
            label: 'Generate a plan first',
            fill: AppColors.ink,
            labelColor: AppColors.accent,
            shadowColor: Colors.white.withOpacity(0.4),
            onPressed: onGenerateInstead,
          ),
        ],
      ),
    );
  }
}

class _AdjustResultView extends StatelessWidget {
  const _AdjustResultView({required this.result, required this.onAdjustAgain});

  final AdjustPlanResult result;
  final VoidCallback onAdjustAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!result.adjusted)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: BrutalCard(
              fill: AppColors.warning,
              padding: const EdgeInsets.all(14),
              child: Text(
                result.error ?? 'Gagal menyesuaikan plan, jadwal lama tetap dipakai.',
                style: AppText.body(12.5, weight: FontWeight.w600),
              ),
            ),
          ),
        _GeneratedPanel(plan: result.plan, onAdjust: onAdjustAgain),
      ],
    );
  }
}

// --- 3. chat multi-turn + generate plan dari chat ---
class _ChatModePanel extends ConsumerStatefulWidget {
  const _ChatModePanel();

  @override
  ConsumerState<_ChatModePanel> createState() => _ChatModePanelState();
}

class _ChatModePanelState extends ConsumerState<_ChatModePanel> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(chatControllerProvider.notifier).loadHistory());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final notifier = ref.read(chatControllerProvider.notifier);
    final modeNotifier = ref.read(plannerModeProvider.notifier);

    ref.listen(chatControllerProvider.select((s) => s.messages.length), (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _BackButton(onTap: modeNotifier.reset),
            GestureDetector(
              onTap: notifier.startOver,
              child: Text('Start over',
                  style: AppText.body(12, weight: FontWeight.w700, color: AppColors.danger)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (state.error != null) _ErrorBanner(message: state.error!),
        if (state.plan != null)
          _GeneratedPanel(
            plan: state.plan!,
            onAdjust: () => modeNotifier.select(PlannerMode.adjust),
          )
        else if (state.reviewCandidates.isNotEmpty)
          _TaskReviewPanel(
            candidates: state.reviewCandidates,
            deselected: state.deselectedIndices,
            onToggle: notifier.toggleCandidate,
            onConfirm: notifier.confirmCandidatesAndGenerate,
            onSkip: notifier.skipReview,
            onCancel: notifier.cancelReview,
            submitting: state.status == ChatStatus.generatingPlan,
          )
        else if (state.loadingHistory)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator(color: AppColors.ink)),
          )
        else ...[
          SizedBox(
            height: 340,
            child: state.messages.isEmpty
                ? const _AiBubble(
                    text:
                        "Hi! Tell me about your day — how much free time you have, what's on "
                        'your mind, or how you like to study.',
                  )
                : ListView.separated(
                    controller: _scrollController,
                    itemCount: state.messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ChatBubble(message: state.messages[i]),
                  ),
          ),
          const SizedBox(height: 12),
          if (state.canGeneratePlan)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BrutalButton(
                label: 'Generate plan from this chat',
                fill: AppColors.ink,
                labelColor: AppColors.accent,
                loading: state.status == ChatStatus.extracting ||
                    state.status == ChatStatus.generatingPlan,
                onPressed: notifier.generatePlan,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: BrutalTextField(
                  label: 'Message',
                  controller: _inputController,
                  hint: 'Type a message…',
                ),
              ),
              const SizedBox(width: 10),
              _SendButton(
                loading: state.status == ChatStatus.sending,
                onPressed: () {
                  final text = _inputController.text;
                  if (text.trim().isEmpty) return;
                  _inputController.clear();
                  notifier.send(text);
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: Brutal.flat(fill: AppColors.primary),
          child: Text(message.content,
              style: AppText.body(13, weight: FontWeight.w600, color: Colors.white)),
        ),
      );
    }
    return _AiBubble(text: message.content);
  }
}

// tinjau dulu task/course usulan AI dari chat sblm bener2 disimpen ke task asli
class _TaskReviewPanel extends StatelessWidget {
  const _TaskReviewPanel({
    required this.candidates,
    required this.deselected,
    required this.onToggle,
    required this.onConfirm,
    required this.onSkip,
    required this.onCancel,
    required this.submitting,
  });

  final List<TaskCandidate> candidates;
  final Set<int> deselected;
  final ValueChanged<int> onToggle;
  final VoidCallback onConfirm;
  final VoidCallback onSkip;
  final VoidCallback onCancel;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final selectedCount = candidates.length - deselected.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: submitting ? null : onCancel,
          child: Text('← Back to chat',
              style: AppText.body(12, weight: FontWeight.w700, color: AppColors.inkMuted(0.6))),
        ),
        const SizedBox(height: 14),
        Text('I found these in our chat', style: AppText.display(16)),
        const SizedBox(height: 6),
        Text(
          "I'll add these to your tasks before building the schedule — uncheck anything "
          "that's not right.",
          style: AppText.body(12, color: AppColors.inkMuted(0.6)),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < candidates.length; i++) ...[
          _CandidateRow(
            candidate: candidates[i],
            selected: !deselected.contains(i),
            onTap: submitting ? () {} : () => onToggle(i),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        BrutalButton(
          label: selectedCount > 0 ? 'Add $selectedCount & generate plan' : 'Generate plan',
          fill: AppColors.ink,
          labelColor: AppColors.accent,
          loading: submitting,
          onPressed: onConfirm,
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: submitting ? null : onSkip,
            child: Text('Skip, just use existing tasks',
                style: AppText.body(12,
                    weight: FontWeight.w700, color: AppColors.inkMuted(0.6))),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                Text(candidate.title,
                    style: AppText.display(13.5, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${candidate.course} · ${candidate.type} · ${candidate.difficulty}',
                  style: AppText.body(11,
                      weight: FontWeight.w600, color: AppColors.inkMuted(0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: Brutal.box(fill: AppColors.primary, shadowOffset: 3),
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
      ),
    );
  }
}
