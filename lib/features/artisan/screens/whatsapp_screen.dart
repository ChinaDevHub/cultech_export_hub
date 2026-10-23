import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/json.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/feedback.dart';
import '../../../router.dart';
import '../data/artisan_repository.dart';
import '../whatsapp/wa_api.dart';
import '../whatsapp/wa_models.dart';
import '../whatsapp/wa_widgets.dart';
import '../widgets/artisan_widgets.dart';

/// WhatsApp bot simulator: the artisan chats with the same bot that runs on
/// real WhatsApp (photo → text/voice → AI draft → variants).
class WhatsAppScreen extends ConsumerStatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  ConsumerState<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends ConsumerState<WhatsAppScreen> {
  static const _pollEvery = Duration(seconds: 4);
  static const _quickReplies = ['salam', '1', '2', 'Bəli', 'Xeyr', 'gəlir', 'sifariş'];
  static const _demoImageText = 'Bu vazanı Şəkidə hazırlamışam, 120 manat';
  static const _demoText =
      'Salam! Bu mis sinini Lahıcda öz əlimlə döymüşəm. Diametri 40 sm-dir. Qiyməti 90 manat.';

  final _messages = <WaMessage>[];
  final _pending = <XFile>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();

  bool _sending = false;

  /// Null until the user toggles it: open by default on tall screens only.
  bool? _introOpen;
  bool _editingPhone = false;
  String? _manualPhone;

  // Outbox polling.
  Timer? _timer;
  String? _pollPhone;
  String? _after;
  bool _baselined = false;
  bool _polling = false;
  final _seen = <String>{};

  /// Texts of bot replies already shown, so the same message arriving again
  /// through the outbox is not duplicated.
  final _recentReplies = <String>[];

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInput);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input
      ..removeListener(_onInput)
      ..dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onInput() => setState(() {});

  // ───────────────────────────── Phone ─────────────────────────────

  /// Logged-in artisan's phone, else the dashboard artisan's phone.
  ({String? phone, bool loading}) _resolvePhone() {
    if (_manualPhone != null) return (phone: _manualPhone, loading: false);
    final auth = ref.watch(authProvider);
    final actingFor = ref.watch(actAsProvider);
    final own = actingFor == null ? str(pick(auth.user ?? const {}, ['phone', 'tel'])) : null;
    if (own != null) return (phone: own, loading: false);
    final dash = ref.watch(dashboardProvider);
    final fromDash = dash.value == null
        ? null
        : str(pick(dash.value!.artisan.raw, ['phone', 'tel', 'whatsapp']));
    return (phone: fromDash, loading: dash.isLoading && fromDash == null);
  }

  void _ensurePolling(String? phone) {
    if (phone == _pollPhone) return;
    _timer?.cancel();
    _pollPhone = phone;
    _after = null;
    _baselined = false;
    _seen.clear();
    if (phone == null) return;
    _timer = Timer.periodic(_pollEvery, (_) => _poll());
    _poll();
  }

  Future<void> _poll() async {
    final phone = _pollPhone;
    // Skipped while a message is in flight so bot replies that also land in
    // the outbox are recognised as duplicates afterwards.
    if (_polling || _sending || phone == null || !mounted) return;
    _polling = true;
    try {
      final page = await ref.read(whatsAppApiProvider).outbox(phone: phone, after: _after);
      if (!mounted || phone != _pollPhone) return;
      final fresh = <WaMessage>[];
      for (final item in page.items) {
        if (!_seen.add(item.key)) continue;
        // The first answer is the history before this screen opened.
        if (!_baselined) continue;
        final i = _recentReplies.indexOf(item.message.text.trim());
        if (i >= 0) {
          _recentReplies.removeAt(i);
          continue;
        }
        fresh.add(item.message);
      }
      _after = page.cursor ?? _after;
      _baselined = true;
      if (fresh.isNotEmpty) {
        setState(() => _messages.addAll(fresh));
        _scrollToEnd();
      }
    } catch (_) {
      // Offline or not supported yet: keep polling quietly.
      if (!_baselined) {
        _baselined = true;
        _after ??= DateTime.now().toUtc().toIso8601String();
      }
    } finally {
      _polling = false;
    }
  }

  void _setPhone(String phone) {
    setState(() {
      _manualPhone = phone.trim();
      _editingPhone = false;
      _messages.clear();
      _pending.clear();
    });
  }

  // ───────────────────────────── Sending ─────────────────────────────

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      // The list is reversed: offset 0 is the newest message.
      _scroll.animateTo(
        0,
        duration: AppMotion.of(context, const Duration(milliseconds: 250)),
        curve: AppMotion.curve,
      );
    });
  }

  /// Sends [text]. [images] defaults to the attached (pending) images.
  Future<void> _send(String text, {List<XFile>? images}) async {
    final phone = _pollPhone;
    if (phone == null) {
      showToast('Əvvəlcə telefon nömrəsini yazın', kind: ToastKind.error, large: true);
      return;
    }
    if (_sending) return;
    final files = images ?? List<XFile>.of(_pending);
    final t = text.trim();
    if (t.isEmpty && files.isEmpty) return;

    final msg = WaMessage(
      id: WaMessage.nextId(),
      text: t,
      outgoing: true,
      at: DateTime.now(),
      files: files,
      status: WaStatus.sending,
    );
    setState(() {
      _messages.add(msg);
      _sending = true;
      _introOpen = false;
      if (images == null) _pending.clear();
    });
    _scrollToEnd();

    try {
      final replies = await ref
          .read(whatsAppApiProvider)
          .simulate(phone: phone, text: t, images: files);
      if (!mounted) return;
      _recentReplies.addAll(replies.map((r) => r.text.trim()).where((s) => s.isNotEmpty));
      if (_recentReplies.length > 30) {
        _recentReplies.removeRange(0, _recentReplies.length - 30);
      }
      setState(() {
        msg.status = WaStatus.sent;
        _messages.addAll(replies);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => msg.status = WaStatus.failed);
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _sendComposer() {
    final text = _input.text;
    if (text.trim().isEmpty && _pending.isEmpty) return;
    _input.clear();
    _send(text);
  }

  void _retry(WaMessage m) {
    setState(() => _messages.remove(m));
    _send(m.text, images: m.files);
  }

  Future<void> _attach() async {
    final room = 4 - _pending.length;
    if (room <= 0) {
      showToast('Ən çox 4 şəkil göndərmək olar', large: true);
      return;
    }
    final files = await pickImages(context, max: room);
    if (files.isNotEmpty && mounted) setState(() => _pending.addAll(files));
  }

  // ───────────────────────────── UI ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final resolved = _resolvePhone();
    final phone = resolved.phone;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensurePolling(phone);
    });

    return ArtisanPage(
      title: 'WhatsApp',
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.ustaMore),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
          final frame = _PhoneFrame(child: _frameContent(phone, resolved.loading));

          if (wide) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _intro(phone, collapsible: false),
                              const SizedBox(height: 16),
                              ..._demoButtons(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(width: 440, child: frame),
                    ],
                  ),
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!keyboard)
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: c.maxHeight * .42),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: _intro(phone, collapsible: true),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12, keyboard ? 4 : 10, 12, 12),
                      child: frame,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool get _introIsOpen => _introOpen ?? MediaQuery.sizeOf(context).height >= 760;

  Widget _intro(String? phone, {required bool collapsible}) => WaIntroCard(
    open: !collapsible || _introIsOpen,
    onToggle: collapsible ? () => setState(() => _introOpen = !_introIsOpen) : null,
    phone: phone,
    onChangePhone: _sending ? null : () => setState(() => _editingPhone = true),
  );

  List<Widget> _demoButtons() => [
    AppButton(
      label: 'Demo şəkil göndər',
      icon: Icons.image_rounded,
      size: BtnSize.xl,
      onPressed: _sending || _pollPhone == null ? null : () => _send(_demoImageText),
    ),
    const SizedBox(height: 10),
    AppButton(
      label: 'Demo mətn',
      icon: Icons.text_snippet_rounded,
      size: BtnSize.xl,
      variant: BtnVariant.outline,
      onPressed: _sending || _pollPhone == null ? null : () => _send(_demoText, images: const []),
    ),
  ];

  Widget _frameContent(String? phone, bool loading) {
    if (_editingPhone || (phone == null && !loading)) {
      return Column(
        children: [
          const WaHeaderBar(),
          Expanded(
            child: WaPhoneForm(
              initial: phone,
              onSubmit: _setPhone,
              onCancel: phone == null ? null : () => setState(() => _editingPhone = false),
            ),
          ),
        ],
      );
    }
    if (phone == null) {
      return const Column(
        children: [
          WaHeaderBar(),
          Expanded(
            child: Center(child: CircularProgressIndicator(color: AppColors.waHeader)),
          ),
        ],
      );
    }

    final quick = [
      WaQuickAction('Demo şəkil göndər', () => _send(_demoImageText), icon: Icons.image_rounded),
      WaQuickAction(
        'Demo mətn',
        () => _send(_demoText, images: const []),
        icon: Icons.text_snippet_rounded,
      ),
      for (final q in _quickReplies) WaQuickAction(q, () => _send(q, images: const [])),
    ];

    return Column(
      children: [
        const WaHeaderBar(),
        Expanded(child: _messages.isEmpty && !_sending ? _emptyChat() : _chatList()),
        if (_pending.isNotEmpty)
          WaPendingImages(files: _pending, onRemove: (i) => setState(() => _pending.removeAt(i))),
        WaQuickReplies(actions: quick, enabled: !_sending),
        WaComposer(
          controller: _input,
          sending: _sending,
          canSend: !_sending && (_input.text.trim().isNotEmpty || _pending.isNotEmpty),
          onSend: _sendComposer,
          onAttach: _attach,
        ),
      ],
    );
  }

  Widget _chatList() {
    // Reversed list: index 0 is the newest item at the bottom.
    final items = <Widget>[
      if (_sending) const WaTypingBubble(),
      for (final m in _messages.reversed)
        WaBubble(
          key: ValueKey(m.id),
          message: m,
          buttonsEnabled: !_sending,
          onButton: (b) => _send(b, images: const []),
          onRetry: _sending ? null : () => _retry(m),
        ),
      const WaDayChip(),
    ];
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }

  Widget _emptyChat() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WaDayChip(),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.goldLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Məhsulunuzun şəklini göndərin və ya «salam» yazın. '
                'Sınamaq üçün aşağıdakı demo düymələrindən birini basın.',
                textAlign: TextAlign.center,
                style: AppText.body(16, weight: FontWeight.w600, color: AppColors.goldInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded "phone" with WhatsApp wallpaper.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.raised,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: ColoredBox(color: AppColors.waWallpaper, child: child),
      ),
    );
  }
}
