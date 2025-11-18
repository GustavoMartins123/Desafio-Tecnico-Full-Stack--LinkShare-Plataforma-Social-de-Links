import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../collections/my_collections_tab.dart';
import '../friends/friends_tab.dart';
import '../profile/profile_tab.dart';
import '../../providers/service_providers.dart';
import 'feed_tab.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const FeedTab(),
    const MyCollectionsTab(),
    const FriendsTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize Firebase Messaging
    try {
      final fcmService = ref.read(firebaseMessagingServiceProvider);
      await fcmService.initialize();

      final token = fcmService.fcmToken;
      if (token != null) {
        // Register device with backend
        await _registerDevice(token);

        // Listen to FCM events
        _listenToNotifications(fcmService);
      }
    } catch (e) {
      print('Error initializing FCM: $e');
    }

    // Initialize SignalR
    try {
      final signalRService = ref.read(signalRServiceProvider);
      await signalRService.connect();
      await signalRService.joinFriendshipGroup();
    } catch (e) {
      print('Error initializing SignalR: $e');
    }
  }

  Future<void> _registerDevice(String fcmToken) async {
    try {
      final profileService = ref.read(profileServiceProvider);
      final deviceInfo = DeviceInfoPlugin();

      String deviceName = 'Unknown Device';
      String platform = Platform.isAndroid ? 'android' : 'ios';

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        deviceName = '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        deviceName = '${info.name} ${info.model}';
      }

      await profileService.registerDevice(
        fcmToken: fcmToken,
        deviceName: deviceName,
        platform: platform,
      );

      print('Device registered successfully');
    } catch (e) {
      print('Error registering device: $e');
    }
  }

  void _listenToNotifications(fcmService) {
    // Listen to friend requests
    fcmService.onFriendRequest.listen((data) {
      print('Friend request received: $data');
      // Show snackbar or dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New friend request from ${data['requesterName'] ?? 'someone'}')),
        );
      }
    });

    // Listen to friend requests accepted
    fcmService.onFriendAccepted.listen((data) {
      print('Friend request accepted: $data');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your friend request was accepted!')),
        );
      }
    });

    // Listen to collection shared
    fcmService.onCollectionShared.listen((data) {
      print('Collection shared: $data');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${data['ownerName'] ?? 'Someone'} shared a collection with you')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.collections_bookmark),
            label: 'Collections',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
