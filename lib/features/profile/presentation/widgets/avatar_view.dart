import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    required this.imageUrl,
    required this.initials,
    required this.uploading,
  });

  final String? imageUrl;
  final String initials;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary.withValues(alpha: 0.12),
            border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
          ),
          child: ClipOval(
            child: imageUrl == null || imageUrl!.trim().isEmpty ? Center(
              child: Text(initials,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ) : CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Center(
                child: Text(initials,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (uploading)
          Container(width: 104, height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.30),
            ),
            child: const Center(child: CircularProgressIndicator(),),
          ),
      ],
    );
  }
}