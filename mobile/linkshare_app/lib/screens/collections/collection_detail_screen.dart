import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drift/drift.dart' as drift;
import '../../providers/collection_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/service_providers.dart';
import '../../models/link_item.dart' as model;
import '../../database/app_database.dart';
import 'add_link_item_screen.dart';
import 'share_collection_screen.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  final int collectionId;

  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
  });

  @override
  ConsumerState<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends ConsumerState<CollectionDetailScreen> {
  StreamSubscription? _newLinkSubscription;

  @override
  void initState() {
    super.initState();
    _initializeSignalR();
  }

  Future<void> _initializeSignalR() async {
    final signalRService = ref.read(signalRServiceProvider);
    final database = ref.read(databaseProvider);

    // Connect to SignalR if not already connected
    if (!signalRService.isConnected) {
      await signalRService.connect();
    }

    // Join the collection group
    await signalRService.joinCollectionGroup(widget.collectionId);

    // Listen to NewLinkAdded events
    _newLinkSubscription = signalRService.newLinkAdded.listen((linkData) async {
      print('CollectionDetailScreen: Received NewLinkAdded event: $linkData');

      // Check if this link belongs to the current collection
      final linkCollectionId = linkData['collectionId'] as int;
      if (linkCollectionId != widget.collectionId) return;

      // Parse the link item
      final linkItem = model.LinkItem.fromJson(linkData);

      // Insert into local Drift database
      try {
        await database.insertLinkItem(
          LocalLinkItemsCompanion.insert(
            id: drift.Value(linkItem.id),
            title: linkItem.title,
            url: linkItem.url,
            description: linkItem.description,
            collectionId: linkItem.collectionId,
            createdAt: linkItem.createdAt,
            lastSyncedAt: drift.Value(DateTime.now()),
          ),
        );

        print('CollectionDetailScreen: Link added to local database');

        // Refresh the UI by invalidating the provider
        // This will trigger a rebuild with the updated data from Drift
        if (mounted) {
          ref.invalidate(collectionDetailProvider(widget.collectionId));
        }
      } catch (e) {
        print('CollectionDetailScreen: Error inserting link into database: $e');
      }
    });
  }

  @override
  void dispose() {
    // Clean up SignalR connection
    final signalRService = ref.read(signalRServiceProvider);
    signalRService.leaveCollectionGroup(widget.collectionId);
    _newLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collectionAsync = ref.watch(collectionDetailProvider(widget.collectionId));
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Details'),
        actions: [
          // Real-time indicator
          Consumer(
            builder: (context, ref, child) {
              final signalRService = ref.watch(signalRServiceProvider);
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Icon(
                  Icons.circle,
                  size: 12,
                  color: signalRService.isConnected ? Colors.green : Colors.grey,
                ),
              );
            },
          ),
        ],
      ),
      body: collectionAsync.when(
        data: (collection) {
          final isOwner = currentUser?.id == collection.ownerId;

          return RefreshIndicator(
            onRefresh: () => ref.refresh(collectionDetailProvider(widget.collectionId).future),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                collection.title,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            Chip(
                              label: Text(
                                collection.isPublic ? 'Public' : 'Private',
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: collection.isPublic
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'by @${collection.ownerUsername}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.flash_on,
                              size: 16,
                              color: Colors.amber,
                            ),
                            Text(
                              'Live',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (collection.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(collection.description),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'Created ${DateFormat.yMMMMd().format(collection.createdAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (isOwner)
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => AddLinkItemScreen(
                                          collectionId: collection.id,
                                        ),
                                      ),
                                    );
                                    ref.invalidate(collectionDetailProvider(widget.collectionId));
                                  },
                                  icon: const Icon(Icons.add_link),
                                  label: const Text('Add Link'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ShareCollectionScreen(
                                          collection: collection,
                                        ),
                                      ),
                                    );
                                    ref.invalidate(collectionDetailProvider(widget.collectionId));
                                  },
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share'),
                                ),
                              ),
                            ],
                          ),
                        const Divider(height: 32),
                        Text(
                          'Links (${collection.linkItems?.length ?? 0})',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (collection.linkItems == null || collection.linkItems!.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.link_off, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No links yet'),
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final linkItem = collection.linkItems![index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.link),
                            ),
                            title: Text(
                              linkItem.title,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (linkItem.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    linkItem.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  linkItem.url,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () async {
                                final uri = Uri.parse(linkItem.url);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                      childCount: collection.linkItems!.length,
                    ),
                  ),
              ],
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
                onPressed: () => ref.refresh(collectionDetailProvider(widget.collectionId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
