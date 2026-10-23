import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../widgets/want_sheet.dart';
import 'phase2_models.dart';
import 'phase2_providers.dart';
import 'phase2_repository.dart';
import 'phase2_widgets.dart';

/// Booking sheet: date, guests, contact, live total → success with the id.
Future<void> showExperienceBookSheet(BuildContext context, Experience exp) =>
    showPhase2Sheet<void>(context, (_) => _BookSheet(exp: exp));

class _BookSheet extends ConsumerStatefulWidget {
  const _BookSheet({required this.exp});

  final Experience exp;

  @override
  ConsumerState<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends ConsumerState<_BookSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final _email = TextEditingController(text: ref.read(emailMemoryProvider));
  final _phone = TextEditingController();
  ExpDate? _date;
  int _people = 1;
  bool _sending = false;

  /// Set on success: (booking id or null, date, people).
  ({String? id, ExpDate date, int people})? _done;

  @override
  void initState() {
    super.initState();
    final open = widget.exp.upcoming.where((d) => !d.isFull);
    _date = open.firstOrNull;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  int get _maxPeople {
    final seats = _date?.seats;
    final cap = widget.exp.maxPeople;
    final limits = [?seats, ?cap].where((n) => n > 0);
    if (limits.isEmpty) return 20;
    return limits.reduce((a, b) => a < b ? a : b);
  }

  void _pickDate(ExpDate d) {
    setState(() {
      _date = d;
      _people = _people.clamp(1, _maxPeople);
    });
  }

  Future<void> _submit() async {
    final t = ref.read(tProvider);
    final valid = _form.currentState?.validate() ?? false;
    if (_date == null) {
      showToast(t('exp.pickDate'), kind: ToastKind.error);
      return;
    }
    if (!valid) return;
    setState(() => _sending = true);
    try {
      final id = await ref
          .read(phase2RepoProvider)
          .bookExperience(
            widget.exp.id,
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            date: _date!.value,
            people: _people,
          );
      ref.read(emailMemoryProvider.notifier).remember(_email.text);
      ref.invalidate(experiencesProvider);
      if (!mounted) return;
      setState(() => _done = (id: id, date: _date!, people: _people));
    } catch (e) {
      showToast(
        errorText(e, network: t('common.network'), fallback: t('common.error')),
        kind: ToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final done = _done;
    if (done != null) return _Success(exp: widget.exp, result: done);

    final money = ref.watch(moneyProvider);
    final config = ref.watch(configOrEmptyProvider);
    final exp = widget.exp;
    final dates = exp.upcoming;
    final subtotal = exp.priceAZN * _people;
    final fee = subtotal * config.serviceFeeRate;
    final total = subtotal + fee;

    String? required(String? v) => (v == null || v.trim().isEmpty) ? t('common.required') : null;

    return SheetBody(
      title: exp.title.of(lang),
      subtitle: [
        if (exp.artisan != null) exp.artisan!.name,
        ?exp.village,
        if (exp.durationH != null) t('exp.hours', {'n': formatNum(exp.durationH!, lang)}),
      ].join(' · '),
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FieldLabel(t('exp.date')),
              if (dates.isEmpty)
                NoteCard(
                  icon: Icons.event_busy_rounded,
                  child: Text(t('exp.noDates'), style: AppText.bodyS),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in dates)
                      _DateChip(
                        date: d,
                        selected: identical(d, _date),
                        onTap: d.isFull ? null : () => _pickDate(d),
                      ),
                  ],
                ),
              const SizedBox(height: 20),
              FieldLabel(t('exp.guests')),
              Row(
                children: [
                  QuantityStepper(
                    value: _people,
                    min: 1,
                    max: _maxPeople,
                    onChanged: (v) => setState(() => _people = v),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(t('exp.maxGuests', {'n': _maxPeople}), style: AppText.caption),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _name,
                label: t('co.name'),
                autofillHints: const [AutofillHints.name],
                textCapitalization: TextCapitalization.words,
                validator: required,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _email,
                label: t('co.email'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (v) => isValidEmail(v ?? '') ? null : t('common.invalidEmail'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _phone,
                label: t('exp.phone'),
                hint: '+49 151 2345 6789',
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]'))],
                validator: required,
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.soft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KeyValueRow(
                      label: t('exp.priceTimes', {'price': money(exp.priceAZN), 'n': _people}),
                      value: money(subtotal),
                    ),
                    KeyValueRow(
                      label: t('co.serviceFee', {'p': config.feePercent}),
                      value: money(fee),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider()),
                    KeyValueRow(label: t('co.total'), value: money(total), strong: true),
                    if (!money.isAzn)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text('≈ ${money.azn(total)}', style: AppText.caption),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(t('exp.payNote'), style: AppText.caption),
              const SizedBox(height: 18),
              AppButton(
                label: t('exp.confirm'),
                icon: Icons.event_available_rounded,
                size: BtnSize.lg,
                expand: true,
                loading: _sending,
                onPressed: dates.isEmpty ? null : _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateChip extends ConsumerWidget {
  const _DateChip({required this.date, required this.selected, required this.onTap});

  final ExpDate date;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final d = date;
    final full = d.isFull;
    final label = d.date == null ? d.value : formatDay(d.date!, lang);
    final seats = full
        ? t('exp.full')
        : (d.seats == null ? t('exp.open') : t('exp.seatsLeft', {'n': d.seats}));
    final fg = full ? AppColors.muted : (selected ? AppColors.brand : AppColors.ink);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !full,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          constraints: const BoxConstraints(minHeight: 56, minWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: full ? AppColors.soft : (selected ? AppColors.brandLight : AppColors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.line2,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppText.body(
                  14.5,
                  weight: FontWeight.w800,
                  color: fg,
                ).copyWith(decoration: full ? TextDecoration.lineThrough : null),
              ),
              Text(
                seats,
                style: AppText.body(
                  12,
                  weight: FontWeight.w700,
                  color: full
                      ? AppColors.danger
                      : (d.seats != null && d.seats! <= 3 ? AppColors.warn : AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Success extends ConsumerWidget {
  const _Success({required this.exp, required this.result});

  final Experience exp;
  final ({String? id, ExpDate date, int people}) result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final d = result.date;
    return SheetBody(
      icon: Icons.check_rounded,
      iconColor: AppColors.ok,
      iconBg: AppColors.okLight,
      title: t('exp.booked'),
      subtitle: t('exp.bookedSub'),
      children: [
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (result.id != null) ...[
                Text(t('exp.bookingId'), style: AppText.caption),
                const SizedBox(height: 4),
                SelectableText(result.id!, style: AppText.mono(20)),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 6),
              ],
              Text(exp.title.of(lang), style: AppText.body(16, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              KeyValueRow(
                label: t('exp.date'),
                value: d.date == null ? d.value : formatDay(d.date!, lang),
              ),
              KeyValueRow(label: t('exp.guests'), value: '${result.people}'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: t('common.close'),
          variant: BtnVariant.outline,
          size: BtnSize.lg,
          expand: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
