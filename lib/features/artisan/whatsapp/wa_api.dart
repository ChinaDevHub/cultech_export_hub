import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import 'wa_models.dart';

/// The WhatsApp bot simulator endpoints.
class WhatsAppApi {
  WhatsAppApi(this._api);

  final ApiClient _api;

  /// Sends one artisan message to the bot; returns the bot's replies.
  Future<List<WaMessage>> simulate({
    required String phone,
    required String text,
    List<XFile> images = const [],
  }) async {
    final form = FormData();
    form.fields
      ..add(MapEntry('phone', phone))
      ..add(MapEntry('text', text));
    for (final img in images.take(4)) {
      form.files.add(MapEntry('images', await ApiClient.imageFile(img)));
    }
    return WaMessage.repliesFrom(await _api.post('/whatsapp/simulate', form));
  }

  /// System notifications sent to [phone] after [after] (ISO time).
  Future<OutboxPage> outbox({required String phone, String? after}) async => OutboxPage.fromAny(
    await _api.get('/whatsapp/outbox', query: {'phone': phone, 'after': after}),
  );
}

final whatsAppApiProvider = Provider<WhatsAppApi>((ref) => WhatsAppApi(ref.watch(apiProvider)));
