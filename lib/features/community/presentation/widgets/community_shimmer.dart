import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class CommunityShimmer extends StatelessWidget {
  const CommunityShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color baseColor = isDark ? Colors.grey[900]! : Colors.grey[300]!;
    Color highlightColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return ListView.builder(
      itemCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 20),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 20),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 120, height: 12, color: Colors.white),
                          const SizedBox(height: 6),
                          Container(width: 80, height: 8, color: Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 350,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 200, height: 10, color: Colors.white),
                      const SizedBox(height: 8),
                      Container(width: 150, height: 10, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color baseColor = isDark ? Colors.grey[900]! : Colors.grey[300]!;
    Color highlightColor = isDark ? Colors.grey[800]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(radius: 50),
            const SizedBox(height: 16),
            Container(width: 150, height: 20, color: Colors.white),
            const SizedBox(height: 8),
            Container(width: 100, height: 12, color: Colors.white),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) => Column(
                children: [
                  Container(width: 40, height: 20, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(width: 60, height: 10, color: Colors.white),
                ],
              )),
            ),
            const SizedBox(height: 32),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: 9,
              itemBuilder: (context, index) => Container(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
