import 'package:flutter/material.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../data/artisan_models.dart';
import 'artisan_widgets.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.item});

  final ArtisanNotification item;

  IconData get _icon {
    final t = '${item.type ?? ''} ${item.text}'.toLowerCase();
    if (t.contains('satıl') || t.contains('sold')) return Icons.celebration_rounded;
    if (t.contains('sifariş') || t.contains('order')) return Icons.shopping_bag_rounded;
    if (t.contains('sertifikat') || t.contains('cert') || t.contains('ekspert')) {
      return Icons.verified_rounded;
    }
    if (t.contains('istəyir') || t.contains('want')) return Icons.favorite_rounded;
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.read ? null : 'Oxunmamış',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.read ? AppColors.soft2 : AppColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: item.read ? AppColors.ink2 : AppColors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: AppText.body(
                      17,
                      weight: item.read ? FontWeight.w500 : FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                  if (item.at != null) ...[
                    const SizedBox(height: 2),
                    Text(azDate(item.at), style: AppText.body(14, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            if (!item.read)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 8),
                width: 12,
                height: 12,
                decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
