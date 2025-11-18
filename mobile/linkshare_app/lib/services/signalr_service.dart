import 'package:signalr_netcore/signalr_client.dart';
import 'storage_service.dart';
import 'dart:async';

class SignalRService {
  final StorageService _storage;
  HubConnection? _hubConnection;
  bool _isConnected = false;

  static const String hubUrl = 'http://localhost:8080/hubs/collection';

  // Event streams
  final _newLinkAddedController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<HubConnectionState>.broadcast();

  Stream<Map<String, dynamic>> get newLinkAdded => _newLinkAddedController.stream;
  Stream<HubConnectionState> get connectionState => _connectionStateController.stream;

  SignalRService(this._storage);

  /// Initialize and start the SignalR connection
  Future<void> connect() async {
    if (_isConnected || _hubConnection != null) {
      print('SignalR: Already connected or connecting');
      return;
    }

    final accessToken = _storage.getAccessToken();
    if (accessToken == null) {
      print('SignalR: No access token available');
      return;
    }

    try {
      // Create connection with authentication
      _hubConnection = HubConnectionBuilder()
          .withUrl(
            hubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => accessToken,
              logging: (level, message) => print('SignalR [$level]: $message'),
            ),
          )
          .withAutomaticReconnect()
          .build();

      // Register event handlers
      _registerEventHandlers();

      // Listen to connection state changes
      _hubConnection!.onclose((error) {
        print('SignalR: Connection closed. Error: $error');
        _isConnected = false;
        _connectionStateController.add(HubConnectionState.Disconnected);
      });

      _hubConnection!.onreconnecting((error) {
        print('SignalR: Reconnecting... Error: $error');
        _connectionStateController.add(HubConnectionState.Reconnecting);
      });

      _hubConnection!.onreconnected((connectionId) {
        print('SignalR: Reconnected. ConnectionId: $connectionId');
        _isConnected = true;
        _connectionStateController.add(HubConnectionState.Connected);
      });

      // Start connection
      await _hubConnection!.start();
      _isConnected = true;
      _connectionStateController.add(HubConnectionState.Connected);

      print('SignalR: Connected successfully');
    } catch (e) {
      print('SignalR: Connection failed: $e');
      _isConnected = false;
      _connectionStateController.add(HubConnectionState.Disconnected);
    }
  }

  /// Register event handlers for SignalR events
  void _registerEventHandlers() {
    if (_hubConnection == null) return;

    // Handle NewLinkAdded event
    _hubConnection!.on('NewLinkAdded', (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final linkData = arguments[0] as Map<String, dynamic>;
        print('SignalR: NewLinkAdded event received: $linkData');
        _newLinkAddedController.add(linkData);
      }
    });

    // You can add more event handlers here
    // _hubConnection!.on('CollectionUpdated', (arguments) { ... });
    // _hubConnection!.on('LinkDeleted', (arguments) { ... });
  }

  /// Join a collection group to receive updates
  Future<void> joinCollectionGroup(int collectionId) async {
    if (!_isConnected || _hubConnection == null) {
      print('SignalR: Cannot join group - not connected');
      return;
    }

    try {
      await _hubConnection!.invoke('JoinCollectionGroup', args: [collectionId]);
      print('SignalR: Joined collection group $collectionId');
    } catch (e) {
      print('SignalR: Failed to join collection group: $e');
    }
  }

  /// Leave a collection group
  Future<void> leaveCollectionGroup(int collectionId) async {
    if (_hubConnection == null) return;

    try {
      await _hubConnection!.invoke('LeaveCollectionGroup', args: [collectionId]);
      print('SignalR: Left collection group $collectionId');
    } catch (e) {
      print('SignalR: Failed to leave collection group: $e');
    }
  }

  /// Join friendship notification group
  Future<void> joinFriendshipGroup() async {
    if (!_isConnected || _hubConnection == null) {
      print('SignalR: Cannot join friendship group - not connected');
      return;
    }

    try {
      await _hubConnection!.invoke('JoinFriendshipGroup');
      print('SignalR: Joined friendship group');
    } catch (e) {
      print('SignalR: Failed to join friendship group: $e');
    }
  }

  /// Leave friendship notification group
  Future<void> leaveFriendshipGroup() async {
    if (_hubConnection == null) return;

    try {
      await _hubConnection!.invoke('LeaveFriendshipGroup');
      print('SignalR: Left friendship group');
    } catch (e) {
      print('SignalR: Failed to leave friendship group: $e');
    }
  }

  /// Disconnect from SignalR
  Future<void> disconnect() async {
    if (_hubConnection == null) return;

    try {
      await _hubConnection!.stop();
      _isConnected = false;
      _connectionStateController.add(HubConnectionState.Disconnected);
      print('SignalR: Disconnected');
    } catch (e) {
      print('SignalR: Error disconnecting: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _newLinkAddedController.close();
    _connectionStateController.close();
  }

  bool get isConnected => _isConnected;
}
