import 'package:flutter/material.dart';

class ShardPayBrandMark extends StatelessWidget {
  static const _launcherAssetPath = 'android/app/src/main/res/mipmap-xxxhdpi/shardpay_launcher.png';

  const ShardPayBrandMark({
    super.key,
    this.size = 48,
    this.borderRadius,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(0),
  });

  final double size;
  final double? borderRadius;
  final Color? backgroundColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.28;

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(
          color: backgroundColor ?? Colors.transparent,
          child: Padding(
            padding: padding,
            child: Image.asset(
              _launcherAssetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
