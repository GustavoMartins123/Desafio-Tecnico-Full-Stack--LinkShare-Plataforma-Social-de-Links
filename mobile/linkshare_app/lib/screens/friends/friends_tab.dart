import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/friendship_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/auth_provider.dart';
import 'search_friends_screen.dart';

class FriendsTab extends ConsumerWidget {
  const FriendsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Friends'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Friends'),
              Tab(text: 'Requests'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchFriendsScreen()),
                );
              },
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _MyFriendsTab(),
            _FriendRequestsTab(),
          ],
        ),
      ),
    );
  }
}

class _MyFriendsTab extends ConsumerWidget {
  const _MyFriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(myFriendsProvider);
    final currentUser = ref.watch(currentUserProvider);

    return friendsAsync.when(
      data: (friendships) {
        if (friendships.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No friends yet',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  'Tap the + button to search for friends',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(myFriendsProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: friendships.length,
            itemBuilder: (context, index) {
              final friendship = friendships[index];
              // Determine which user is the friend (not current user)
              final iAmRequester = friendship.requesterId == currentUser?.id;
              final friendUsername = iAmRequester
                  ? friendship.addresseeUsername
                  : friendship.requesterUsername;
              final friendDisplayName = iAmRequester
                  ? friendship.addresseeDisplayName
                  : friendship.requesterDisplayName;
              final friendId = iAmRequester
                  ? friendship.addresseeId
                  : friendship.requesterId;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      friendDisplayName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    friendDisplayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('@$friendUsername'),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Remove Friend'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'remove') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Remove Friend'),
                            content: Text('Remove $friendDisplayName from your friends?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          try {
                            final friendshipService = ref.read(friendshipServiceProvider);
                            await friendshipService.removeFriend(friendId);
                            ref.invalidate(myFriendsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Friend removed')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString()}')),
                              );
                            }
                          }
                        }
                      }
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${error.toString()}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(myFriendsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRequestsTab extends ConsumerWidget {
  const _FriendRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(friendRequestsProvider);

    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => ref.refresh(friendRequestsProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: Text(
                      request.requesterDisplayName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    request.requesterDisplayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('@${request.requesterUsername}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          try {
                            final friendshipService = ref.read(friendshipServiceProvider);
                            await friendshipService.acceptFriendRequest(request.id);
                            ref.invalidate(friendRequestsProvider);
                            ref.invalidate(myFriendsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Friend request accepted')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString()}')),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          try {
                            final friendshipService = ref.read(friendshipServiceProvider);
                            await friendshipService.declineFriendRequest(request.id);
                            ref.invalidate(friendRequestsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Friend request declined')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${e.toString()}')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: ${error.toString()}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.refresh(friendRequestsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
