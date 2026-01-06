import 'package:flutter/material.dart';

class WorkoutBannerCarousel extends StatefulWidget {
  const WorkoutBannerCarousel({Key? key}) : super(key: key);

  @override
  State<WorkoutBannerCarousel> createState() => _WorkoutBannerCarouselState();
}

class _WorkoutBannerCarouselState extends State<WorkoutBannerCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.88);
  int _currentPage = 0;

  final List<Map<String, String>> banners = [
    {
      "title": "Build Strength",
      "subtitle": "Try full-body workouts today",
    },
    {
      "title": "Lose Fat Faster",
      "subtitle": "Burn calories with HIIT routines",
    },
    {
      "title": "Gain Muscle",
      "subtitle": "Follow expert-approved plans",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final banner = banners[index];
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double value = 1.0;

                  if (_controller.position.haveDimensions) {
                    value = (_controller.page! - index).abs();
                    value = (1 - (value * 0.2)).clamp(0.8, 1.0);
                  }

                  return Transform.scale(
                    scale: value,
                    child: _bannerCard(
                      title: banner["title"]!,
                      subtitle: banner["subtitle"]!,
                    ),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Page Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(banners.length, (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: isActive ? 22 : 8,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.withOpacity(0.85)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }),
        ),
      ],
    );
  }

  // PREMIUM GRADIENT BANNER CARD
  Widget _bannerCard({
    required String title,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(right: 12, left: 4, top: 8, bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade400.withOpacity(0.9),
              Colors.blue.shade400.withOpacity(0.95),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 12,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
