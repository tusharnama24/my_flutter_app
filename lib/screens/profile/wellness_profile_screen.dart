import 'package:flutter/material.dart';
import 'package:halo/Profile Pages/wellness_profile_page.dart' as legacy;
import 'package:halo/Profile Pages/aspirant_profile_page.dart' as aspirant_legacy;
import 'package:halo/Profile Pages/guru_profile_page.dart' as guru_legacy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/controllers/profile_controller.dart';
import 'package:halo/screens/profile/widgets/profile_skeleton.dart';

class WellnessProfileScreen extends ConsumerWidget {
  final String profileUserId;
  const WellnessProfileScreen({Key? key, required this.profileUserId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileStreamProvider(profileUserId));
    return profileAsync.when(
      loading: () => const ProfileSkeleton(),
      error: (_, __) => legacy.WellnessProfilePage(profileUserId: profileUserId),
      data: (user) {
        final type = user?.accountType ?? 'wellness';
        if (type == 'aspirant') {
          return aspirant_legacy.ProfilePage(profileUserId: profileUserId);
        }
        if (type == 'guru') {
          return guru_legacy.GuruProfilePage(profileUserId: profileUserId);
        }
        return legacy.WellnessProfilePage(profileUserId: profileUserId);
      },
    );
  }
}
