import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/friendship_provider.dart';
import '../../providers/service_providers.dart';

class ShareCollectionScreen extends ConsumerWidget {
  final int collectionId;

  const ShareCollectionScreen({
    super.key,
    required this.collectionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(myFriendsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share with Friends'),
      ),
      body: friendsAsync.when(
        data: (friendships) {
          if (friendships.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No friends yet'),
                  SizedBox(height: 8),
                  Text(
                    'Add friends to share collections with them',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: friendships.length,
            itemBuilder: (context, index) {
              final friendship = friendships[index];
              // Determine which user is the friend (not the current user)
              final friendUsername = friendship.requesterUsername;
              final friendDisplayName = friendship.requesterDisplayName;
              final friendId = friendship.requesterId;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(friendDisplayName[0].toUpperCase()),
                  ),
                  title: Text(friendDisplayName),
                  subtitle: Text('@$friendUsername'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      try {
                        final collectionService = ref.read(collectionServiceProvider);
                        await collectionService.shareCollection(
                          collectionId: collectionId,
                          friendId: friendId,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Shared with $friendDisplayName'),
                            ),
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
                    child: const Text('Share'),
                  ),
                ),
              );
            },
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
            ],
          ),
        ),
      ),
    );
  }
}
