import 'package:flutter/material.dart';

/// Shared Novyn app icon used on splash and authentication surfaces.
class NovynBrandMark extends StatelessWidget {
  final double size;
  const NovynBrandMark({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: Image.asset(
          'assets/icons/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: 'Novyn',
        ),
      );
}
