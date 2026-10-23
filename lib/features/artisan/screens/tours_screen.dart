import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/voice/voice_controller.dart';
import '../../../core/voice/voice_field.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../extras/extras_models.dart';
import '../extras/extras_repository.dart';
import '../extras/extras_widgets.dart';
import '../widgets/artisan_widgets.dart';

/// "Turlar": the artisan's master-classes / workshop visits with their
/// bookings, plus a create form.
class ToursScreen extends ConsumerStatefulWidget {
  const ToursScreen({super.key});

  @override
  ConsumerState<ToursScreen> createState() => _ToursScreenState();
}

class _ToursScreenState extends ConsumerState<ToursScreen> {
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final tours = ref.watch(experiencesProvider);
    return tours.when(
      skipLoadingOnRefresh: true,
      loading: () => const ExtrasLoading(header: 72, count: 2, height: 220),
      error: (e, _) => ErrorState(
        message: azError(e),
        artisan: true,
        retryLabel: 'Yenidən cəhd et',
        onRetry: () => ref.invalidate(experiencesProvider),
      ),
      data: (list) => RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () async {
          ref.invalidate(experiencesProvider);
          try {
            await ref.read(experiencesProvider.future);
          } catch (_) {
            // The error state is shown by the screen itself.
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ArtisanColumn(
            children: [
              Text('Turlar', style: AppText.aH1),
              const SizedBox(height: 6),
              Text(
                'Turistləri emalatxananıza dəvət edin.',
                style: AppText.aBody.copyWith(color: AppColors.ink2),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.slow),
                child: _creating
                    ? _TourForm(
                        key: const ValueKey('form'),
                        onClose: () => setState(() => _creating = false),
                      )
                    : AppButton(
                        key: const ValueKey('button'),
                        label: 'Yeni tur yarat',
                        icon: Icons.add_rounded,
                        size: BtnSize.xl,
                        onPressed: () => setState(() => _creating = true),
                      ),
              ),
              const SizedBox(height: 26),
              if (list.isEmpty) ...[
                if (!_creating)
                  const EmptyCard(
                    icon: Icons.groups_outlined,
                    title: 'Hələ turunuz yoxdur',
                    subtitle: 'Master-klass və ya səfər yaradın — turistlər yer sifariş edəcək.',
                  ),
              ] else ...[
                const SectionHeader(title: 'Turlarım', artisan: true),
                const SizedBox(height: 12),
                for (final e in list) ...[
                  _TourCard(key: ValueKey('tour-${e.id}'), experience: e),
                  const SizedBox(height: 14),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _typeLabel(Experience e) => e.isMasterclass ? 'Master-klass' : 'Emalatxanaya səfər';

String _hoursLabel(num h) => '${h == h.roundToDouble() ? h.round() : h} saat';

class _TourCard extends ConsumerStatefulWidget {
  const _TourCard({super.key, required this.experience});

  final Experience experience;

  @override
  ConsumerState<_TourCard> createState() => _TourCardState();
}

class _TourCardState extends ConsumerState<_TourCard> {
  bool _deleting = false;

  Experience get e => widget.experience;

  Future<void> _delete() async {
    final booked = e.bookings.length;
    final ok = await showConfirm(
      context,
      title: '«${e.title}» turunu silək?',
      message: booked > 0
          ? 'Bu turda $booked sifariş var. Qonaqlara xəbər verməyi unutmayın.'
          : 'Tur saytdan götürüləcək.',
      confirmLabel: 'Bəli, sil',
      cancelLabel: 'Xeyr',
      confirmVariant: BtnVariant.danger,
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.danger,
      iconBg: AppColors.dangerLight,
      artisan: true,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(extrasRepoProvider).deleteExperience(e.id);
      ref.invalidate(experiencesProvider);
      showToast('Tur silindi', kind: ToastKind.ok, large: true);
    } catch (err) {
      showToast(azError(err), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _deleting ? .5 : 1,
      duration: AppMotion.of(context, AppMotion.fast),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconCircle(
                  icon: e.isMasterclass ? Icons.back_hand_rounded : Icons.home_work_rounded,
                  bg: e.isMasterclass ? AppColors.goldLight : AppColors.brandLight,
                  fg: e.isMasterclass ? AppColors.goldInk : AppColors.brand,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBadge(
                        _typeLabel(e),
                        variant: e.isMasterclass ? BadgeVariant.gold : BadgeVariant.ready,
                        large: true,
                      ),
                      const SizedBox(height: 6),
                      Text(e.title, style: AppText.body(19, weight: FontWeight.w800, height: 1.25)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RoundIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Turu sil',
                  foreground: AppColors.danger,
                  background: AppColors.dangerLight,
                  size: 48,
                  onPressed: _deleting ? null : _delete,
                ),
              ],
            ),
            if (e.description != null) ...[
              const SizedBox(height: 10),
              Text(
                e.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(16.5, color: AppColors.ink2),
              ),
            ],
            const SizedBox(height: 10),
            if (e.price != null)
              InfoLine(
                icon: Icons.payments_rounded,
                text: '${formatAzn(e.price)} / 1 nəfər',
                color: AppColors.ink,
                size: 18,
                strong: true,
              ),
            if (e.hours != null)
              InfoLine(icon: Icons.schedule_rounded, text: _hoursLabel(e.hours!)),
            if (e.maxPeople != null)
              InfoLine(icon: Icons.group_rounded, text: 'Ən çox ${e.maxPeople} nəfər'),
            if (e.dates.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in e.dates)
                    AppChip(
                      label: azDate(d, withTime: false),
                      icon: Icons.event_rounded,
                      large: true,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            CardTitle(
              e.bookings.isEmpty
                  ? 'Sifarişlər'
                  : 'Sifarişlər · ${e.bookings.length} (${e.bookedPeople} nəfər)',
              icon: Icons.how_to_reg_rounded,
            ),
            const SizedBox(height: 8),
            if (e.bookings.isEmpty)
              Text('Hələ sifariş yoxdur.', style: AppText.aHint)
            else
              for (final b in e.bookings) ...[_BookingTile(booking: b), const SizedBox(height: 8)],
          ],
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(b.name, style: AppText.body(18, weight: FontWeight.w800)),
          const SizedBox(height: 2),
          InfoLine(icon: Icons.group_rounded, text: '${b.people} nəfər'),
          if (b.date != null)
            InfoLine(icon: Icons.event_rounded, text: azDate(b.date, withTime: false)),
          if (b.phone != null)
            ContactLine(icon: Icons.phone_rounded, text: b.phone!, url: 'tel:${b.phone}'),
          if (b.email != null)
            ContactLine(icon: Icons.email_rounded, text: b.email!, url: 'mailto:${b.email}'),
        ],
      ),
    );
  }
}

// ───────────────────────────── Create form ─────────────────────────────

class _TourForm extends ConsumerStatefulWidget {
  const _TourForm({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<_TourForm> createState() => _TourFormState();
}

class _TourFormState extends ConsumerState<_TourForm> {
  String _type = 'masterclass';
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  int _hours = 2;
  int _maxPeople = 6;
  final List<DateTime> _dates = [];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _addDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = _dates.isEmpty
        ? today.add(const Duration(days: 7))
        : _dates.last.add(const Duration(days: 1));
    final last = today.add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : initial,
      firstDate: today,
      lastDate: last,
      helpText: 'Tarixi seçin',
      confirmText: 'Seç',
      cancelText: 'Ləğv et',
    );
    if (picked == null) return;
    final d = DateUtils.dateOnly(picked);
    if (_dates.any((x) => DateUtils.isSameDay(x, d))) return;
    setState(
      () => _dates
        ..add(d)
        ..sort(),
    );
  }

  Future<void> _save() async {
    final price = parsePrice(_price.text);
    final error = _title.text.trim().isEmpty
        ? 'Başlığı yazın'
        : price == null
        ? 'Qiyməti yazın'
        : _dates.isEmpty
        ? 'Ən azı bir tarix əlavə edin'
        : null;
    if (error != null) {
      showToast(error, kind: ToastKind.error, large: true);
      return;
    }
    await ref.read(voiceProvider).stop();
    setState(() => _saving = true);
    try {
      await ref
          .read(extrasRepoProvider)
          .createExperience(
            type: _type,
            title: _title.text,
            description: _desc.text,
            price: price!,
            hours: _hours,
            maxPeople: _maxPeople,
            dates: _dates,
          );
      ref.invalidate(experiencesProvider);
      showToast('Tur yaradıldı — turistlər görəcək', kind: ToastKind.ok, large: true);
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
              Expanded(child: Text('Yeni tur', style: AppText.aH2)),
              RoundIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Bağla',
                size: 48,
                onPressed: _saving ? null : widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FieldLabel('Növü', artisan: true),
          ChoicePair<String>(
            options: const [
              ('masterclass', 'Master-klass', Icons.back_hand_rounded),
              ('visit', 'Emalatxanaya səfər', Icons.home_work_rounded),
            ],
            value: _type,
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 18),
          AppTextField(
            controller: _title,
            artisan: true,
            label: 'Başlıq',
            hint: 'Məsələn: Xalça toxuma dərsi',
            prefixIcon: Icons.title_rounded,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 18),
          VoiceTextField(
            controller: _desc,
            label: 'Təsvir',
            hint: 'Qonaqlar nə görəcək, nə edəcək?',
            minLines: 3,
          ),
          const SizedBox(height: 18),
          const FieldLabel('Qiymət (1 nəfər üçün)', artisan: true),
          PriceInput(controller: _price),
          const SizedBox(height: 18),
          const FieldLabel('Neçə saat çəkir?', artisan: true),
          UnitStepper(
            value: _hours,
            unit: 'saat',
            min: 1,
            max: 12,
            onChanged: (v) => setState(() => _hours = v),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Ən çox neçə nəfər?', artisan: true),
          UnitStepper(
            value: _maxPeople,
            unit: 'nəfər',
            min: 1,
            max: 50,
            onChanged: (v) => setState(() => _maxPeople = v),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Tarixlər', artisan: true),
          if (_dates.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in _dates)
                  RemovableChip(
                    label: azDate(d, withTime: false),
                    onRemove: () => setState(() => _dates.remove(d)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          AppButton(
            label: _dates.isEmpty ? 'Tarix əlavə et' : 'Daha bir tarix',
            icon: Icons.event_rounded,
            size: BtnSize.lg,
            variant: BtnVariant.soft,
            expand: true,
            onPressed: _saving ? null : _addDate,
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Turu yarat',
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
