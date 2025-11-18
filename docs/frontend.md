# Frontend Flutter - LinkShare App

## Visão Geral

O LinkShare App é um aplicativo móvel Flutter completo que implementa todas as funcionalidades da plataforma social de compartilhamento de links, incluindo capacidades offline-first, colaboração em tempo real e notificações push.

## Arquitetura

```
mobile/linkshare_app/
├── lib/
│   ├── main.dart                      # Entry point, Firebase init
│   ├── models/                        # Data models (DTOs)
│   │   ├── user.dart
│   │   ├── profile.dart
│   │   ├── collection.dart
│   │   ├── link_item.dart
│   │   ├── friendship.dart
│   │   └── ...
│   ├── database/                      # Drift offline database
│   │   ├── app_database.dart          # Main database class
│   │   └── tables/                    # Table definitions
│   │       ├── local_collections.dart
│   │       ├── local_link_items.dart
│   │       ├── local_profiles.dart
│   │       ├── local_friendships.dart
│   │       └── pending_actions.dart
│   ├── services/                      # Business logic services
│   │   ├── api_client.dart            # Dio HTTP client with interceptors
│   │   ├── auth_service.dart          # Authentication (login, register, refresh)
│   │   ├── profile_service.dart       # Profile management, device registration
│   │   ├── collection_service.dart    # Collections and links CRUD
│   │   ├── friendship_service.dart    # Friends management
│   │   ├── storage_service.dart       # Local storage (tokens)
│   │   ├── sync_service.dart          # Offline sync
│   │   ├── signalr_service.dart       # Real-time with SignalR
│   │   ├── firebase_messaging_service.dart  # Push notifications
│   │   └── feed_service.dart          # Public feed
│   ├── repositories/                  # Data repositories (offline-first pattern)
│   │   └── collection_repository.dart
│   ├── providers/                     # Riverpod providers (state management)
│   │   ├── service_providers.dart     # Service DI
│   │   ├── auth_provider.dart         # Auth state
│   │   ├── profile_provider.dart      # Profile state
│   │   ├── collection_provider.dart   # Collections state
│   │   ├── friendship_provider.dart   # Friends state
│   │   ├── feed_provider.dart         # Feed state
│   │   └── database_provider.dart     # Database instance
│   └── screens/                       # UI screens
│       ├── auth/
│       │   ├── login_screen.dart
│       │   └── register_screen.dart
│       ├── home/
│       │   ├── home_screen.dart       # Main screen with bottom nav
│       │   └── feed_tab.dart
│       ├── collections/
│       │   ├── my_collections_tab.dart
│       │   ├── collection_detail_screen.dart
│       │   ├── add_collection_screen.dart
│       │   ├── add_link_item_screen.dart
│       │   ├── share_collection_screen.dart
│       │   └── shared_with_me_screen.dart
│       ├── friends/
│       │   ├── friends_tab.dart
│       │   └── search_friends_screen.dart
│       └── profile/
│           ├── profile_tab.dart
│           └── edit_profile_screen.dart
└── pubspec.yaml                       # Dependencies
```

## Tecnologias Principais

| Tecnologia | Versão | Propósito |
|------------|--------|-----------|
| **Flutter** | SDK >=3.0.0 | Framework mobile |
| **Riverpod** | ^2.4.9 | State management |
| **Dio** | ^5.4.0 | HTTP client |
| **Drift** | ^2.14.1 | Offline-first database (SQLite) |
| **SignalR** | ^1.3.7 | Real-time communication |
| **Firebase Core** | ^2.24.0 | Firebase initialization |
| **Firebase Messaging** | ^14.7.6 | Push notifications (FCM) |
| **flutter_local_notifications** | ^16.3.0 | Local notifications |
| **image_picker** | ^1.0.7 | Profile picture upload |
| **shared_preferences** | ^2.2.2 | Persistent storage (tokens) |
| **device_info_plus** | ^9.1.1 | Device information |

## Funcionalidades Implementadas

### ✅ Módulo 2: Frontend Flutter Básico

#### Autenticação
- **LoginScreen**: Login com email/username e password
- **RegisterScreen**: Registro de novos usuários
- **Token Management**: Armazenamento seguro de access e refresh tokens
- **Auto-login**: Verificação de sessão ao abrir o app
- **Logout**: Limpeza de tokens e redirecionamento

#### Navegação Principal
- **HomeScreen** com BottomNavigationBar:
  - Tab 1: Feed (coleções públicas)
  - Tab 2: My Collections (coleções do usuário)
  - Tab 3: Friends (amigos e pedidos)
  - Tab 4: Profile (perfil do usuário)

#### Coleções
- **MyCollectionsTab**: Lista de coleções do usuário
- **CollectionDetailScreen**: Detalhes da coleção com links
- **AddCollectionScreen**: Criar nova coleção (pública/privada)
- **AddLinkItemScreen**: Adicionar link a uma coleção
- **ShareCollectionScreen**: Compartilhar coleção com amigos
- **SharedWithMeScreen**: Coleções compartilhadas comigo

#### Amizades
- **FriendsTab**:
  - Sub-tab "My Friends": Lista de amigos aceitos
  - Sub-tab "Pending Requests": Pedidos pendentes
- **SearchFriendsScreen**: Buscar usuários e enviar pedidos
- **Aceitar/Recusar**: Gerenciar pedidos de amizade
- **Remover amigo**: Desfazer amizade

#### Perfil
- **ProfileTab**: Visualizar perfil próprio
- **EditProfileScreen**: Editar DisplayName e Bio
- **Upload de foto**: Seleção e upload de foto de perfil
- **Logout**: Botão de sair

### ✅ Módulo 4: Upload de Imagem

- **Image Picker** integrado
- **Platform detection** (kIsWeb vs Mobile)
- **MultipartFile** upload
- **Preview** de imagem antes do upload
- **Error handling** para formatos inválidos

### ✅ Módulo 5: Offline-First com Drift

#### Database Local
```dart
@DriftDatabase(
  tables: [
    LocalCollections,
    LocalLinkItems,
    LocalProfiles,
    LocalFriendships,
    PendingActions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
}
```

#### Offline-First Pattern
1. **Leitura**:
   - UI lê do banco local (Drift) imediatamente
   - Exibe dados antigos (offline)
   - Em paralelo, faz request à API
   - Quando API responde, atualiza o banco local
   - UI se atualiza automaticamente (Riverpod watch)

2. **Escrita**:
   - Tenta enviar à API
   - Se offline, salva em `PendingActions`
   - `SyncService` processa fila quando online
   - Marca item como "pendente" na UI

#### Sync Service
```dart
class SyncService {
  Future<void> syncPendingActions() async {
    final actions = await database.getPendingActions();
    for (final action in actions) {
      try {
        await _executeAction(action);
        await database.deletePendingAction(action.id);
      } catch (e) {
        // Keep in queue for next sync
      }
    }
  }

  void startPeriodicSync() {
    Timer.periodic(Duration(minutes: 5), (_) {
      syncPendingActions();
    });
  }
}
```

### ✅ Módulo 6: Segurança Avançada (Flutter)

#### Auth Interceptor com Refresh Token
```dart
class AuthInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Try to refresh token
      final refreshToken = storage.getRefreshToken();
      if (refreshToken != null) {
        try {
          final response = await dio.post('/auth/refresh', data: {
            'refreshToken': refreshToken,
          });

          // Save new tokens
          storage.setAccessToken(response.data['accessToken']);
          storage.setRefreshToken(response.data['refreshToken']);

          // Retry original request
          final opts = Options(
            method: err.requestOptions.method,
            headers: {...err.requestOptions.headers, 'Authorization': 'Bearer ${response.data['accessToken']}'},
          );

          final cloneReq = await dio.request(
            err.requestOptions.path,
            options: opts,
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
          );

          return handler.resolve(cloneReq);
        } catch (e) {
          // Refresh failed, logout
          storage.clear();
          // Navigate to login
        }
      }
    }
    handler.next(err);
  }
}
```

### ✅ Módulo 7: Real-Time com SignalR

#### SignalRService
```dart
class SignalRService {
  HubConnection? _hubConnection;

  Future<void> connect() async {
    _hubConnection = HubConnectionBuilder()
      .withUrl(hubUrl, options: HttpConnectionOptions(
        accessTokenFactory: () async => accessToken,
      ))
      .withAutomaticReconnect()
      .build();

    // Register event handlers
    _hubConnection!.on('NewLinkAdded', (arguments) {
      final linkData = arguments[0] as Map<String, dynamic>;
      _newLinkAddedController.add(linkData);
    });

    await _hubConnection!.start();
  }

  Future<void> joinCollectionGroup(int collectionId) async {
    await _hubConnection!.invoke('JoinCollectionGroup', args: [collectionId]);
  }
}
```

#### Integração com Drift
```dart
// CollectionDetailScreen
@override
void initState() {
  super.initState();

  // Connect to SignalR
  final signalRService = ref.read(signalRServiceProvider);
  signalRService.joinCollectionGroup(widget.collectionId);

  // Listen to new links
  _newLinkSubscription = signalRService.newLinkAdded.listen((linkData) async {
    // Insert directly into Drift
    final linkItem = model.LinkItem.fromJson(linkData);
    await database.insertLinkItem(linkItem);

    // Riverpod invalidates and UI rebuilds automatically
    if (mounted) {
      ref.invalidate(collectionDetailProvider(widget.collectionId));
    }
  });
}
```

### ✅ Módulo 8: Push Notifications

#### Firebase Messaging Service
```dart
class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permission
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token
    _fcmToken = await _firebaseMessaging.getToken();

    // Setup handlers
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}
```

#### Device Registration
```dart
// HomeScreen.initState()
Future<void> _registerDevice(String fcmToken) async {
  final deviceInfo = DeviceInfoPlugin();

  String deviceName = 'Unknown Device';
  String platform = Platform.isAndroid ? 'android' : 'ios';

  if (Platform.isAndroid) {
    final info = await deviceInfo.androidInfo;
    deviceName = '${info.brand} ${info.model}';
  }

  await profileService.registerDevice(
    fcmToken: fcmToken,
    deviceName: deviceName,
    platform: platform,
  );
}
```

#### Notification Handlers
```dart
void _listenToNotifications(fcmService) {
  // Friend requests
  fcmService.onFriendRequest.listen((data) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('New friend request from ${data['requesterName']}')),
    );
  });

  // Friend accepted
  fcmService.onFriendAccepted.listen((data) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your friend request was accepted!')),
    );
  });

  // Collection shared
  fcmService.onCollectionShared.listen((data) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${data['ownerName']} shared a collection with you')),
    );
  });
}
```

## Configuração do Firebase

### Passo 1: Criar Projeto no Firebase Console

1. Acesse https://console.firebase.google.com
2. Crie um novo projeto ou use existente
3. Adicione apps Android e iOS

### Passo 2: Configurar Android

1. No Firebase Console, adicione app Android
2. Package name: `com.example.linkshare_app` (ou o seu)
3. Baixe `google-services.json`
4. Cole em `android/app/google-services.json`

5. Edite `android/build.gradle`:
```gradle
buildscript {
  dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
  }
}
```

6. Edite `android/app/build.gradle`:
```gradle
apply plugin: 'com.google.gms.google-services'

android {
  defaultConfig {
    minSdkVersion 21  // Firebase requires 21+
  }
}
```

### Passo 3: Configurar iOS

1. No Firebase Console, adicione app iOS
2. Bundle ID: `com.example.linkshar eApp` (verifique em Xcode)
3. Baixe `GoogleService-Info.plist`
4. Abra o projeto no Xcode: `open ios/Runner.xcworkspace`
5. Arraste `GoogleService-Info.plist` para `Runner/Runner` no Xcode

6. Edite `ios/Podfile`:
```ruby
platform :ios, '13.0'  # Firebase requires 13.0+
```

7. Configure permissões em `ios/Runner/Info.plist`:
```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>remote-notification</string>
</array>
```

### Passo 4: FlutterFire CLI (Opcional - Recomendado)

```bash
# Instalar FlutterFire CLI
dart pub global activate flutterfire_cli

# Configurar Firebase automaticamente
flutterfire configure

# Isso cria firebase_options.dart automaticamente
```

Se usar FlutterFire CLI, edite `main.dart`:
```dart
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ...
}
```

### Passo 5: Testar

```bash
flutter run

# Logs esperados:
# Firebase initialized successfully
# FCM: Requesting permission
# FCM: Token obtained: eX1a2b3c...
# Device registered successfully
```

## API Endpoints Utilizados

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| **Auth** |||
| POST | /api/auth/register | Registrar novo usuário |
| POST | /api/auth/login | Login (retorna access + refresh tokens) |
| POST | /api/auth/refresh | Renovar access token |
| POST | /api/auth/logout | Logout (blacklist token) |
| **Profile** |||
| GET | /api/profiles/me | Obter perfil próprio |
| PUT | /api/profiles/me | Atualizar perfil |
| POST | /api/profiles/me/picture | Upload de foto |
| GET | /api/profiles/{username} | Perfil de outro usuário |
| GET | /api/profiles/search?query={q} | Buscar usuários |
| POST | /api/profiles/me/device | Registrar FCM token |
| DELETE | /api/profiles/me/device | Remover dispositivo |
| **Collections** |||
| GET | /api/collections/me | Minhas coleções |
| POST | /api/collections | Criar coleção |
| GET | /api/collections/{id} | Detalhes da coleção |
| POST | /api/collections/{id}/items | Adicionar link |
| POST | /api/collections/{id}/share | Compartilhar com amigo |
| **Friends** |||
| POST | /api/friends/request | Enviar pedido |
| GET | /api/friends/requests | Pedidos pendentes |
| PUT | /api/friends/requests/{id}/accept | Aceitar pedido |
| DELETE | /api/friends/requests/{id} | Recusar pedido |
| GET | /api/friends | Lista de amigos |
| DELETE | /api/friends/{id} | Remover amigo |
| **Feed** |||
| GET | /api/collections/public | Coleções públicas recentes |

## State Management com Riverpod

### Exemplo: Collection Provider

```dart
final collectionDetailProvider = FutureProvider.family<CollectionWithItems, int>((ref, collectionId) async {
  final repository = ref.watch(collectionRepositoryProvider);
  return await repository.getCollectionWithItems(collectionId);
});

// UI
@override
Widget build(BuildContext context, WidgetRef ref) {
  final collectionAsync = ref.watch(collectionDetailProvider(widget.collectionId));

  return collectionAsync.when(
    data: (collection) => _buildCollection(collection),
    loading: () => CircularProgressIndicator(),
    error: (err, stack) => Text('Error: $err'),
  );
}
```

## Fluxo de Dados: Offline-First

```
┌──────────────────────────────────────────────────────────┐
│                         UI (Screen)                       │
│                                                            │
│  ref.watch(collectionProvider)                            │
└────────────────────┬─────────────────────────────────────┘
                     │
                     v
┌──────────────────────────────────────────────────────────┐
│                   Riverpod Provider                       │
│                                                            │
│  FutureProvider.autoDispose((ref) async {                │
│    return await repository.getCollections();             │
│  })                                                       │
└────────────────────┬─────────────────────────────────────┘
                     │
                     v
┌──────────────────────────────────────────────────────────┐
│                  Collection Repository                    │
│                                                            │
│  1. Lê do Drift database (retorna imediatamente)         │
│  2. UI exibe dados antigos (offline-first)               │
│  3. Faz request à API em paralelo                        │
│  4. Quando API responde, atualiza Drift                  │
│  5. Riverpod notifica UI → rebuild automático            │
└──────────────────┬───────────────┬───────────────────────┘
                   │               │
            (read) v               v (write)
         ┌──────────────┐   ┌──────────────┐
         │    Drift     │   │   API Client │
         │   Database   │   │     (Dio)    │
         └──────────────┘   └──────────────┘
```

## Executando o App

### Pré-requisitos

```bash
flutter --version  # Flutter 3.0.0+
dart --version     # Dart 3.0.0+
```

### Instalar Dependências

```bash
cd mobile/linkshare_app
flutter pub get
```

### Gerar Código Drift

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Executar

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Chrome (web - limitado)
flutter run -d chrome
```

### Configurar API URL

Edite o endpoint da API em `lib/services/api_client.dart`:

```dart
class ApiClient {
  static const String baseUrl = 'http://10.0.2.2:8080/api';  // Android emulator
  // static const String baseUrl = 'http://localhost:8080/api';  // iOS simulator
  // static const String baseUrl = 'http://192.168.1.100:8080/api';  // Physical device
}
```

## Estrutura de Código

### Models (DTOs)

```dart
// lib/models/collection.dart
class Collection {
  final int id;
  final String title;
  final String description;
  final bool isPublic;
  final int ownerId;
  final DateTime createdAt;

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      isPublic: json['isPublic'],
      ownerId: json['ownerId'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
```

### Drift Tables

```dart
// lib/database/tables/local_collections.dart
class LocalCollections extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  BoolColumn get isPublic => boolean()();
  IntColumn get ownerId => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}
```

### Services

```dart
// lib/services/collection_service.dart
class CollectionService {
  final ApiClient _apiClient;

  Future<List<Collection>> getMyCollections() async {
    final response = await _apiClient.get('/collections/me');
    return (response.data as List)
      .map((json) => Collection.fromJson(json))
      .toList();
  }

  Future<Collection> createCollection({
    required String title,
    required String description,
    required bool isPublic,
  }) async {
    final response = await _apiClient.post('/collections', data: {
      'title': title,
      'description': description,
      'isPublic': isPublic,
    });
    return Collection.fromJson(response.data);
  }
}
```

## Troubleshooting

### Firebase não inicializa

**Erro:**
```
Firebase initialization failed: [core/no-app]
```

**Solução:**
1. Verificar `google-services.json` (Android) ou `GoogleService-Info.plist` (iOS)
2. Verificar `google-services` plugin em `build.gradle`
3. Executar `flutter clean && flutter pub get`

### SignalR não conecta

**Erro:**
```
SignalR: Connection failed: SocketException
```

**Solução:**
1. Verificar URL do hub em `signalr_service.dart`
2. Android emulator: usar `http://10.0.2.2:8080`
3. iOS simulator: usar `http://localhost:8080`
4. Device físico: usar IP da máquina na rede

### Drift errors

**Erro:**
```
Error: The getter 'companionWhere' isn't defined
```

**Solução:**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Token expirado

Se receber 401 constantemente:
1. Verificar `AuthInterceptor` está registrado no Dio
2. Verificar refresh token está sendo salvo
3. Limpar storage e fazer login novamente:
```dart
await storage.clear();
```

## Melhorias Futuras

### 1. Deep Linking
Abrir coleção específica via notificação:
```dart
FirebaseMessaging.onMessageOpenedApp.listen((message) {
  final collectionId = message.data['collectionId'];
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => CollectionDetailScreen(collectionId)),
  );
});
```

### 2. Infinite Scroll
Paginação no feed:
```dart
final feedProvider = FutureProvider.family<List<Collection>, int>((ref, page) async {
  return await feedService.getPublicCollections(page: page, limit: 20);
});
```

### 3. Image Caching
Cachear imagens de perfil e links:
```dart
dependencies:
  cached_network_image: ^3.3.0
```

### 4. Dark Mode
```dart
theme: ThemeData.light(),
darkTheme: ThemeData.dark(),
themeMode: ThemeMode.system,
```

### 5. Analytics
```dart
dependencies:
  firebase_analytics: ^10.7.0
```

## Conclusão

O frontend Flutter do LinkShare está completo com:

✅ **48 arquivos Dart** implementados
✅ **Offline-First** com Drift database
✅ **Real-time** com SignalR
✅ **Push Notifications** com FCM
✅ **Auto refresh tokens** com interceptor
✅ **State management** com Riverpod
✅ **Upload de imagens** com image_picker
✅ **Navegação completa** com 4 tabs
✅ **Todas as telas** (Auth, Collections, Friends, Profile)

O app está pronto para ser testado e usado em produção após configurar o Firebase!
