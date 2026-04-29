import 'dart:io';
import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.initials,
    this.radius = 22,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = backgroundColor ?? cs.primary.withOpacity(0.12);
    final txtColor = textColor ?? cs.primary;

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      if (avatarUrl!.startsWith('assets/')) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: AssetImage(avatarUrl!),
          backgroundColor: bgColor,
        );
      }
      if (avatarUrl!.startsWith('/')) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: FileImage(File(avatarUrl!)),
          backgroundColor: bgColor,
        );
      }
      if (avatarUrl!.startsWith('http://') || avatarUrl!.startsWith('https://')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          child: ClipOval(
            child: Image.network(
              avatarUrl!,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildInitials(bgColor, txtColor);
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildInitials(bgColor, txtColor); // Show initials while loading
              },
            ),
          ),
        );
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: _buildInitials(bgColor, txtColor),
    );
  }

  Widget _buildInitials(Color bgColor, Color txtColor) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: txtColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.65,
        ),
      ),
    );
  }
}
