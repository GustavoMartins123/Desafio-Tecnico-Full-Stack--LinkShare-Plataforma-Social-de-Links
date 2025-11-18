import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity.dart';
import 'service_providers.dart';

// Feed Activities Provider
final feedActivitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final feedService = ref.watch(feedServiceProvider);
  return await feedService.getFeedActivities(limit: 50);
});
