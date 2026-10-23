import 'package:url_launcher/url_launcher.dart';

/// Opens an external URL (Stripe checkout, carrier tracking, tel:).
/// Returns false when nothing could handle it.
Future<bool> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
