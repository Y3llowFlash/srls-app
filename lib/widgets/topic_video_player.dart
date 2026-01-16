import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';

class TopicVideoPlayer extends StatefulWidget {
  final String? videoUrl; // youtube link OR storage path like "videos/..../file.mp4"

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

  bool _showControls = true;

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
    // YOUTUBE (http links)
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
    // FIREBASE STORAGE (path)
    // -----------------------------
    try {
      final ref = FirebaseStorage.instance.ref(raw);
      final downloadUrl = await ref.getDownloadURL();

      _videoController = VideoPlayerController.networkUrl(Uri.parse(downloadUrl));
      await _videoController!.initialize();

      // update UI as position changes (for timeline/time labels)
      _videoController!.addListener(() {
        if (!mounted) return;
        setState(() {});
      });

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
    _videoController?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '${two(hours)}:${two(minutes)}:${two(seconds)}';
    return '${two(minutes)}:${two(seconds)}';
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
    // YOUTUBE
    // -----------------------------
    if (_ytController != null) {
      return YoutubePlayer(
        controller: _ytController!,
        showVideoProgressIndicator: true,
        aspectRatio: 16 / 9,
      );
    }

    // -----------------------------
    // STORAGE VIDEO (with timeline)
    // -----------------------------
    final vc = _videoController;
    if (vc == null) return const SizedBox.shrink();

    final isPlaying = vc.value.isPlaying;
    final position = vc.value.position;
    final duration = vc.value.duration;

    return AspectRatio(
      aspectRatio: vc.value.aspectRatio == 0 ? (16 / 9) : vc.value.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: VideoPlayer(vc),
            ),

            // Big play button (center)
            if (_showControls)
              Center(
                child: IconButton(
                  iconSize: 64,
                  icon: Icon(
                    isPlaying ? Icons.pause_circle : Icons.play_circle,
                  ),
                  onPressed: () async {
                    if (isPlaying) {
                      await vc.pause();
                    } else {
                      await vc.play();
                    }
                    if (mounted) setState(() {});
                  },
                ),
              ),

            // Bottom controls: time + scrub bar
            if (_showControls)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.0),
                        Colors.black.withOpacity(0.65),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Scrubbable progress bar (built-in!)
                      VideoProgressIndicator(
                        vc,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      Row(
                        children: [
                          Text(
                            _fmt(position),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            _fmt(duration),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
