import 'dart:async';
import 'package:flutter/material.dart';

class BannerCarousel extends StatefulWidget {
  final List<String>? assetPaths;          // Explicit asset list
  final String? assetFolder;               // Auto-discover folder: assets/ads
  final int maxAutoDiscover;
  final Duration autoScrollDuration;
  final double borderRadius;

  const BannerCarousel({
    super.key,
    this.assetPaths,
    this.assetFolder,
    this.maxAutoDiscover = 10,
    this.autoScrollDuration = const Duration(seconds: 5),
    this.borderRadius = 20,
  });

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _pageController = PageController();
  Timer? _timer;
  List<String> _images = [];
  int _current = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    if (widget.assetPaths != null && widget.assetPaths!.isNotEmpty) {
      _images = widget.assetPaths!;
    } else if (widget.assetFolder != null) {
      final folder = widget.assetFolder!.replaceAll('/', '');
      for (int i = 1; i <= widget.maxAutoDiscover; i++) {
        final jpg = '${widget.assetFolder!}/ad$i.jpg';
        final png = '${widget.assetFolder!}/ad$i.png';

        try {
          await precacheImage(AssetImage(jpg), context);
          _images.add(jpg);
        } catch (_) {
          try {
            await precacheImage(AssetImage(png), context);
            _images.add(png);
          } catch (_) {}
        }
      }
    }

    setState(() => _loading = false);

    if (_images.length > 1) {
      _timer = Timer.periodic(widget.autoScrollDuration, (_) {
        if (!mounted) return;
        final next = (_current + 1) % _images.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: _loading
              ? Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          )
              : _images.isEmpty
              ? Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Text(
                "No Ads Available",
                style: TextStyle(
                  color: Colors.black54,
                  fontFamily: "Poppins",
                ),
              ),
            ),
          )
              : Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: _images.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, index) {
                  return Image.asset(
                    _images[index],
                    fit: BoxFit.cover,
                  );
                },
              ),

              // indicator
              Positioned(
                bottom: 10,
                right: 12,
                child: Row(
                  children: List.generate(_images.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _current == i ? 16 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _current == i
                            ? Colors.white
                            : Colors.white54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
