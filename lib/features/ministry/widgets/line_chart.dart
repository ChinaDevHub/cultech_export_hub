import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../admin/data/admin_models.dart';
import '../../admin/widgets/admin_format.dart';

/// Time-series line chart: y gridlines with labels, first / middle / last
/// date on the x axis, teal line with a soft fill and a dot on the latest
/// value. Painted directly — no chart package.
class LineChart extends StatelessWidget {
  const LineChart({
    super.key,
    required this.points,
    required this.formatValue,
    this.height = 220,
    this.color = AppColors.brand,
  });

  final List<SeriesPoint> points;

  /// Full value text (semantics / latest value), e.g. `1.240 AZN`.
  final String Function(double) formatValue;
  final double height;
  final Color color;

  static String labelOf(SeriesPoint p, int i) =>
      p.date != null ? shortDate(p.date!) : (p.label ?? '${i + 1}');

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text('No data for this period', style: AppText.caption)),
      );
    }
    final last = points.last;
    return Semantics(
      label:
          '${points.length} days, from ${labelOf(points.first, 0)} to '
          '${labelOf(last, points.length - 1)}. Latest: ${formatValue(last.value)}.',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _LinePainter(
            points: points,
            color: color,
            labelStyle: AppText.body(11, weight: FontWeight.w600, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.points, required this.color, required this.labelStyle});

  final List<SeriesPoint> points;
  final Color color;
  final TextStyle labelStyle;

  static const _ticks = 4;
  static final _compact = NumberFormat.compact(locale: 'en_US');

  /// 1, 2, 2.5, 5 × 10ⁿ ≥ [v].
  static double _niceCeil(double v) {
    if (v <= 0) return 1;
    final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (v <= m * exp) return m * exp;
    }
    return 10 * exp;
  }

  TextPainter _text(String s) => TextPainter(
    text: TextSpan(text: s, style: labelStyle),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = _niceCeil(points.fold<double>(0, (m, p) => math.max(m, p.value)));
    final yLabels = [for (var i = 0; i <= _ticks; i++) _text(_compact.format(maxV * i / _ticks))];
    final left = yLabels.fold<double>(0, (m, t) => math.max(m, t.width)) + 10;
    const top = 10.0, right = 10.0, bottom = 24.0;
    final chart = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    if (chart.width <= 0 || chart.height <= 0) return;

    // Gridlines + y labels.
    final grid = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= _ticks; i++) {
      final y = chart.bottom - chart.height * i / _ticks;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      final t = yLabels[i];
      t.paint(canvas, Offset(left - 10 - t.width, y - t.height / 2));
    }

    // Points.
    final n = points.length;
    Offset at(int i) {
      final x = n == 1 ? chart.center.dx : chart.left + chart.width * i / (n - 1);
      final y = chart.bottom - chart.height * (points[i].value / maxV).clamp(0, 1);
      return Offset(x, y);
    }

    final line = Path();
    for (var i = 0; i < n; i++) {
      final p = at(i);
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
      }
    }

    // Soft fill under the line.
    if (n > 1) {
      final fill = Path.from(line)
        ..lineTo(at(n - 1).dx, chart.bottom)
        ..lineTo(at(0).dx, chart.bottom)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
          ).createShader(chart),
      );
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Latest value dot.
    final lastP = at(n - 1);
    canvas.drawCircle(lastP, 6, Paint()..color = AppColors.white);
    canvas.drawCircle(lastP, 4.5, Paint()..color = color);

    // X labels: first, middle, last (clamped inside the chart).
    final xs = n == 1 ? [0] : (n == 2 ? [0, 1] : [0, n ~/ 2, n - 1]);
    for (final i in xs) {
      final t = _text(LineChart.labelOf(points[i], i));
      final x = math.max(chart.left, math.min(at(i).dx - t.width / 2, chart.right - t.width));
      t.paint(canvas, Offset(x, chart.bottom + 7));
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.color != color || old.labelStyle != labelStyle;
}
