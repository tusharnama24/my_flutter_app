import 'package:flutter/material.dart';
import 'package:halo/widgets/follow_button.dart';

class AspirantActionRow extends StatelessWidget {
  final bool isOwnProfile;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback onMessage;
  final VoidCallback onEditProfile;
  final Color accentColor;

  const AspirantActionRow({
    super.key,
    required this.isOwnProfile,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onMessage,
    required this.onEditProfile,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
      child: isOwnProfile
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onEditProfile,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  side: BorderSide(color: accentColor),
                ),
                child: const Text('Edit Profile'),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: FollowButton(
                    isFollowing: isFollowing,
                    isLoading: false,
                    onPressed: onToggleFollow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMessage,
                    icon: const Icon(Icons.message_outlined),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
