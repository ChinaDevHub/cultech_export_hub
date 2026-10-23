import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// Vertical order stepper driven by the API's `steps` / `stepIndex` /
/// `history` (never hard-coded statuses).
class OrderStepper extends StatelessWidget {
  const OrderStepper({
    super.key,
    required this.steps,
    required this.stepIndex,
    this.history = const [],
    this.locale = 'en',
    this.large = false,
  });

  final List<OrderStep> steps;
  final int stepIndex;
  final List<OrderEvent> history;
  final String locale;
  final bool large;

  DateTime? _timeFor(OrderStep s) {
    for (final h in history.reversed) {
      if (h.status == s.key) return h.at;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM, HH:mm', locale);
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            label: steps[i].label,
            time: _timeFor(steps[i]) == null ? null : fmt.format(_timeFor(steps[i])!),
            state: i < stepIndex
                ? _StepState.done
                : i == stepIndex
                ? _StepState.current
                : _StepState.todo,
            isLast: i == steps.length - 1,
            lineDone: i < stepIndex,
            large: large,
          ),
      ],
    );
  }
}

enum _StepState { done, current, todo }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.time,
    required this.state,
    required this.isLast,
    required this.lineDone,
    required this.large,
  });

  final String label;
  final String? time;
  final _StepState state;
  final bool isLast;
  final bool lineDone;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final dot = large ? 30.0 : 26.0;
    Widget circle;
    switch (state) {
      case _StepState.done:
        circle = Container(
          width: dot,
          height: dot,
          decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, color: AppColors.white, size: dot * .62),
        );
      case _StepState.current:
        circle = Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.brand, width: 3),
            boxShadow: const [BoxShadow(color: AppColors.brandLight, spreadRadius: 5)],
          ),
          child: Center(
            child: Container(
              width: dot * .32,
              height: dot * .32,
              decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
            ),
          ),
        );
      case _StepState.todo:
        circle = Container(
          width: dot,
          height: dot,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.line2, width: 2),
          ),
        );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: dot + 12,
            child: Column(
              children: [
                circle,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: lineDone ? AppColors.brand : AppColors.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.body(
                      large ? 18 : 15.5,
                      weight: state == _StepState.todo ? FontWeight.w600 : FontWeight.w800,
                      color: state == _StepState.todo ? AppColors.muted : AppColors.ink,
                    ),
                  ),
                  if (time != null) ...[
                    const SizedBox(height: 2),
                    Text(time!, style: AppText.caption),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin segmented progress bar (artisan order cards).
class SegmentProgress extends StatelessWidget {
  const SegmentProgress({super.key, required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i <= done ? AppColors.brand : AppColors.soft2,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          if (i < total - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}
