import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';

/// Scrollable admin page: soft background, 1200 px content column, a
/// Fraunces title, optional actions and pull-to-refresh.
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.children,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 28, bottom: 56),
      children: [
        _full(_PageHeader(title: title, subtitle: subtitle, actions: actions)),
        const SizedBox(height: 24),
        for (final c in children) _full(c),
      ],
    );
    return ColoredBox(
      color: AppColors.soft,
      child: onRefresh == null
          ? list
          : RefreshIndicator(
              color: AppColors.brand,
              onRefresh: () async {
                try {
                  await onRefresh!();
                } catch (_) {
                  // The page's own error state shows the failure.
                }
              },
              child: list,
            ),
    );
  }
}

/// Content column, full width up to 1200 px (left-aligned children).
Widget _full(Widget child) => ContentWidth(
  child: SizedBox(width: double.infinity, child: child),
);

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, this.subtitle, required this.actions});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 640;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.display(wide ? 32 : 26, weight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: AppText.bodyS),
            ],
          ],
        );
        if (actions.isEmpty) return text;
        final actionWrap = Wrap(spacing: 8, runSpacing: 8, children: actions);
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 14), actionWrap],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: text),
            const SizedBox(width: 16),
            actionWrap,
          ],
        );
      },
    );
  }
}

/// White card with a small heading — one dashboard block.
class AdminPanel extends StatelessWidget {
  const AdminPanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.display(19, weight: FontWeight.w700)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppText.caption),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Wraps children into as many equal columns as fit [minItemWidth].
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 280,
    this.maxColumns = 3,
    this.spacing = 16,
    this.balance = false,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;

  /// Prefer a column count that leaves no lonely tiles on the last row.
  final bool balance;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final fit = ((c.maxWidth + spacing) / (minItemWidth + spacing)).floor();
        var cols = math.max(1, math.min(math.min(fit, maxColumns), children.length));
        if (balance && children.length % cols != 0) {
          for (var k = cols - 1; k >= (cols / 2).ceil() && k > 1; k--) {
            if (children.length % k == 0) {
              cols = k;
              break;
            }
          }
        }
        final w = ((c.maxWidth - spacing * (cols - 1)) / cols).floorToDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: w, child: child)],
        );
      },
    );
  }
}

/// Column spec for [AdminTable] / [TableCells].
class TableCol {
  const TableCol(this.label, {this.flex = 1, this.width, this.end = false});

  final String label;
  final int flex;

  /// Fixed width instead of [flex].
  final double? width;

  /// Right-align (numbers).
  final bool end;
}

/// One table row laid out by [cols].
class TableCells extends StatelessWidget {
  const TableCells({super.key, required this.cols, required this.cells});

  final List<TableCol> cols;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < cols.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          _cell(cols[i], i < cells.length ? cells[i] : const SizedBox.shrink()),
        ],
      ],
    );
  }

  Widget _cell(TableCol col, Widget child) {
    final aligned = Align(
      alignment: col.end ? Alignment.centerRight : Alignment.centerLeft,
      child: child,
    );
    if (col.width != null) return SizedBox(width: col.width, child: aligned);
    return Expanded(flex: col.flex, child: aligned);
  }
}

/// A table in one card: muted header, divider-separated rows.
class AdminTable extends StatelessWidget {
  const AdminTable({super.key, required this.cols, required this.rows});

  final List<TableCol> cols;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: TableCells(
              cols: cols,
              cells: [
                for (final c in cols)
                  Text(
                    c.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      11.5,
                      weight: FontWeight.w800,
                      color: AppColors.muted,
                      letterSpacing: .6,
                    ),
                  ),
              ],
            ),
          ),
          for (final r in rows) ...[const Divider(), r],
        ],
      ),
    );
  }
}

/// Search box used above admin lists.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({super.key, required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppText.body(15, weight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted, size: 21),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: _border(AppColors.line2),
        enabledBorder: _border(AppColors.line2),
        focusedBorder: _border(AppColors.brand),
      ),
    );
  }

  static OutlineInputBorder _border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.pill),
    borderSide: BorderSide(color: c, width: 1.5),
  );
}

/// Search + optional filter on one line (wraps on phones).
class AdminToolbar extends StatelessWidget {
  const AdminToolbar({super.key, required this.search, this.filter});

  final Widget search;
  final Widget? filter;

  @override
  Widget build(BuildContext context) {
    if (filter == null) return search;
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 680) {
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              filter!,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [search, const SizedBox(height: 10), filter!],
        );
      },
    );
  }
}

/// Muted "N items" line under toolbars.
class CountLine extends StatelessWidget {
  const CountLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
    child: Text(
      text,
      style: AppText.body(13, weight: FontWeight.w700, color: AppColors.muted),
    ),
  );
}

/// Shown on admin-only pages when a heritage expert opens them directly.
class AdminOnlyState extends StatelessWidget {
  const AdminOnlyState({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
    title: 'Admins only',
    subtitle: 'Ask an administrator if you need access to this section.',
    icon: Icons.lock_outline_rounded,
  );
}
