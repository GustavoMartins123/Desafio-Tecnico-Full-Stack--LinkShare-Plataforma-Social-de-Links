import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import 'service_providers.dart';

// My Profile Provider
final myProfileProvider = FutureProvider<Profile>((ref) async {
  final profileService = ref.watch(profileServiceProvider);
  return await profileService.getMyProfile();
});

// Profile Search Provider
final profileSearchProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<Profile>>((ref) async {
  final query = ref.watch(profileSearchProvider);
  if (query.isEmpty) {
    return [];
  }
  final profileService = ref.watch(profileServiceProvider);
  return await profileService.searchProfiles(query);
});
