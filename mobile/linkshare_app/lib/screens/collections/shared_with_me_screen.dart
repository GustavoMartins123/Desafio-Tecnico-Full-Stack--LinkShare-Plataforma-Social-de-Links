import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/shared_collection.dart';
import '../../providers/service_providers.dart';
import 'package:intl/intl.dart';
import 'collection_detail_screen.dart';

class SharedWithMeScreen extends ConsumerStatefulWidget {
  const SharedWithMeScreen({super.key});

  @override
  ConsumerState<SharedWithMeScreen> createState() => _SharedWithMeScreenState();
}

class _SharedWithMeScreenState extends ConsumerState<SharedWithMeScreen> {
  List<SharedCollection> _sharedCollections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSharedCollections();
  }

  Future<void> _loadSharedCollections() async {
    setState(() => _isLoading = true);

    try {
      final collectionService = ref.read(collectionServiceProvider);
      final collections = await collectionService.getSharedWithMe();

      setState(() {
        _sharedCollections = collections;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared With Me'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sharedCollections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_shared,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No shared collections',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Collections shared with you will appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSharedCollections,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sharedCollections.length,
                    itemBuilder: (context, index) {
                      final collection = _sharedCollections[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: collection.canEdit
                                ? Colors.green
                                : Colors.blue,
                            child: Icon(
                              collection.canEdit
                                  ? Icons.edit
                                  : Icons.visibility,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            collection.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (collection.description != null) ...[
                                Text(
                                  collection.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                              ],
                              Row(
                                children: [
                                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    collection.ownerDisplayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.link, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${collection.linkCount} links',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Shared ${DateFormat.yMMMd().format(collection.sharedAt)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Chip(
                            label: Text(
                              collection.canEdit ? 'Can Edit' : 'View Only',
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: collection.canEdit
                                ? Colors.green[100]
                                : Colors.blue[100],
                            padding: EdgeInsets.zero,
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => CollectionDetailScreen(
                                  collectionId: collection.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
