import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/catalog.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/skeleton.dart';

/// Artisan's video story with English subtitles. The API gives subtitle
/// lines without timings, so they are spread evenly over the duration.
class ProductVideoPlayer extends StatefulWidget {
  const ProductVideoPlayer({super.key, required this.video});

  final ProductVideo video;

  @override
  State<ProductVideoPlayer> createState() => _ProductVideoPlayerState();
}

class _ProductVideoPlayerState extends State<ProductVideoPlayer> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final url = mediaUrl(widget.video.url);
    if (url == null) {
      setState(() => _failed = true);
      return;
    }
    final video = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = video;
    try {
      await video.initialize();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    final lines = widget.video.subtitles;
    final total = video.value.duration;
    final cues = <Subtitle>[];
    if (lines.isNotEmpty && total > Duration.zero) {
      final slice = total ~/ lines.length;
      for (var i = 0; i < lines.length; i++) {
        cues.add(
          Subtitle(
            index: i,
            start: slice * i,
            end: i == lines.length - 1 ? total : slice * (i + 1),
            text: lines[i],
          ),
        );
      }
    }
    setState(() {
      _chewie = ChewieController(
        videoPlayerController: video,
        aspectRatio: video.value.aspectRatio == 0 ? 16 / 9 : video.value.aspectRatio,
        autoPlay: false,
        looping: false,
        showOptions: false,
        subtitle: cues.isEmpty ? null : Subtitles(cues),
        showSubtitles: cues.isNotEmpty,
        subtitleBuilder: (context, text) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$text',
            textAlign: TextAlign.center,
            style: AppText.body(15, weight: FontWeight.w600, color: AppColors.white),
          ),
        ),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.brand,
          handleColor: AppColors.brand,
          bufferedColor: AppColors.line2,
          backgroundColor: AppColors.soft2,
        ),
      );
    });
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_failed) {
      // Offline / unreachable: still show what the artisan says, as text.
      child = Container(
        color: AppColors.ink,
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: AppColors.white, size: 36),
              const SizedBox(height: 10),
              for (final line in widget.video.subtitles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '“$line”',
                    textAlign: TextAlign.center,
                    style: AppText.body(14.5, weight: FontWeight.w600, color: AppColors.white),
                  ),
                ),
            ],
          ),
        ),
      );
    } else if (_chewie == null) {
      child = const Skeleton();
    } else {
      child = Chewie(controller: _chewie!);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: AspectRatio(
        aspectRatio: _video?.value.isInitialized == true && _video!.value.aspectRatio > 0
            ? _video!.value.aspectRatio
            : 16 / 9,
        child: ColoredBox(color: AppColors.ink, child: child),
      ),
    );
  }
}
