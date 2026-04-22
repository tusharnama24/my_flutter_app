import 'package:flutter/material.dart';
import 'package:halo/Profile Pages/guru_profile_page.dart' as legacy;
import 'package:halo/Profile Pages/aspirant_profile_page.dart' as aspirant_legacy;
import 'package:halo/Profile Pages/wellness_profile_page.dart' as wellness_legacy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:halo/controllers/profile_controller.dart';
import 'package:halo/screens/profile/widgets/profile_skeleton.dart';

class GuruProfileScreen extends ConsumerWidget {
  final String profileUserId;
  const GuruProfileScreen({Key? key, required this.profileUserId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileStreamProvider(profileUserId));
    return profileAsync.when(
      loading: () => const ProfileSkeleton(),
      error: (_, __) => legacy.GuruProfilePage(profileUserId: profileUserId),
      data: (user) {
        final type = user?.accountType ?? 'guru';
        if (type == 'aspirant') {
          return aspirant_legacy.ProfilePage(profileUserId: profileUserId);
        }
        if (type == 'wellness') {
          return wellness_legacy.WellnessProfilePage(profileUserId: profileUserId);
        }
        return legacy.GuruProfilePage(profileUserId: profileUserId);
      },
    );
  }
}
