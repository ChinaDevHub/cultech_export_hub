import 'package:flutter/material.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/inputs.dart';
import '../data/admin_models.dart';
import 'admin_format.dart';

/// Who reviews this request. Admins get a dropdown to (re)assign;
/// experts see a read-only line.
class CertRoutingBox extends StatelessWidget {
  const CertRoutingBox({
    super.key,
    required this.assigned,
    required this.experts,
    required this.canAssign,
    required this.busy,
    required this.onAssign,
  });

  final ExpertRef? assigned;
  final List<ExpertRef> experts;
  final bool canAssign;
  final bool busy;
  final ValueChanged<ExpertRef> onAssign;

  @override
  Widget build(BuildContext context) {
    if (canAssign && experts.isNotEmpty) {
      final current = experts.where((e) => e == assigned).firstOrNull;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSelect<ExpertRef>(
            label: 'Routed to expert',
            sheetTitle: 'Assign to expert',
            hint: assigned?.display ?? 'Not assigned yet',
            icon: busy ? Icons.hourglass_top_rounded : Icons.person_search_outlined,
            options: experts,
            value: current,
            labelOf: (e) => e.display,
            onChanged: (e) {
              if (!busy && e != assigned) onAssign(e);
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Requests are routed by craft. Reassign if another specialist fits better.',
            style: AppText.caption,
          ),
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_outlined, size: 20, color: AppColors.goldInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Routed to  ',
                    style: AppText.body(13, weight: FontWeight.w600, color: AppColors.goldInk),
                  ),
                  TextSpan(
                    text: assigned?.display ?? 'not assigned yet',
                    style: AppText.body(13.5, weight: FontWeight.w800, color: AppColors.goldInk),
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

/// Verification history (oldest first), as a compact timeline.
class CertHistoryList extends StatelessWidget {
  const CertHistoryList({super.key, required this.events});

  final List<CertEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verification history',
          style: AppText.body(12.5, weight: FontWeight.w800, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < events.length; i++)
          _HistoryRow(event: events[i], last: i == events.length - 1),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.event, required this.last});

  final CertEvent event;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final a = event.action.toLowerCase();
    final (icon, fg, bg) = switch (a) {
      _ when a.contains('approv') || a.contains('verif') || a.contains('issued') => (
        Icons.check_rounded,
        AppColors.ok,
        AppColors.okLight,
      ),
      _ when a.contains('reject') || a.contains('declin') => (
        Icons.close_rounded,
        AppColors.danger,
        AppColors.dangerLight,
      ),
      _ when a.contains('assign') || a.contains('rout') => (
        Icons.alt_route_rounded,
        AppColors.goldInk,
        AppColors.goldLight,
      ),
      _ => (Icons.history_rounded, AppColors.ink2, AppColors.soft2),
    };
    final who = [event.by, event.specialty].whereType<String>().join(' · ');
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 15, color: fg),
              ),
              if (!last) Expanded(child: Container(width: 2, color: AppColors.line)),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 12, top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: humanize(event.action),
                          style: AppText.body(13.5, weight: FontWeight.w800),
                        ),
                        if (who.isNotEmpty)
                          TextSpan(
                            text: '  ·  $who',
                            style: AppText.body(13, color: AppColors.ink2),
                          ),
                      ],
                    ),
                  ),
                  if (event.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('“${event.note!.trim()}”', style: AppText.bodyS),
                    ),
                  if (event.at != null) Text(shortDateTime(event.at!), style: AppText.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
