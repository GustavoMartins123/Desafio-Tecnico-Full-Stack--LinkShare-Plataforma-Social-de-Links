# Módulo 2: Frontend (Flutter) - Documentação

## 📋 Resumo

Este módulo implementa o aplicativo mobile completo da plataforma LinkShare usando Flutter, com gerenciamento de estado via Riverpod, integração completa com a API backend, e uma interface moderna e responsiva.

---

## 🎯 O que foi feito

### 1. Estrutura do Projeto Flutter

Criada a estrutura completa do aplicativo Flutter com organização modular:

```
mobile/linkshare_app/
├── lib/
│   ├── models/           # Modelos de dados (espelham DTOs da API)
│   ├── services/         # Serviços HTTP e armazenamento
│   ├── providers/        # Providers Riverpod (state management)
│   ├── screens/          # Telas do aplicativo
│   │   ├── auth/         # Login e Register
│   │   ├── home/         # HomeScreen e Feed
│   │   ├── collections/  # Gerenciamento de coleções
│   │   ├── friends/      # Sistema de amizades
│   │   └── profile/      # Perfil do usuário
│   ├── widgets/          # Widgets reutilizáveis (preparado para expansão)
│   └── main.dart         # Ponto de entrada
├── pubspec.yaml          # Dependências
├── analysis_options.yaml # Configurações do linter
└── README.md             # Documentação do app
```

**Por que essa estrutura?**
- **Feature-based organization**: Código organizado por funcionalidade
- **Separação clara**: Models, Services, Providers e UI separados
- **Escalabilidade**: Fácil adicionar novas features
- **Testabilidade**: Camadas independentes facilitam testes

---

### 2. Dependências (pubspec.yaml)

```yaml
dependencies:
  flutter_riverpod: ^2.4.9  # State management
  dio: ^5.4.0               # HTTP client
  shared_preferences: ^2.2.2 # Local storage
  intl: ^0.18.1             # Internacionalização/formatação
  url_launcher: ^6.2.2      # Abrir links externos
```

**Por que essas bibliotecas?**

- **flutter_riverpod**:
  - State management moderno e type-safe
  - Melhor que Provider (predecessor)
  - Suporte a async/await nativo
  - Dependency injection integrado

- **dio**:
  - HTTP client mais poderoso que http
  - Interceptors (para adicionar token automaticamente)
  - Melhor tratamento de erros
  - Cancelamento de requisições

- **shared_preferences**:
  - Persistência local simples (key-value)
  - Ideal para armazenar token JWT
  - Rápido e confiável

- **intl**:
  - Formatação de datas
  - Preparado para i18n (internacionalização)

- **url_launcher**:
  - Abrir links em navegador externo
  - Necessário para abrir os LinkItems

---

### 3. Models (Espelhos dos DTOs da API)

Implementados 6 models que espelham os DTOs do backend:

#### **User** (models/user.dart)
- Dados básicos do usuário autenticado
- Campos: id, email, username
- `fromJson` / `toJson` para serialização

#### **Profile** (models/profile.dart)
- Perfil completo do usuário
- Campos: id, userId, username, displayName, bio, profilePictureUrl
- Método `copyWith` para imutabilidade

#### **Collection** (models/collection.dart)
- Coleção de links
- Campos: id, title, description, ownerId, ownerUsername, isPublic, createdAt, linkItemsCount
- Campo opcional `linkItems` (apenas em detail view)

#### **LinkItem** (models/link_item.dart)
- Item individual dentro de uma coleção
- Campos: id, title, url, description, collectionId, createdAt

#### **Friendship** (models/friendship.dart)
- Relacionamento de amizade entre usuários
- Enum `FriendshipStatus` (pending, accepted, declined, blocked)
- Campos completos de ambos os usuários (requester e addressee)

#### **AuthResponse** (models/auth_response.dart)
- Resposta do login/register
- Campos: token, userId, username, email

**Por que models separados?**
- **Type-safety**: Erros detectados em compile-time
- **Autocomplete**: IDE ajuda com sugestões
- **Manutenibilidade**: Fácil adicionar validações
- **Serialização**: JSON ↔ Dart objects

---

### 4. Services (Camada de Negócio)

Implementados 6 services que encapsulam a lógica:

#### **StorageService** (services/storage_service.dart)
- Wrapper ao redor de SharedPreferences
- Métodos: saveToken, getToken, saveUserData, clearAll
- Abstrai detalhes de implementação

**Por que abstrair SharedPreferences?**
- Fácil trocar implementação (ex: Hive, secure_storage)
- Testes mais fáceis (mock simples)
- Interface limpa

#### **ApiClient** (services/api_client.dart)
- Cliente HTTP centralizado com Dio
- **Interceptor automático**: Adiciona token JWT em todas as requisições
- **Tratamento de 401**: Limpa storage quando token expira
- Métodos genéricos: get, post, put, delete

**Por que interceptor?**
```dart
onRequest: (options, handler) {
  final token = _storage.getToken();
  if (token != null) {
    options.headers['Authorization'] = 'Bearer $token';
  }
  return handler.next(options);
}
```
- Evita repetir código em todo service
- Token sempre atualizado
- Fácil adicionar outros headers globais

#### **AuthService** (services/auth_service.dart)
- `register()`: Cria conta e salva credenciais
- `login()`: Autentica e salva token
- `logout()`: Limpa storage
- `getCurrentUser()`: Recupera usuário salvo
- `isLoggedIn`: Getter booleano

#### **ProfileService** (services/profile_service.dart)
- `getMyProfile()`: Perfil do usuário autenticado
- `getProfileByUsername()`: Perfil público de outro usuário
- `updateMyProfile()`: Atualiza displayName e bio
- `searchProfiles()`: Busca por username ou nome

#### **CollectionService** (services/collection_service.dart)
- `createCollection()`: Nova coleção
- `getMyCollections()`: Todas as coleções do usuário
- `getUserPublicCollections()`: Coleções públicas de outro usuário
- `getCollectionById()`: Detalhes completos (com links)
- `addLinkItem()`: Adiciona link à coleção
- `shareCollection()`: Compartilha com amigo

#### **FriendshipService** (services/friendship_service.dart)
- `sendFriendRequest()`: Envia pedido
- `getFriendRequests()`: Pedidos pendentes
- `acceptFriendRequest()`: Aceita pedido
- `declineFriendRequest()`: Recusa pedido
- `getFriends()`: Lista de amigos
- `removeFriend()`: Remove amizade

**Por que separar services?**
- **Single Responsibility**: Cada service tem um propósito
- **Reutilização**: Múltiplas telas usam o mesmo service
- **Testabilidade**: Mock de services é simples
- **Manutenção**: Mudanças na API isoladas nos services

---

### 5. Providers Riverpod (State Management)

Implementados 5 arquivos de providers:

#### **service_providers.dart**
Providers para injeção de dependências:
```dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {...});
final storageServiceProvider = Provider<StorageService>((ref) {...});
final apiClientProvider = Provider<ApiClient>((ref) {...});
final authServiceProvider = Provider<AuthService>((ref) {...});
// ...
```

**Por que Provider (não StateProvider)?**
- Services são singleton (mesma instância em todo app)
- Não mudam durante execução
- Permitem injeção de dependências limpa

#### **auth_provider.dart**
```dart
final currentUserProvider = StateProvider<User?>(...);
final isLoggedInProvider = Provider<bool>(...);
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>(...);
```

- **StateProvider**: Para estado simples (currentUser)
- **StateNotifier**: Para operações complexas (login, register, logout)
- **AsyncValue**: Representa estados de loading/data/error

**Por que StateNotifier?**
```dart
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  Future<void> login(...) async {
    state = const AsyncValue.loading(); // Loading state
    try {
      final user = await authService.login(...);
      state = AsyncValue.data(user); // Success state
    } catch (e, stack) {
      state = AsyncValue.error(e, stack); // Error state
    }
  }
}
```
- Gerencia estados complexos (loading, success, error)
- Evita race conditions
- Notifica UI automaticamente

#### **profile_provider.dart**
```dart
final myProfileProvider = FutureProvider<Profile>(...);
final profileSearchProvider = StateProvider<String>(...);
final searchResultsProvider = FutureProvider<List<Profile>>(...);
```

**Por que FutureProvider?**
- Async data loading automático
- Cache integrado
- Refresh fácil (`ref.refresh(provider)`)

#### **collection_provider.dart**
```dart
final myCollectionsProvider = FutureProvider<List<Collection>>(...);
final collectionDetailProvider = FutureProvider.family<Collection, int>(...);
```

**Por que `.family`?**
- Provider parametrizado (collectionId)
- Cache por parâmetro
- Múltiplas instâncias simultâneas

#### **friendship_provider.dart**
```dart
final myFriendsProvider = FutureProvider<List<Friendship>>(...);
final friendRequestsProvider = FutureProvider<List<Friendship>>(...);
```

**Por que Riverpod > setState?**
- Estado global (acessível em qualquer widget)
- Rebuild apenas widgets que usam o provider
- Fácil invalidar cache (`ref.invalidate`)
- Testável (mock de providers)

---

### 6. Telas Implementadas

#### **Auth Screens**

**LoginScreen** (screens/auth/login_screen.dart)
- Form com validação (email, password)
- Loading state durante login
- Navegação para RegisterScreen
- Redirecionamento automático para HomeScreen após login

**RegisterScreen** (screens/auth/register_screen.dart)
- Form com 4 campos (email, username, password, confirmPassword)
- Validações:
  - Email válido
  - Username mínimo 3 caracteres
  - Password mínimo 6 caracteres
  - Confirmação de senha
- Loading state

**Por que validação no client-side?**
- UX melhor (feedback imediato)
- Reduz chamadas inválidas à API
- Backend AINDA valida (segurança em camadas)

---

#### **Home Screen**

**HomeScreen** (screens/home/home_screen.dart)
- BottomNavigationBar com 4 tabs
- State local para `_currentIndex`
- Renderiza tab ativa

**FeedTab** (screens/home/feed_tab.dart)
- Placeholder para feature bônus
- Mensagem informativa
- Preparado para implementação futura

**Por que BottomNavigationBar?**
- Padrão Material Design
- Familiar para usuários mobile
- Fácil navegação entre seções principais

---

#### **Collections Screens**

**MyCollectionsTab** (screens/collections/my_collections_tab.dart)
- Lista de coleções do usuário (`myCollectionsProvider`)
- Indicador de público/privado
- Contador de links
- Data de criação formatada (intl)
- RefreshIndicator (pull-to-refresh)
- Navegação para CollectionDetailScreen
- Botão FAB para criar coleção

**CollectionDetailScreen** (screens/collections/collection_detail_screen.dart)
- Detalhes da coleção
- Lista de LinkItems
- Botões condicionais (apenas para owner):
  - **Add Link**: Navega para AddLinkItemScreen
  - **Share**: Navega para ShareCollectionScreen
- Abrir link externo (url_launcher)
- RefreshIndicator

**AddCollectionScreen** (screens/collections/add_collection_screen.dart)
- Form: title, description
- SwitchListTile para IsPublic
- Invalidação do provider após criar (`ref.invalidate(myCollectionsProvider)`)

**AddLinkItemScreen** (screens/collections/add_link_item_screen.dart)
- Form: title, URL, description
- Validação de URL (Uri.tryParse)
- Pop após adicionar (volta para detail)

**ShareCollectionScreen** (screens/collections/share_collection_screen.dart)
- Lista de amigos (`myFriendsProvider`)
- Botão "Share" para cada amigo
- Chama API `/collections/{id}/share/{friendId}`

**Por que invalidar providers?**
```dart
ref.invalidate(myCollectionsProvider);
```
- Força re-fetch da API
- Atualiza UI automaticamente
- Evita estado desatualizado

---

#### **Friends Screens**

**FriendsTab** (screens/friends/friends_tab.dart)
- TabBar com 2 sub-tabs:
  - **My Friends**: Lista de amigos aceitos
  - **Requests**: Pedidos pendentes
- Botão "Add Friend" no AppBar

**_MyFriendsTab**:
- Lista de amizades (`myFriendsProvider`)
- Determina qual usuário é o "friend" (pode ser requester OU addressee)
- PopupMenu para remover amigo (com confirmação)
- RefreshIndicator

**_FriendRequestsTab**:
- Lista de pedidos pendentes (`friendRequestsProvider`)
- Botões aceitar/recusar
- Invalidação de ambos providers após aceitar (friends + requests)

**SearchFriendsScreen** (screens/friends/search_friends_screen.dart)
- TextField de busca
- `profileSearchProvider` (StateProvider<String>)
- `searchResultsProvider` (FutureProvider reativo)
- Lista de resultados com botão "Add"
- Tracking local de pedidos enviados (Set<int>)
- Chip "Sent" após enviar pedido

**Por que determinar o "friend" dinamicamente?**
```dart
final iAmRequester = friendship.requesterId == currentUser?.id;
final friendUsername = iAmRequester
    ? friendship.addresseeUsername
    : friendship.requesterUsername;
```
- Amizade é bidirecional (pode estar em qualquer direção)
- UI sempre mostra o "outro" usuário
- Lógica consistente

---

#### **Profile Screens**

**ProfileTab** (screens/profile/profile_tab.dart)
- Exibe dados de `myProfileProvider`
- CircleAvatar com inicial ou foto
- DisplayName e @username
- Bio
- Botão "Edit Profile"
- Botão "Logout" (com confirmação)
- RefreshIndicator

**EditProfileScreen** (screens/profile/edit_profile_screen.dart)
- Form: displayName, bio
- Username read-only (não pode alterar)
- Botão placeholder para foto (Módulo 4)
- Invalidação de `myProfileProvider` após salvar

**Por que RefreshIndicator em várias telas?**
- Pull-to-refresh é esperado em apps mobile
- Atualiza dados sem fechar/reabrir tela
- UX padrão do Material Design

---

### 7. Main.dart e Inicialização

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const LinkShareApp(),
    ),
  );
}
```

**ProviderScope**:
- Root do Riverpod (obrigatório)
- Overrides permitem injetar dependências
- Necessário para async init (SharedPreferences)

**AuthChecker**:
```dart
class AuthChecker extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    return isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}
```
- Verifica estado de auth ao iniciar
- Redireciona automaticamente
- Reage a mudanças em `isLoggedInProvider`

**Por que async initialization?**
- SharedPreferences requer await
- Plugins nativos precisam inicialização
- `ensureInitialized()` garante que Flutter está pronto

---

### 8. Tema e UI

Configuração global de tema:

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  useMaterial3: true,
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 0,
  ),
  cardTheme: CardTheme(
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  // ...
)
```

**Por que Material 3?**
- Design moderno
- Melhor acessibilidade
- Animações suaves
- Cores dinâmicas (seed color)

---

## 📁 Arquivos Criados

### Estrutura Completa:

```
mobile/linkshare_app/
├── lib/
│   ├── models/
│   │   ├── user.dart
│   │   ├── profile.dart
│   │   ├── collection.dart
│   │   ├── link_item.dart
│   │   ├── friendship.dart
│   │   └── auth_response.dart
│   │
│   ├── services/
│   │   ├── storage_service.dart
│   │   ├── api_client.dart
│   │   ├── auth_service.dart
│   │   ├── profile_service.dart
│   │   ├── collection_service.dart
│   │   └── friendship_service.dart
│   │
│   ├── providers/
│   │   ├── service_providers.dart
│   │   ├── auth_provider.dart
│   │   ├── profile_provider.dart
│   │   ├── collection_provider.dart
│   │   └── friendship_provider.dart
│   │
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   └── feed_tab.dart
│   │   ├── collections/
│   │   │   ├── my_collections_tab.dart
│   │   │   ├── collection_detail_screen.dart
│   │   │   ├── add_collection_screen.dart
│   │   │   ├── add_link_item_screen.dart
│   │   │   └── share_collection_screen.dart
│   │   ├── friends/
│   │   │   ├── friends_tab.dart
│   │   │   └── search_friends_screen.dart
│   │   └── profile/
│   │       ├── profile_tab.dart
│   │       └── edit_profile_screen.dart
│   │
│   └── main.dart
│
├── pubspec.yaml
├── analysis_options.yaml
├── .gitignore
└── README.md

docs/
└── modulo2.md (este arquivo)
```

**Total: 38 arquivos criados**

---

## 🔑 Decisões Técnicas Importantes

### 1. Por que Flutter?
- **Cross-platform**: Um código para iOS e Android
- **Performance**: Renderização nativa (60fps)
- **Hot reload**: Desenvolvimento rápido
- **Material Design**: Widgets prontos e bonitos
- **Comunidade**: Milhares de packages no pub.dev

### 2. Por que Riverpod?
- **Type-safe**: Erros em compile-time
- **Sem BuildContext**: Providers acessíveis em qualquer lugar
- **Auto-dispose**: Gerencia lifecycle automaticamente
- **Testing**: Mock de providers é trivial
- **DevTools**: Inspeção em tempo real

Comparação com outras soluções:
| Feature | Riverpod | Provider | Bloc | GetX |
|---------|----------|----------|------|------|
| Type-safe | ✅ | ⚠️ | ✅ | ❌ |
| Boilerplate | Baixo | Médio | Alto | Baixo |
| Testing | Excelente | Bom | Excelente | Ruim |
| Learning curve | Médio | Fácil | Difícil | Fácil |

### 3. Por que Dio?
```dart
// Interceptor automático
dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) {
    options.headers['Authorization'] = 'Bearer $token';
    return handler.next(options);
  },
));
```
- Interceptors nativos
- Melhor que `http` package
- Cancelamento de requests
- Upload/download progress

### 4. Arquitetura em Camadas

```
┌─────────────────────────────────────┐
│  UI (Screens/Widgets)               │
├─────────────────────────────────────┤
│  State Management (Providers)       │
├─────────────────────────────────────┤
│  Business Logic (Services)          │
├─────────────────────────────────────┤
│  Data (Models, API Client)          │
└─────────────────────────────────────┘
```

**Benefícios**:
- Separação de responsabilidades
- Testabilidade (cada camada isolada)
- Manutenibilidade (mudanças localizadas)
- Reutilização (services usados por múltiplos providers)

### 5. Tratamento de Erros

Em toda tela com async data:
```dart
asyncProvider.when(
  data: (data) => /* UI com dados */,
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => /* UI de erro com retry */,
)
```

**Por que `.when()`?**
- Força tratar todos os casos
- UI consistente (loading, error, success)
- Evita NPE (null pointer exceptions)

---

## 🚀 Como Executar

### Pré-requisitos:
1. Flutter SDK instalado (>= 3.0.0)
2. Android Studio / VS Code
3. Backend API rodando (Módulo 1)

### Passos:

1. **Instalar dependências**:
```bash
cd mobile/linkshare_app
flutter pub get
```

2. **Configurar URL da API**:
Edite `lib/services/api_client.dart`:
```dart
static const String baseUrl = 'http://10.0.2.2:8080/api'; // Android Emulator
// static const String baseUrl = 'http://localhost:8080/api'; // iOS Simulator
// static const String baseUrl = 'http://SEU-IP:8080/api'; // Dispositivo físico
```

**Importante**:
- **Android Emulator**: Use `10.0.2.2` (alias para localhost do host)
- **iOS Simulator**: Use `localhost`
- **Dispositivo físico**: Use IP do computador (ex: `192.168.1.10`)

3. **Rodar o app**:
```bash
flutter run
```

Ou selecione o dispositivo no VS Code/Android Studio e pressione F5.

---

## 🧪 Fluxo de Teste Manual

### 1. Autenticação

```
1. Abrir app → LoginScreen
2. Clicar "Don't have an account? Register"
3. Preencher: email=test@test.com, username=testuser, password=123456
4. Submit → Criar conta
5. Verificar redirecionamento para HomeScreen
6. Fazer logout
7. Login novamente com mesmas credenciais
```

### 2. Coleções

```
1. Na tab "Collections", clicar botão "+"
2. Criar coleção: title="Meus Artigos", isPublic=true
3. Verificar coleção aparece na lista
4. Tocar na coleção → CollectionDetailScreen
5. Clicar "Add Link"
6. Adicionar: title="Flutter Docs", url="https://flutter.dev"
7. Verificar link aparece na lista
8. Tocar no link → Abrir navegador externo
```

### 3. Amigos

```
1. Criar segunda conta (outro emulador ou register/logout/register)
2. Na tab "Friends", clicar botão "+"
3. Buscar primeiro usuário por username
4. Clicar "Add" → Enviar pedido
5. Fazer login com primeira conta
6. Tab "Friends" → Sub-tab "Requests"
7. Verificar pedido pendente
8. Aceitar pedido
9. Verificar amigo aparece em "My Friends"
```

### 4. Compartilhar Coleção

```
1. Na tab "Collections", entrar em uma coleção
2. Clicar botão "Share"
3. Selecionar amigo
4. Clicar "Share"
5. Fazer login com conta do amigo
6. Tab "Collections" → Verificar coleção compartilhada aparece
```

### 5. Perfil

```
1. Tab "Profile"
2. Clicar "Edit Profile"
3. Alterar DisplayName para "João Silva"
4. Alterar Bio para "Desenvolvedor Flutter"
5. Salvar
6. Verificar mudanças refletidas
7. Pull-to-refresh → Verificar dados persistem
```

---

## 📊 Endpoints da API Utilizados

### Auth:
- ✅ `POST /api/auth/register`
- ✅ `POST /api/auth/login`

### Profiles:
- ✅ `GET /api/profiles/me`
- ✅ `GET /api/profiles/{username}`
- ✅ `PUT /api/profiles/me`
- ✅ `GET /api/profiles/search?query={query}`

### Friends:
- ✅ `POST /api/friends/request/{userId}`
- ✅ `GET /api/friends/requests`
- ✅ `PUT /api/friends/requests/{requestId}/accept`
- ✅ `DELETE /api/friends/requests/{requestId}`
- ✅ `GET /api/friends`
- ✅ `DELETE /api/friends/{friendId}`

### Collections:
- ✅ `POST /api/collections`
- ✅ `GET /api/collections/me`
- ✅ `GET /api/collections/user/{username}`
- ✅ `GET /api/collections/{collectionId}`
- ✅ `POST /api/collections/{collectionId}/items`
- ✅ `POST /api/collections/{collectionId}/share/{friendId}`

**Cobertura: 100% dos endpoints do Módulo 1!**

---

## ✅ Checklist do Módulo 2

- [x] Estrutura do projeto Flutter
- [x] Configuração pubspec.yaml (dio, riverpod, shared_preferences)
- [x] Models (6 models)
- [x] Services (6 services)
- [x] Providers Riverpod (5 arquivos)
- [x] LoginScreen e RegisterScreen
- [x] HomeScreen com BottomNavigationBar (4 tabs)
- [x] Tab "Feed" (placeholder para bônus)
- [x] Tab "Minhas Coleções" (lista + detail + add + share)
- [x] Tab "Amigos" (sub-tabs: friends + requests + search)
- [x] Tab "Perfil" (view + edit)
- [x] Integração completa com API
- [x] Persistência de token (SharedPreferences)
- [x] Tratamento de erros (AsyncValue.when)
- [x] Loading states
- [x] Pull-to-refresh
- [x] Validação de forms
- [x] Navegação entre telas
- [x] Tema Material 3

---

## 🔜 Próximos Passos (Módulo 3)

- Docker e Docker Compose
- Dockerfile para o backend .NET
- docker-compose.yml orquestrando API + PostgreSQL
- Volumes para persistência de dados
- Variáveis de ambiente

---

## 📝 Notas Adicionais

### Melhorias Futuras (Não implementadas no Módulo 2):

1. **Widgets Reutilizáveis**:
   - ErrorWidget customizado
   - LoadingWidget customizado
   - EmptyStateWidget

2. **Validações Mais Robustas**:
   - Email regex completo
   - Username sem caracteres especiais
   - URL validation mais rigorosa

3. **UX Enhancements**:
   - Skeleton screens (em vez de CircularProgressIndicator)
   - Animações de transição
   - Snackbar customizada

4. **Performance**:
   - Pagination (infinit scroll)
   - Image caching
   - Debounce em search

5. **Offline Support**:
   - Cache local (Drift - Módulo 5)
   - Fila de sincronização
   - Indicador de conectividade

**Estas features serão implementadas nos módulos futuros!**

---

**Módulo 2 completo! 🎉**
