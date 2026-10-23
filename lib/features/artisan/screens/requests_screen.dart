import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/chat.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import '../extras/extras_models.dart';
import '../extras/extras_repository.dart';
import '../extras/extras_widgets.dart';
import '../widgets/artisan_widgets.dart';

/// "Sorğular": buyers' custom-order requests. Each card expands to show what
/// the buyer wants (in Azerbaijani), the message thread and the quote form.
class ArtisanRequestsScreen extends ConsumerWidget {
  const ArtisanRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(artisanRequestsProvider);
    return requests.when(
      skipLoadingOnRefresh: true,
      loading: () => const ExtrasLoading(count: 3, height: 130),
      error: (e, _) => ErrorState(
        message: azError(e),
        artisan: true,
        retryLabel: 'Yenidən cəhd et',
        onRetry: () => ref.invalidate(artisanRequestsProvider),
      ),
      data: (list) {
        final open = list.where((r) => r.isOpen).length;
        return RefreshIndicator(
          color: AppColors.brand,
          onRefresh: () async {
            ref.invalidate(artisanRequestsProvider);
            try {
              await ref.read(artisanRequestsProvider.future);
            } catch (_) {
              // The error state is shown by the screen itself.
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ArtisanColumn(
              children: [
                Text('Sorğular', style: AppText.aH1),
                const SizedBox(height: 6),
                Text(
                  open > 0
                      ? '$open yeni sorğu cavab gözləyir.'
                      : 'Alıcılar xüsusi sifariş istəyəndə burada görünür.',
                  style: AppText.aBody.copyWith(color: AppColors.ink2),
                ),
                const SizedBox(height: 18),
                if (list.isEmpty)
                  const EmptyCard(
                    icon: Icons.mark_email_unread_outlined,
                    title: 'Hələ sorğu yoxdur',
                    subtitle: 'Alıcı xüsusi sifariş istəyəndə burada görəcəksiniz.',
                  )
                else
                  for (final r in list) ...[
                    _RequestCard(
                      key: ValueKey('req-${r.id}'),
                      request: r,
                      initiallyExpanded: list.length == 1,
                    ),
                    const SizedBox(height: 14),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Outgoing {
  _Outgoing(this.text);

  final String text;
  final DateTime at = DateTime.now();
  bool sent = false;
  bool failed = false;
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({super.key, required this.request, this.initiallyExpanded = false});

  final CustomRequest request;
  final bool initiallyExpanded;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  late bool _expanded = widget.initiallyExpanded;
  final _price = TextEditingController();
  final _note = TextEditingController();
  late int _days = widget.request.quote?.leadDays ?? 14;
  final List<_Outgoing> _outgoing = [];
  bool _sending = false;
  String? _busy;

  CustomRequest get r => widget.request;

  @override
  void didUpdateWidget(_RequestCard old) {
    super.didUpdateWidget(old);
    // Fresh data arrived: delivered messages are now part of the thread.
    if (!identical(old.request, widget.request)) _outgoing.removeWhere((o) => o.sent);
  }

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final out = _Outgoing(text.trim());
    setState(() {
      _outgoing.add(out);
      _sending = true;
    });
    await _deliver(out);
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _deliver(_Outgoing out) async {
    try {
      await ref.read(extrasRepoProvider).sendMessage(r.id, out.text);
      out
        ..sent = true
        ..failed = false;
      ref.invalidate(artisanRequestsProvider);
    } catch (e) {
      out.failed = true;
      showToast(azError(e), kind: ToastKind.error, large: true);
    }
    if (mounted) setState(() {});
  }

  Future<void> _retry(_Outgoing out) async {
    setState(() => out.failed = false);
    await _deliver(out);
  }

  Future<void> _quote() async {
    final price = parsePrice(_price.text);
    if (price == null) {
      showToast('Qiymətinizi yazın', kind: ToastKind.error, large: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = 'quote');
    try {
      await ref
          .read(extrasRepoProvider)
          .quote(r.id, price: price, leadDays: _days, note: _note.text);
      ref.invalidate(artisanRequestsProvider);
      showToast('Təklifiniz alıcıya göndərildi', kind: ToastKind.ok, large: true);
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _decline() async {
    final ok = await showConfirm(
      context,
      title: 'Bu sifarişi edə bilmirsiniz?',
      message: 'Alıcıya nəzakətlə bildirəcəyik.',
      confirmLabel: 'Bəli, edə bilmirəm',
      cancelLabel: 'Xeyr, geri',
      confirmVariant: BtnVariant.danger,
      icon: Icons.block_rounded,
      artisan: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = 'decline');
    try {
      await ref.read(extrasRepoProvider).decline(r.id);
      ref.invalidate(artisanRequestsProvider);
      showToast('Alıcıya bildirildi', kind: ToastKind.ok, large: true);
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          AnimatedSize(
            duration: AppMotion.of(context, AppMotion.slow),
            curve: AppMotion.curve,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 18), child: _body())
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final who = [r.buyerFirstName, r.country].whereType<String>().join(' · ');
    final preview = r.summary.isNotEmpty
        ? r.summary.first
        : r.details.map((d) => '${d.$1}: ${d.$2}').join(', ');
    return Semantics(
      button: true,
      expanded: _expanded,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.card),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ArtisanThumb(image: r.productImage, size: 76),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.productName ?? 'Xüsusi sifariş',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(19, weight: FontWeight.w800, height: 1.25),
                          ),
                          if (who.isNotEmpty) InfoLine(icon: Icons.person_rounded, text: who),
                          const SizedBox(height: 6),
                          _StatusBadge(r.status),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!_expanded && preview.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(16.5, color: AppColors.ink2),
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: ExpandHint(expanded: _expanded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WantsBlock(request: r),
        if (r.quote != null && !r.isOpen) ...[const SizedBox(height: 14), _quoteSent()],
        if (r.status == RequestStatus.declined) ...[
          const SizedBox(height: 14),
          InfoLine(
            icon: Icons.block_rounded,
            text: 'Bu sorğudan imtina etdiniz.',
            color: AppColors.muted,
            size: 17,
          ),
        ],
        const SizedBox(height: 20),
        const CardTitle('Yazışma', icon: Icons.forum_rounded),
        const SizedBox(height: 8),
        ..._thread(),
        if (r.status != RequestStatus.declined) ...[
          const SizedBox(height: 10),
          ChatComposer(large: true, hint: 'Mesaj yazın…', sending: _sending, onSend: _send),
          const SizedBox(height: 6),
          Text('Mesajınız alıcının dilinə tərcümə olunur.', style: AppText.aHint),
        ],
        if (r.isOpen) ...[const SizedBox(height: 22), _quoteForm()],
      ],
    );
  }

  List<Widget> _thread() {
    if (r.messages.isEmpty && _outgoing.isEmpty) {
      return [Text('Hələ mesaj yoxdur.', style: AppText.aHint)];
    }
    return [
      for (final m in r.messages)
        ChatBubble(
          text: m.text,
          mine: m.mine,
          large: true,
          author: m.mine ? null : r.buyerFirstName,
          time: m.at == null ? null : azDate(m.at),
          note: m.translated ? 'Tərcümə olunub' : null,
        ),
      for (final o in _outgoing)
        GestureDetector(
          onTap: o.failed ? () => _retry(o) : null,
          child: Opacity(
            opacity: o.sent ? 1 : .7,
            child: ChatBubble(
              text: o.text,
              mine: true,
              large: true,
              time: azDate(o.at),
              note: o.failed
                  ? 'Göndərilmədi — yenidən cəhd üçün basın'
                  : (o.sent ? null : 'Göndərilir…'),
            ),
          ),
        ),
    ];
  }

  Widget _quoteSent() {
    final q = r.quote!;
    final parts = [
      if (q.price != null) formatAzn(q.price),
      if (q.leadDays != null) '${q.leadDays} gün',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: r.status == RequestStatus.accepted ? AppColors.okLight : AppColors.warnLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.status == RequestStatus.accepted ? 'Alıcı təklifinizi qəbul etdi' : 'Təklifiniz',
            style: AppText.aLabel,
          ),
          const SizedBox(height: 4),
          Text(parts, style: AppText.display(26, weight: FontWeight.w800)),
          if (q.note != null) ...[
            const SizedBox(height: 4),
            Text(q.note!, style: AppText.body(16.5, color: AppColors.ink2)),
          ],
          if (r.status == RequestStatus.quoted) ...[
            const SizedBox(height: 6),
            Text('Alıcının cavabını gözləyirik.', style: AppText.aHint),
          ],
        ],
      ),
    );
  }

  Widget _quoteForm() {
    final busy = _busy != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Təklifiniz', style: AppText.aH2),
          const SizedBox(height: 14),
          const FieldLabel('Qiymətiniz', artisan: true),
          PriceInput(controller: _price),
          const SizedBox(height: 6),
          Text('Bu məbləği tam siz alırsınız.', style: AppText.aHint),
          const SizedBox(height: 18),
          const FieldLabel('Neçə günə hazır olar?', artisan: true),
          DaysStepper(value: _days, onChanged: (v) => setState(() => _days = v)),
          const SizedBox(height: 18),
          AppTextField(
            controller: _note,
            artisan: true,
            label: 'Qeyd (istəyə görə)',
            hint: 'Məsələn: rəngi bir az fərqli ola bilər',
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Təklif ver',
            icon: Icons.send_rounded,
            size: BtnSize.xl,
            loading: _busy == 'quote',
            onPressed: busy ? null : _quote,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Edə bilmirəm',
            icon: Icons.close_rounded,
            size: BtnSize.xl,
            variant: BtnVariant.outline,
            loading: _busy == 'decline',
            onPressed: busy ? null : _decline,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, variant, icon) = switch (status) {
      RequestStatus.open => ('Yeni', BadgeVariant.accent, Icons.mark_email_unread_rounded),
      RequestStatus.quoted => ('Təklif göndərilib', BadgeVariant.pending, Icons.schedule_rounded),
      RequestStatus.accepted => ('Qəbul edilib', BadgeVariant.ok, Icons.check_circle_rounded),
      RequestStatus.declined => ('İmtina', BadgeVariant.neutral, Icons.block_rounded),
    };
    return AppBadge(label, variant: variant, icon: icon, large: true);
  }
}

/// "What the buyer wants": Azerbaijani summary, details, notes, sample image.
class _WantsBlock extends StatelessWidget {
  const _WantsBlock({required this.request});

  final CustomRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final hasText = r.summary.isNotEmpty || r.details.isNotEmpty || r.notes != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_rounded, color: AppColors.brand, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Alıcı nə istəyir',
                  style: AppText.body(18.5, weight: FontWeight.w800, color: AppColors.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasText) Text('Ətraflı məlumat yoxdur — alıcıya yazın.', style: AppText.aBody),
          for (final line in r.summary)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: AppText.aBodyStrong),
                  Expanded(child: Text(line, style: AppText.aBody)),
                ],
              ),
            ),
          for (final (label, value) in r.details)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: AppText.body(17.5, weight: FontWeight.w600, color: AppColors.ink2),
                    ),
                    TextSpan(
                      text: value,
                      style: AppText.body(18, weight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          if (r.notes != null) ...[
            const SizedBox(height: 6),
            Text('Qeyd:', style: AppText.aLabel),
            Text(r.notes!, style: AppText.aBody),
          ],
          if (r.sampleImage != null) ...[
            const SizedBox(height: 12),
            Text('Nümunə şəkil', style: AppText.aLabel),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: NetImage(r.sampleImage, radius: AppRadii.image),
            ),
          ],
        ],
      ),
    );
  }
}
