import 'package:flutter/material.dart';
import 'package:iot_manager/core/widgets/glass_card.dart';
import 'package:iot_manager/features/profile/domain/entities/profile_entity.dart';
import 'package:iot_manager/features/profile/presentation/widgets/avatar_action_button.dart';
import 'package:iot_manager/features/profile/presentation/widgets/avatar_view.dart';

class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.profile,
    required this.editMode,
    required this.uploadingAvatar,
    required this.onCameraTap,
    required this.onGalleryTap,
  });

  final ProfileEntity profile;
  final bool editMode;
  final bool uploadingAvatar;
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      child: Row(
        crossAxisAlignment:
        editMode ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          AvatarView(
            imageUrl: profile.avatarSignedUrl,
            initials: profile.initials,
            uploading: uploadingAvatar,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: editMode ? null : 104,
              child: Column(
                mainAxisAlignment:
                editMode ? MainAxisAlignment.start : MainAxisAlignment.center,
                crossAxisAlignment:
                editMode ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Text(profile.fullName.isEmpty ? 'Tu perfil' : profile.fullName,
                    textAlign: editMode ? TextAlign.start : TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800,),
                  ),
                  if (editMode) ...[
                    const SizedBox(height: 14),
                    Text('Cambiar foto de perfil',
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AvatarActionButton(
                            icon: Icons.photo_camera_rounded,
                            label: 'Cámara',
                            enabled: !uploadingAvatar,
                            onTap: onCameraTap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: AvatarActionButton(
                            icon: Icons.photo_library_rounded,
                            label: 'Galería',
                            enabled: !uploadingAvatar,
                            onTap: onGalleryTap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}