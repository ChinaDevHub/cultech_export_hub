import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import 'extras_models.dart';

/// Short Azerbaijani lessons shown when the API sends none.
const builtInLessons = [
  Lesson(
    key: 'photo',
    title: 'Şəkil necə çəkilir',
    steps: [
      'Gün işığında, pəncərənin yanında çəkin.',
      'Arxa fon sadə olsun — ağ divar və ya düz parça.',
      'Məhsulu 4 tərəfdən çəkin: öndən, arxadan, yandan və yaxından.',
      'Telefonu sabit tutun ki, şəkil bulanıq olmasın.',
    ],
  ),
  Lesson(
    key: 'voice',
    title: 'Səslə danışmaq',
    steps: [
      'Mikrofon düyməsini basın və sakit danışın.',
      'Nədən hazırlandığını deyin: yun, ipək, mis, ağac…',
      'Ölçüsünü və neçə günə hazırladığınızı deyin.',
      'Naxışın mənasını danışın — alıcılar hekayəni sevir.',
    ],
  ),
  Lesson(
    key: 'price',
    title: 'Qiyməti necə qoymalı',
    steps: [
      'Materialın pulunu və sərf etdiyiniz vaxtı hesablayın.',
      'Süni intellektin tövsiyə etdiyi aralığa baxın.',
      'Qiymətinizi tam siz alırsınız — xidmət haqqını alıcı ödəyir.',
      'Çox ucuz satmayın — əməyiniz dəyərlidir.',
    ],
  ),
  Lesson(
    key: 'variants',
    title: 'Başqa versiyalar',
    steps: [
      'Süni intellekt başqa rəng və ölçülər təklif edir.',
      'Yalnız bacardığınız versiyaları qəbul edin.',
      'Hər versiya üçün qiymət və gün sayını yazın.',
      'Alıcı sifariş verəndə hazırlamağa başlayırsınız.',
    ],
  ),
  Lesson(
    key: 'packing',
    title: 'Qablaşdırma',
    steps: [
      'Məhsulu təmiz kağıza və ya parçaya bükün.',
      'Kövrək əşyaları qalın karton qutuya qoyun.',
      'Boşluqları kağızla doldurun ki, içində tərpənməsin.',
      'Təhvil kodunu qutunun üstünə iri hərflərlə yazın.',
    ],
  ),
  Lesson(
    key: 'chat',
    title: 'Alıcı ilə yazışma',
    steps: [
      'Azərbaycanca yazın — mesaj alıcının dilinə tərcümə olunur.',
      'Qısa və nəzakətli cavab verin.',
      'Bir gün ərzində cavab verməyə çalışın.',
      'Bilmədiyiniz sualı koordinatorunuzdan soruşun.',
    ],
  ),
];

/// Icon for a lesson, guessed from its key/title.
IconData lessonIcon(Lesson l) {
  final k = '${l.key} ${l.title}'.toLowerCase();
  bool has(List<String> words) => words.any(k.contains);
  if (has(['photo', 'şəkil', 'foto', 'camera'])) return Icons.photo_camera_rounded;
  if (has(['voice', 'səs', 'audio', 'mic', 'danış'])) return Icons.mic_rounded;
  if (has(['pric', 'qiymət'])) return Icons.sell_rounded;
  if (has(['variant', 'versiya'])) return Icons.auto_awesome;
  if (has(['pack', 'qablaş', 'box'])) return Icons.inventory_2_rounded;
  if (has(['chat', 'message', 'buyer', 'yazış', 'alıcı'])) return Icons.forum_rounded;
  if (has(['video'])) return Icons.videocam_rounded;
  return Icons.lightbulb_rounded;
}

/// Rotating tints so neighbouring lessons look different.
const lessonTints = [
  (AppColors.brandLight, AppColors.brand),
  (AppColors.goldLight, AppColors.goldInk),
  (AppColors.conceptBg, AppColors.concept),
  (AppColors.okLight, AppColors.ok),
  (AppColors.accentLight, AppColors.accent),
  (AppColors.warnLight, AppColors.warn),
];
