import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class TopicVideoPlayer extends StatefulWidget {
  final String? videoUrl; // youtube link OR storage path like "videos/.../file.mp4"

  const TopicVideoPlayer({
    super.key,
    required this.videoUrl,
  });

  @override
  State<TopicVideoPlayer> createState() => _TopicVideoPlayerState();
}

class _TopicVideoPlayerState extends State<TopicVideoPlayer> {
  YoutubePlayerController? _ytController;

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final raw = widget.videoUrl?.trim() ?? '';

    if (raw.isEmpty) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }

    // -----------------------------
    // YOUTUBE
    // -----------------------------
    if (raw.startsWith('http')) {
      final id = YoutubePlayer.convertUrlToId(raw);
      if (id == null) {
        setState(() {
          _loading = false;
          _error = true;
        });
        return;
      }

      _ytController = YoutubePlayerController(
        initialVideoId: id,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          controlsVisibleAtStart: true,
        ),
      );

      setState(() => _loading = false);
      return;
    }

    // -----------------------------
    // FIREBASE STORAGE
    // -----------------------------
    try {
      final ref = FirebaseStorage.instance.ref(raw);
      final downloadUrl = await ref.getDownloadURL();

      _videoController = VideoPlayerController.networkUrl(Uri.parse(downloadUrl));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.redAccent,
          handleColor: Colors.redAccent,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
      );

      setState(() => _loading = false);
    } catch (_) {
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceVariant,
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Video is unavailable.\nPlease contact the course creator.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // YOUTUBE
    if (_ytController != null) {
      return YoutubePlayer(
        controller: _ytController!,
        showVideoProgressIndicator: true,
        aspectRatio: 16 / 9,
      );
    }

    // STORAGE (Chewie)
    if (_chewieController != null) {
      return AspectRatio(
        aspectRatio: _videoController?.value.aspectRatio == 0
            ? (16 / 9)
            : (_videoController!.value.aspectRatio),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Chewie(controller: _chewieController!),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
