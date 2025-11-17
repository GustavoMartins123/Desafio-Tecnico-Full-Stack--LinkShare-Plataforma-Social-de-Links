import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/friendship.dart';
import 'service_providers.dart';

// My Friends Provider
final myFriendsProvider = FutureProvider<List<Friendship>>((ref) async {
  final friendshipService = ref.watch(friendshipServiceProvider);
  return await friendshipService.getFriends();
});

// Friend Requests Provider
final friendRequestsProvider = FutureProvider<List<Friendship>>((ref) async {
  final friendshipService = ref.watch(friendshipServiceProvider);
  return await friendshipService.getFriendRequests();
});
