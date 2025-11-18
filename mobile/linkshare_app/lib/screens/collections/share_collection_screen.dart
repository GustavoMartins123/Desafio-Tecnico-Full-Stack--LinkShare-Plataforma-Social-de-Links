import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/collection.dart';
import '../../models/collection_share.dart';
import '../../models/friendship.dart';
import '../../providers/service_providers.dart';
import 'package:intl/intl.dart';

class ShareCollectionScreen extends ConsumerStatefulWidget {
  final Collection collection;

  const ShareCollectionScreen({
    super.key,
    required this.collection,
  });

  @override
  ConsumerState<ShareCollectionScreen> createState() => _ShareCollectionScreenState();
}

class _ShareCollectionScreenState extends ConsumerState<ShareCollectionScreen> {
  List<Friendship> _friends = [];
  List<CollectionShare> _shares = [];
  bool _isLoading = true;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final friendshipService = ref.read(friendshipServiceProvider);
      final collectionService = ref.read(collectionServiceProvider);

      final friends = await friendshipService.getMyFriends();
      final shares = await collectionService.getCollectionShares(widget.collection.id);

      setState(() {
        _friends = friends;
        _shares = shares;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _shareWithFriend(int friendId, bool canEdit) async {
    setState(() => _isSharing = true);

    try {
      final collectionService = ref.read(collectionServiceProvider);
      final share = await collectionService.shareCollection(
        collectionId: widget.collection.id,
        sharedWithUserId: friendId,
        canEdit: canEdit,
      );

      if (mounted) {
        setState(() {
          _shares.add(share);
          _isSharing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collection shared successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _updatePermissions(int shareId, bool canEdit) async {
    try {
      final collectionService = ref.read(collectionServiceProvider);
      final updatedShare = await collectionService.updateSharePermissions(
        collectionId: widget.collection.id,
        shareId: shareId,
        canEdit: canEdit,
      );

      if (mounted) {
        setState(() {
          final index = _shares.indexWhere((s) => s.id == shareId);
          if (index != -1) {
            _shares[index] = updatedShare;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _removeShare(int shareId) async {
    try {
      final collectionService = ref.read(collectionServiceProvider);
      await collectionService.removeShare(
        collectionId: widget.collection.id,
        shareId: shareId,
      );

      if (mounted) {
        setState(() {
          _shares.removeWhere((s) => s.id == shareId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showShareDialog() {
    // Filter friends who don't already have access
    final availableFriends = _friends.where((friend) {
      return !_shares.any((share) => share.sharedWithUserId == friend.friendId);
    }).toList();

    if (availableFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All friends already have access')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _ShareDialog(
        friends: availableFriends,
        onShare: _shareWithFriend,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Collection'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.collection.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (widget.collection.description != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.collection.description!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                widget.collection.isPublic
                                    ? Icons.public
                                    : Icons.lock,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.collection.isPublic
                                    ? 'Public'
                                    : 'Private',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shared with (${_shares.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ElevatedButton.icon(
                        onPressed: _isSharing ? null : _showShareDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _shares.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.share,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Not shared with anyone yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _showShareDialog,
                                child: const Text('Share with a friend'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _shares.length,
                          itemBuilder: (context, index) {
                            final share = _shares[index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  share.sharedWithDisplayName.isNotEmpty
                                      ? share.sharedWithDisplayName[0].toUpperCase()
                                      : share.sharedWithUsername[0].toUpperCase(),
                                ),
                              ),
                              title: Text(share.sharedWithDisplayName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('@${share.sharedWithUsername}'),
                                  Text(
                                    'Shared ${DateFormat.yMMMd().format(share.sharedAt)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                icon: const Icon(Icons.more_vert),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'permissions',
                                    child: Row(
                                      children: [
                                        Icon(
                                          share.canEdit
                                              ? Icons.visibility
                                              : Icons.edit,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          share.canEdit
                                              ? 'Remove edit access'
                                              : 'Grant edit access',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(Icons.remove_circle, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Remove access', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) {
                                  if (value == 'permissions') {
                                    _updatePermissions(share.id, !share.canEdit);
                                  } else if (value == 'remove') {
                                    _removeShare(share.id);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _ShareDialog extends StatefulWidget {
  final List<Friendship> friends;
  final Function(int friendId, bool canEdit) onShare;

  const _ShareDialog({
    required this.friends,
    required this.onShare,
  });

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  int? _selectedFriendId;
  bool _canEdit = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share with friend'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(
              labelText: 'Select friend',
              border: OutlineInputBorder(),
            ),
            value: _selectedFriendId,
            items: widget.friends.map((friend) {
              return DropdownMenuItem(
                value: friend.friendId,
                child: Text(friend.friendDisplayName),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedFriendId = value);
            },
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('Can edit'),
            subtitle: const Text('Allow friend to add/edit links'),
            value: _canEdit,
            onChanged: (value) {
              setState(() => _canEdit = value ?? false);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedFriendId == null
              ? null
              : () {
                  widget.onShare(_selectedFriendId!, _canEdit);
                  Navigator.of(context).pop();
                },
          child: const Text('Share'),
        ),
      ],
    );
  }
}
