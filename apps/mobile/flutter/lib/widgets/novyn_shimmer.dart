import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class NovynShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const NovynShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: baseColor ?? (isDark ? const Color(0xFF1A1D2B) : const Color(0xFFE2E5F0)),
      highlightColor: highlightColor ?? (isDark ? const Color(0xFF2A2D3B) : const Color(0xFFF1F5F9)),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  static Widget chatItem() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          NovynShimmer(width: 54, height: 54, borderRadius: 27),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NovynShimmer(width: 120, height: 16, borderRadius: 4),
                SizedBox(height: 8),
                NovynShimmer(width: 200, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget friendCard() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          NovynShimmer(width: 50, height: 50, borderRadius: 25),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NovynShimmer(width: 100, height: 16, borderRadius: 4),
                SizedBox(height: 6),
                NovynShimmer(width: 80, height: 12, borderRadius: 4),
              ],
            ),
          ),
          NovynShimmer(width: 38, height: 38, borderRadius: 12),
        ],
      ),
    );
  }

  static Widget callItem() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          NovynShimmer(width: 54, height: 54, borderRadius: 27),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NovynShimmer(width: 140, height: 15, borderRadius: 4),
                SizedBox(height: 8),
                NovynShimmer(width: 100, height: 12, borderRadius: 4),
              ],
            ),
          ),
          NovynShimmer(width: 36, height: 36, borderRadius: 18),
        ],
      ),
    );
  }

  static Widget discoverItem() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          NovynShimmer(width: 54, height: 54, borderRadius: 27),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NovynShimmer(width: 130, height: 16, borderRadius: 4),
                SizedBox(height: 6),
                NovynShimmer(width: 90, height: 12, borderRadius: 4),
                SizedBox(height: 6),
                NovynShimmer(width: 180, height: 10, borderRadius: 4),
              ],
            ),
          ),
          NovynShimmer(width: 70, height: 34, borderRadius: 12),
        ],
      ),
    );
  }
}
