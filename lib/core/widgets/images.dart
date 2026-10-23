import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../mock/mock_media.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'skeleton.dart';

/// Backend image (raster or SVG) with skeleton placeholder and error state.
class NetImage extends StatelessWidget {
  const NetImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.radius,
    this.semanticLabel,
    this.width,
    this.height,
  });

  final String? path;
  final BoxFit fit;
  final double? radius;
  final String? semanticLabel;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final url = mediaUrl(path);
    Widget child;
    if (AppConfig.useMock && MockMedia.handles(path)) {
      child = _MockImage(
        path!,
        fit: fit,
        width: width,
        height: height,
        semanticLabel: semanticLabel,
      );
    } else if (url == null) {
      child = const _ImageFallback();
    } else if (isSvgPath(path)) {
      child = Container(
        color: AppColors.soft2,
        child: SvgPicture.network(
          url,
          fit: fit,
          width: width,
          height: height,
          semanticsLabel: semanticLabel,
          placeholderBuilder: (_) => const Skeleton(),
          errorBuilder: (_, _, _) => const _ImageFallback(),
        ),
      );
    } else {
      child = CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: width,
        height: height,
        fadeInDuration: AppMotion.of(context, AppMotion.slow),
        placeholder: (_, _) => const Skeleton(),
        errorWidget: (_, _, _) => const _ImageFallback(),
      );
      if (semanticLabel != null) {
        child = Semantics(image: true, label: semanticLabel, child: child);
      }
    }
    child = SizedBox(width: width, height: height, child: child);
    if (radius == null) return child;
    return ClipRRect(borderRadius: BorderRadius.circular(radius!), child: child);
  }
}

/// Offline art: drawn-in-code SVGs (`/seed/…`, `/demo/…`) and files the user
/// picked while the mock backend is active (`/uploads/…`, kept in memory).
class _MockImage extends StatelessWidget {
  const _MockImage(this.path, {required this.fit, this.width, this.height, this.semanticLabel});

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (MockMedia.isUpload(path)) {
      final bytes = MockMedia.uploadBytes(path)!;
      final type = MockMedia.uploadType(path) ?? '';
      if (type.contains('svg')) {
        return SvgPicture.memory(bytes, fit: fit, width: width, height: height);
      }
      return Image.memory(
        bytes,
        fit: fit,
        width: width,
        height: height,
        semanticLabel: semanticLabel,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _ImageFallback(),
      );
    }
    return Container(
      color: AppColors.soft2,
      child: SvgPicture.string(
        MockMedia.svg(path),
        fit: fit,
        width: width,
        height: height,
        semanticsLabel: semanticLabel,
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.soft2,
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, c) => Icon(
          Icons.image_outlined,
          color: AppColors.line2,
          size: (c.biggest.shortestSide * .3).clamp(16, 56).toDouble(),
        ),
      ),
    );
  }
}

/// A locally picked image (works on mobile and web via bytes).
class PickedImage extends StatefulWidget {
  const PickedImage(this.file, {super.key, this.fit = BoxFit.cover});

  final XFile file;
  final BoxFit fit;

  @override
  State<PickedImage> createState() => _PickedImageState();
}

class _PickedImageState extends State<PickedImage> {
  late Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  void didUpdateWidget(PickedImage old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) _bytes = widget.file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snap) {
        if (!snap.hasData) return const Skeleton();
        return Image.memory(snap.data!, fit: widget.fit, gaplessPlayback: true);
      },
    );
  }
}

/// Circle avatar: network image or initials on the artisan's colour.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, required this.name, this.image, this.color, this.size = 40});

  final String name;
  final String? image;
  final String? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final bg = color != null
        ? AppColors.fromHex(color)
        : AppColors.avatarFallbacks[name.hashCode.abs() % AppColors.avatarFallbacks.length];
    return Semantics(
      label: name,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: size >= 96 ? Border.all(color: AppColors.white, width: 4) : null,
          boxShadow: size >= 96 ? AppShadows.raised : null,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: image != null && image!.isNotEmpty
            ? NetImage(image, width: size, height: size)
            : Text(
                initials.isEmpty ? '?' : initials,
                style: AppText.display(
                  size * .38,
                  weight: FontWeight.w700,
                  color: AppColors.white,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
