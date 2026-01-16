import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';

class TopicVideoPlayer extends StatefulWidget {
  final String? videoUrl; // youtube link OR storage path

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
    // raw = "videos/courseId/moduleId/topicId.mp4"
    // -----------------------------
    try {
      final ref = FirebaseStorage.instance.ref(raw);
      final downloadUrl = await ref.getDownloadURL();

      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(downloadUrl),
      );

      await _videoController!.initialize();

      setState(() => _loading = false);
    } catch (e) {
      // permission denied / not found / private
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
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

    // -----------------------------
    // YOUTUBE PLAYER
    // -----------------------------
    if (_ytController != null) {
      return YoutubePlayer(
        controller: _ytController!,
        showVideoProgressIndicator: true,
        aspectRatio: 16 / 9,
      );
    }

    // -----------------------------
    // STORAGE VIDEO PLAYER
    // -----------------------------
    if (_videoController != null) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_videoController!),
            IconButton(
              iconSize: 56,
              icon: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause_circle
                    : Icons.play_circle,
              ),
              onPressed: () {
                setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                });
              },
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
