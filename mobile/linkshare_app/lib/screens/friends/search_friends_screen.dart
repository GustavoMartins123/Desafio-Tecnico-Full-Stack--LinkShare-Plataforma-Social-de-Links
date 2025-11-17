import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/profile_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/friendship_provider.dart';

class SearchFriendsScreen extends ConsumerStatefulWidget {
  const SearchFriendsScreen({super.key});

  @override
  ConsumerState<SearchFriendsScreen> createState() => _SearchFriendsScreenState();
}

class _SearchFriendsScreenState extends ConsumerState<SearchFriendsScreen> {
  final _searchController = TextEditingController();
  final _sentRequests = <int>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(profileSearchProvider.notifier).state = query;
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Friends'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by username or name...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(profileSearchProvider.notifier).state = '';
                  },
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          Expanded(
            child: searchResultsAsync.when(
              data: (profiles) {
                if (profiles.isEmpty && _searchController.text.trim().isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Search for users',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Enter a username or name to find friends',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (profiles.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No users found'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    final requestSent = _sentRequests.contains(profile.userId);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            profile.displayName.isNotEmpty
                                ? profile.displayName[0].toUpperCase()
                                : profile.username[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName
                              : profile.username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@${profile.username}'),
                            if (profile.bio.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                profile.bio,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: requestSent
                            ? const Chip(
                                label: Text('Sent', style: TextStyle(fontSize: 12)),
                                backgroundColor: Colors.green,
                                labelStyle: TextStyle(color: Colors.white),
                              )
                            : ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    final friendshipService =
                                        ref.read(friendshipServiceProvider);
                                    await friendshipService.sendFriendRequest(profile.userId);
                                    setState(() {
                                      _sentRequests.add(profile.userId);
                                    });
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Friend request sent!'),
                                        ),
                                      );
                                    }
                                    // Invalidate requests to show the new request
                                    ref.invalidate(friendRequestsProvider);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: ${e.toString()}')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text('Add'),
                              ),
                        isThreeLine: profile.bio.isNotEmpty,
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
          ),
        ],
      ),
    );
  }
}
