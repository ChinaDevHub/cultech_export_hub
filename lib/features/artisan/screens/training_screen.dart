import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/voice/voice_controller.dart';
import '../../../core/voice/voice_field.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import '../extras/built_in_lessons.dart';
import '../extras/extras_models.dart';
import '../extras/extras_repository.dart';
import '../extras/extras_widgets.dart';
import '../widgets/artisan_widgets.dart';

/// "Təlim": short how-to lessons and the artisan's apprentice programmes.
class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final training = ref.watch(trainingProvider);
    if (training.isLoading && !training.hasValue && !training.hasError) {
      return const ExtrasLoading(count: 4, height: 92);
    }
    final data = training.value;
    // Built-in lessons stay readable even when the API is unreachable.
    final lessons = (data == null || data.lessons.isEmpty) ? builtInLessons : data.lessons;
    final programmes = data?.programmes ?? const <Programme>[];

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: () async {
        ref.invalidate(trainingProvider);
        try {
          await ref.read(trainingProvider.future);
        } catch (_) {}
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ArtisanColumn(
          children: [
            Text('Təlim', style: AppText.aH1),
            const SizedBox(height: 6),
            Text(
              'Qısa dərslər — daha yaxşı satış üçün.',
              style: AppText.aBody.copyWith(color: AppColors.ink2),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < lessons.length; i++) ...[
              _LessonCard(
                key: ValueKey('lesson-${lessons[i].key}-$i'),
                lesson: lessons[i],
                tint: lessonTints[i % lessonTints.length],
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 26),
            const SectionHeader(title: 'Şagird proqramlarım', artisan: true),
            const SizedBox(height: 6),
            Text('Sənətinizi gənclərə öyrədin.', style: AppText.aHint),
            const SizedBox(height: 14),
            if (training.hasError && data == null)
              AppCard(
                child: ErrorState(
                  message: azError(training.error!),
                  artisan: true,
                  retryLabel: 'Yenidən cəhd et',
                  onRetry: () => ref.invalidate(trainingProvider),
                ),
              )
            else ...[
              AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.slow),
                child: _creating
                    ? _CourseForm(
                        key: const ValueKey('form'),
                        onClose: () => setState(() => _creating = false),
                      )
                    : AppButton(
                        key: const ValueKey('button'),
                        label: 'Yeni proqram yarat',
                        icon: Icons.add_rounded,
                        size: BtnSize.xl,
                        onPressed: () => setState(() => _creating = true),
                      ),
              ),
              const SizedBox(height: 16),
              if (programmes.isEmpty && !_creating)
                const EmptyCard(
                  icon: Icons.school_outlined,
                  title: 'Hələ proqramınız yoxdur',
                  subtitle: 'Proqram yaradın — gənclər müraciət edəcək.',
                )
              else
                for (final p in programmes) ...[
                  _ProgrammeCard(key: ValueKey('course-${p.id}'), programme: p),
                  const SizedBox(height: 14),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Lessons ─────────────────────────────

class _LessonCard extends StatefulWidget {
  const _LessonCard({super.key, required this.lesson, required this.tint});

  final Lesson lesson;
  final (Color, Color) tint;

  @override
  State<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<_LessonCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    final (bg, fg) = widget.tint;
    return AppCard(
      padding: EdgeInsets.zero,
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      IconCircle(icon: lessonIcon(l), bg: bg, fg: fg),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          l.title,
                          style: AppText.body(19, weight: FontWeight.w800, height: 1.25),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? .5 : 0,
                        duration: AppMotion.of(context, AppMotion.base),
                        child: const Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.ink2,
                          size: 34,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.of(context, AppMotion.slow),
            curve: AppMotion.curve,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (l.image != null) ...[
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: NetImage(l.image, radius: AppRadii.image),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (l.intro != null) ...[
                          Text(l.intro!, style: AppText.aBody.copyWith(color: AppColors.ink2)),
                          const SizedBox(height: 12),
                        ],
                        for (var i = 0; i < l.steps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                NumberBadge(i + 1, size: 34, color: fg),
                                const SizedBox(width: 12),
                                Expanded(child: Text(l.steps[i], style: AppText.aBody)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Programmes ─────────────────────────────

class _ProgrammeCard extends StatelessWidget {
  const _ProgrammeCard({super.key, required this.programme});

  final Programme programme;

  @override
  Widget build(BuildContext context) {
    final p = programme;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconCircle(
                icon: Icons.school_rounded,
                bg: AppColors.conceptBg,
                fg: AppColors.concept,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: AppText.body(19, weight: FontWeight.w800, height: 1.25)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppBadge(
                          p.free ? 'Pulsuz' : 'Ödənişli',
                          variant: p.free ? BadgeVariant.ok : BadgeVariant.gold,
                          large: true,
                        ),
                        if (p.weeks != null)
                          AppBadge(
                            '${p.weeks} həftə',
                            icon: Icons.calendar_month_rounded,
                            large: true,
                          ),
                        if (p.seats != null)
                          AppBadge('${p.seats} yer', icon: Icons.event_seat_rounded, large: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (p.description != null) ...[
            const SizedBox(height: 10),
            Text(
              p.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(16.5, color: AppColors.ink2),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          CardTitle(
            p.applicants.isEmpty ? 'Müraciətlər' : 'Müraciətlər · ${p.applicants.length}',
            icon: Icons.how_to_reg_rounded,
          ),
          const SizedBox(height: 8),
          if (p.applicants.isEmpty)
            Text('Hələ müraciət yoxdur.', style: AppText.aHint)
          else
            for (final a in p.applicants) ...[
              _ApplicantTile(applicant: a),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _ApplicantTile extends StatelessWidget {
  const _ApplicantTile({required this.applicant});

  final Applicant applicant;

  @override
  Widget build(BuildContext context) {
    final a = applicant;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: a.name,
                  style: AppText.body(18, weight: FontWeight.w800),
                ),
                if (a.age != null)
                  TextSpan(
                    text: '  ·  ${a.age} yaş',
                    style: AppText.body(16.5, weight: FontWeight.w600, color: AppColors.ink2),
                  ),
              ],
            ),
          ),
          if (a.phone != null)
            ContactLine(icon: Icons.phone_rounded, text: a.phone!, url: 'tel:${a.phone}'),
          if (a.message != null) ...[
            const SizedBox(height: 4),
            Text(
              '«${a.message}»',
              style: AppText.body(
                16.5,
                color: AppColors.ink2,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (a.at != null) ...[
            const SizedBox(height: 4),
            Text(azDate(a.at), style: AppText.body(14, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

class _CourseForm extends ConsumerStatefulWidget {
  const _CourseForm({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_CourseForm> createState() => _CourseFormState();
}

class _CourseFormState extends ConsumerState<_CourseForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  int _weeks = 8;
  int _seats = 5;
  bool _free = true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showToast('Proqramın adını yazın', kind: ToastKind.error, large: true);
      return;
    }
    await ref.read(voiceProvider).stop();
    setState(() => _saving = true);
    try {
      await ref
          .read(extrasRepoProvider)
          .createCourse(
            title: _title.text,
            description: _desc.text,
            weeks: _weeks,
            seats: _seats,
            free: _free,
          );
      ref.invalidate(trainingProvider);
      showToast('Proqram yaradıldı', kind: ToastKind.ok, large: true);
      widget.onClose();
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Yeni proqram', style: AppText.aH2)),
              RoundIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Bağla',
                size: 48,
                onPressed: _saving ? null : widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _title,
            artisan: true,
            label: 'Başlıq',
            hint: 'Məsələn: Gənclər üçün xalçaçılıq',
            prefixIcon: Icons.title_rounded,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 18),
          VoiceTextField(
            controller: _desc,
            label: 'Təsvir',
            hint: 'Nə öyrədəcəksiniz? Kimlər üçündür?',
            minLines: 3,
          ),
          const SizedBox(height: 18),
          const FieldLabel('Neçə həftə?', artisan: true),
          UnitStepper(
            value: _weeks,
            unit: 'həftə',
            min: 1,
            max: 52,
            onChanged: (v) => setState(() => _weeks = v),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Neçə şagird?', artisan: true),
          UnitStepper(
            value: _seats,
            unit: 'yer',
            min: 1,
            max: 30,
            onChanged: (v) => setState(() => _seats = v),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Ödəniş', artisan: true),
          ChoicePair<bool>(
            options: const [
              (true, 'Pulsuz', Icons.volunteer_activism_rounded),
              (false, 'Ödənişli', Icons.payments_rounded),
            ],
            value: _free,
            onChanged: (v) => setState(() => _free = v),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Proqramı yarat',
            icon: Icons.check_rounded,
            size: BtnSize.xl,
            variant: BtnVariant.ok,
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
