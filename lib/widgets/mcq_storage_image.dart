import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class McqStorageImage extends StatefulWidget {
  final String path;
  final double height;

  const McqStorageImage({
    super.key,
    required this.path,
    this.height = 180,
  });

  @override
  State<McqStorageImage> createState() => _McqStorageImageState();
}

class _McqStorageImageState extends State<McqStorageImage> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await FirebaseStorage.instance.ref(widget.path).getDownloadURL();
      if (!mounted) return;
      setState(() {
        _url = url;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _url = null;
        _loading = false;
      });
    }
  }

  void _zoom() {
    final url = _url;
    if (url == null) return;

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          minScale: 0.7,
          maxScale: 4,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }
    if (_url == null) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(12)),
        child: const Text('Image unavailable'),
      );
    }

    return InkWell(
      onTap: _zoom,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _url!,
          height: widget.height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: widget.height,
            alignment: Alignment.center,
            child: const Text('Image unavailable'),
          ),
        ),
      ),
    );
  }
}
