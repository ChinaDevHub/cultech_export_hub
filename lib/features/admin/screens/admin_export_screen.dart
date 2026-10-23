import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_format.dart';
import '../widgets/admin_page.dart';

/// One downloadable marketplace feed.
class _Feed {
  const _Feed({
    required this.format,
    required this.title,
    required this.summary,
    required this.contents,
    required this.icon,
    required this.fileName,
    required this.mime,
  });

  final String format;
  final String title;
  final String summary;
  final String contents;
  final IconData icon;
  final String fileName;
  final String mime;
}

const _feeds = [
  _Feed(
    format: 'etsy',
    title: 'Etsy',
    summary: 'CSV for Etsy listing upload',
    contents:
        'One row per listing: title, English description, price, quantity, tags, '
        'materials and photo links.',
    icon: Icons.storefront_outlined,
    fileName: 'cultech-etsy.csv',
    mime: 'text/csv',
  ),
  _Feed(
    format: 'shopify',
    title: 'Shopify',
    summary: 'CSV in the Shopify product import format',
    contents:
        'Handle, title, description, vendor (artisan), product type (craft), tags, '
        'price and image URLs.',
    icon: Icons.shopping_bag_outlined,
    fileName: 'cultech-shopify.csv',
    mime: 'text/csv',
  ),
  _Feed(
    format: 'amazon',
    title: 'Amazon Handmade',
    summary: 'CSV inventory file for Amazon',
    contents: 'SKU, title, key features, description, price, quantity and main image.',
    icon: Icons.local_mall_outlined,
    fileName: 'cultech-amazon.csv',
    mime: 'text/csv',
  ),
  _Feed(
    format: 'json',
    title: 'JSON',
    summary: 'The full catalogue for integrations',
    contents: 'Products, AI variants, artisans and heritage certificates as structured JSON.',
    icon: Icons.data_object_rounded,
    fileName: 'cultech-catalog.json',
    mime: 'application/json',
  ),
];

/// Catalogue exports for other marketplaces (admin only).
class AdminExportScreen extends ConsumerWidget {
  const AdminExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(authProvider).isAdmin;
    return AdminPage(
      title: 'Export',
      subtitle: 'Download the catalogue for other marketplaces.',
      children: [
        if (!isAdmin)
          const AdminOnlyState()
        else ...[
          AdaptiveGrid(
            minItemWidth: 280,
            maxColumns: 2,
            children: [for (final f in _feeds) _FeedCard(feed: f)],
          ),
          const SizedBox(height: 16),
          const NoteCard(
            icon: Icons.info_outline_rounded,
            child: Text(
              'Files are generated from the live catalogue when you download them. '
              'Prices are exported as stored (AZN) unless the marketplace format says otherwise.',
            ),
          ),
        ],
      ],
    );
  }
}

class _FeedCard extends ConsumerStatefulWidget {
  const _FeedCard({required this.feed});

  final _Feed feed;

  @override
  ConsumerState<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends ConsumerState<_FeedCard> {
  bool _busy = false;

  Future<void> _download() async {
    final f = widget.feed;
    setState(() => _busy = true);
    final repo = ref.read(adminRepoProvider);
    try {
      final bytes = await repo.export(f.format);
      final saved = await saveBytes(f.fileName, bytes, mime: f.mime);
      showToast(
        saved ? 'Saved ${f.fileName}' : 'Download cancelled',
        kind: saved ? ToastKind.ok : ToastKind.info,
      );
    } catch (e) {
      showToast(adminError(e), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.feed;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(f.icon, color: AppColors.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.title, style: AppText.display(19, weight: FontWeight.w700)),
                    Text(f.summary, style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(f.contents, style: AppText.bodyS),
          const SizedBox(height: 16),
          AppButton(
            label: 'Download ${f.fileName.split('.').last.toUpperCase()}',
            icon: Icons.file_download_outlined,
            variant: BtnVariant.outline,
            loading: _busy,
            onPressed: _busy ? null : _download,
          ),
        ],
      ),
    );
  }
}
