import 'package:flutter/material.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/badges.dart';
import '../../admin/widgets/admin_format.dart';
import '../../admin/widgets/admin_page.dart';
import '../../admin/widgets/admin_thumb.dart';
import '../data/ministry_models.dart';

/// Ranked "most-requested versions": a table on wide panels, a list on
/// phones. Lives inside a panel, so it draws no card of its own.
class VersionsTable extends StatelessWidget {
  const VersionsTable({super.key, required this.rows, required this.craftLabel});

  final List<VersionRow> rows;
  final String Function(String) craftLabel;

  @override
  Widget build(BuildContext context) {
    final hasOrders = rows.any((r) => r.orders != null);
    final hasPrice = rows.any((r) => r.priceAZN != null);
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 720) {
          return Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _VersionListRow(rank: i + 1, row: rows[i], craftLabel: craftLabel),
              ],
            ],
          );
        }
        final cols = [
          const TableCol('#', width: 28),
          const TableCol('Version', flex: 4),
          const TableCol('Craft', flex: 2),
          const TableCol('Artisan', flex: 2),
          const TableCol('Requests', width: 84, end: true),
          if (hasOrders) const TableCol('Orders', width: 70, end: true),
          if (hasPrice) const TableCol('Price', width: 110, end: true),
        ];
        final header = AppText.body(
          11.5,
          weight: FontWeight.w800,
          color: AppColors.muted,
          letterSpacing: .6,
        );
        return Column(
          children: [
            TableCells(
              cols: cols,
              cells: [for (final col in cols) Text(col.label.toUpperCase(), style: header)],
            ),
            for (var i = 0; i < rows.length; i++) ...[
              const Divider(height: 22),
              TableCells(
                cols: cols,
                cells: [
                  Text('${i + 1}', style: AppText.body(14, weight: FontWeight.w800)),
                  _VersionCell(row: rows[i]),
                  _muted(rows[i].craft == null ? null : craftLabel(rows[i].craft!)),
                  _muted(rows[i].artisan),
                  WantsLabel(formatCount(rows[i].requests)),
                  if (hasOrders)
                    Text(
                      rows[i].orders == null ? '—' : formatCount(rows[i].orders!),
                      style: AppText.body(14, weight: FontWeight.w700),
                    ),
                  if (hasPrice)
                    Text(
                      rows[i].priceAZN == null ? '—' : formatAzn(rows[i].priceAZN),
                      style: AppText.price(14),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  static Widget _muted(String? s) => Text(
    s ?? '—',
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: AppText.body(13.5, color: AppColors.ink2),
  );
}

class _VersionCell extends StatelessWidget {
  const _VersionCell({required this.row});

  final VersionRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AdminThumb(image: row.image, concept: row.concept, size: 44, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(14.5, weight: FontWeight.w700),
              ),
              if (row.base != null && row.base != row.title)
                Text(
                  'of ${row.base}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VersionListRow extends StatelessWidget {
  const _VersionListRow({required this.rank, required this.row, required this.craftLabel});

  final int rank;
  final VersionRow row;
  final String Function(String) craftLabel;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (row.craft != null) craftLabel(row.craft!),
      row.artisan,
      if (row.priceAZN != null) formatAzn(row.priceAZN),
    ].whereType<String>().join(' · ');
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text('$rank', style: AppText.body(14, weight: FontWeight.w800)),
        ),
        AdminThumb(image: row.image, concept: row.concept, size: 44, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(14.5, weight: FontWeight.w700),
              ),
              if (meta.isNotEmpty)
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
            ],
          ),
        ),
        const SizedBox(width: 8),
        WantsLabel(formatCount(row.requests)),
      ],
    );
  }
}
