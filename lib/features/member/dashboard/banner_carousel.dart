// lib/features/member/banner/banner_carousel.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BannerCarousel extends StatelessWidget {
  final List<String> assetPaths;
  final Duration autoScrollDuration;
  final double borderRadius;

  const BannerCarousel({
    Key? key,
    required this.assetPaths,
    required this.autoScrollDuration,
    required this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This is a simple implementation. You can expand it with actual carousel logic
    return SizedBox(
      height: 140,
      child: PageView.builder(
        itemCount: assetPaths.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              image: DecorationImage(
                image: AssetImage(assetPaths[index]),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }
}

class NoticeBanner extends StatelessWidget {
  final Map<String, dynamic> notice;
  final Color primaryGreen;
  final Color primaryBlue;

  const NoticeBanner({
    Key? key,
    required this.notice,
    required this.primaryGreen,
    required this.primaryBlue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: notice['isImportant'] == true
              ? [Colors.orange, Colors.deepOrange]
              : [primaryGreen, primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  notice['title'],
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (notice['isImportant'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'IMPORTANT',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              notice['message'],
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM dd, yyyy').format(notice['date']),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}