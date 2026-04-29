import 'package:flutter/material.dart';

/// A small, premium avatar widget that consistently renders either a network
/// image or initials with the existing color-scheme. Used across the social
/// feature for friend/contact/request rows.
class AvatarCircle extends StatelessWidget {
  final String? imageUrl;
  final String label;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AvatarCircle({
    super.key,
    required this.label,
    this.imageUrl,
    this.size = 44,
    this.backgroundColor,
    this.foregroundColor,
  });

  String get _initials {
    final n = label.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? cs.primaryContainer;
    final fg = foregroundColor ?? cs.onPrimaryContainer;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        image: hasImage
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: hasImage
          ? null
          : Text(
              _initials,
              style: TextStyle(
                color: fg,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
