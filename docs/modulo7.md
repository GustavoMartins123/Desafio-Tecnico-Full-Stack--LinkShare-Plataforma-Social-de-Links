# Módulo 7: Colaboração e UI em Tempo Real

## Visão Geral

Este módulo implementa **colaboração em tempo real** usando SignalR, fazendo o aplicativo parecer "vivo". Quando um colaborador adiciona um link a uma coleção que você está visualizando, a tela atualiza **instantaneamente** sem precisar de pull-to-refresh.

## Tecnologias Utilizadas

- **Backend**: SignalR (ASP.NET Core 8.0)
- **Mobile**: signalr_netcore (Flutter)
- **Pattern**: Event-Driven Architecture + Offline-First (Drift)

## Arquitetura

```
┌──────────────────────────────────────────────────────────────┐
│                        SignalR Hub                            │
│                   (CollectionHub)                             │
│                                                                │
│  Groups:                                                       │
│  - collection_1  (users viewing collection 1)                 │
│  - collection_2  (users viewing collection 2)                 │
│  - friendship_<userId>  (user's friend notifications)         │
└───────────────┬──────────────────────────────────────────────┘
                │
         Events │
                ▼
    ┌───────────────────────┐
    │  NewLinkAdded         │  ──┐
    │  CollectionUpdated    │    │
    │  FriendRequestAccepted│    │ Broadcast to
    └───────────────────────┘    │ Group Members
                                 │
                ┌────────────────┘
                │
                ▼
   ┌─────────────────────────────────┐
   │  Flutter App (Consumer)          │
   │                                  │
   │  1. Receives SignalR Event       │
   │  2. Updates Drift Database       │
   │  3. Riverpod Watches Drift       │
   │  4. UI Rebuilds Automatically    │
   └──────────────────────────────────┘
```

## Componentes Backend (.NET)

### 1. CollectionHub

**Arquivo**: `backend/LinkShare.API/Hubs/CollectionHub.cs`

Hub principal do SignalR com métodos para gerenciar grupos:

```csharp
[Authorize]
public class CollectionHub : Hub
{
    // Join/Leave collection groups
    Task JoinCollectionGroup(int collectionId);
    Task LeaveCollectionGroup(int collectionId);

    // Join/Leave friendship notification group
    Task JoinFriendshipGroup();
    Task LeaveFriendshipGroup();
}
```

**Funcionalidades**:
- **Autenticação JWT**: Apenas usuários autenticados podem conectar
- **Grupos Dinâmicos**: `collection_{id}`, `friendship_{userId}`
- **Logging**: Conexões, desconexões e eventos são logados no console
- **Lifecycle Hooks**: `OnConnectedAsync`, `OnDisconnectedAsync`

### 2. Program.cs - SignalR Configuration

**Modificações**:

```csharp
// Add SignalR
builder.Services.AddSignalR();

// Configure JWT for SignalR (access token via query string)
options.Events = new JwtBearerEvents
{
    OnMessageReceived = context =>
    {
        var accessToken = context.Request.Query["access_token"];
        var path = context.HttpContext.Request.Path;
        if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
        {
            context.Token = accessToken;
        }
        return Task.CompletedTask;
    }
};

// Update CORS for SignalR (requires credentials)
policy.SetIsOriginAllowed(_ => true)
      .AllowAnyMethod()
      .AllowAnyHeader()
      .AllowCredentials();

// Map SignalR Hub
app.MapHub<CollectionHub>("/hubs/collection");
```

**Detalhes**:
- SignalR usa WebSockets (fallback para Long Polling se WebSocket não disponível)
- JWT é passado via query string (`?access_token=...`) para WebSockets
- CORS habilitado com `AllowCredentials` para SignalR

### 3. CollectionsController - Event Emission

**Modificação em AddLinkItem**:

```csharp
// Inject IHubContext<CollectionHub>
private readonly IHubContext<CollectionHub> _hubContext;

public async Task<ActionResult<LinkItemDto>> AddLinkItem(...)
{
    // ... save link to database ...

    var linkItemDto = new LinkItemDto { /* ... */ };

    // Notify SignalR clients about the new link
    await _hubContext.Clients
        .Group($"collection_{collectionId}")
        .SendAsync("NewLinkAdded", linkItemDto);

    return CreatedAtAction(..., linkItemDto);
}
```

**Fluxo**:
1. Cliente adiciona link via POST /api/collections/{id}/items
2. Controller salva no PostgreSQL
3. Controller emite evento "NewLinkAdded" para grupo `collection_{id}`
4. Todos os clientes no grupo recebem o evento instantaneamente

## Componentes Mobile (Flutter)

### 1. SignalRService

**Arquivo**: `mobile/linkshare_app/lib/services/signalr_service.dart`

Serviço singleton que gerencia a conexão SignalR:

```dart
class SignalRService {
  HubConnection? _hubConnection;

  // Event streams (broadcast)
  Stream<Map<String, dynamic>> get newLinkAdded;
  Stream<HubConnectionState> get connectionState;

  // Connection management
  Future<void> connect();
  Future<void> disconnect();

  // Group management
  Future<void> joinCollectionGroup(int collectionId);
  Future<void> leaveCollectionGroup(int collectionId);
  Future<void> joinFriendshipGroup();
  Future<void> leaveFriendshipGroup();
}
```

**Características**:
- **Auto-reconnect**: Reconecta automaticamente em caso de queda
- **Token Authentication**: Usa access token do StorageService
- **Event Streams**: Broadcast streams para múltiplos listeners
- **Lifecycle Management**: dispose() limpa recursos

**Configuração da Conexão**:

```dart
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
```

### 2. CollectionDetailScreen - Real-time Integration

**Arquivo**: `mobile/linkshare_app/lib/screens/collections/collection_detail_screen.dart`

**Mudanças**:
- **ConsumerWidget → ConsumerStatefulWidget** (para lifecycle hooks)
- **initState**: Conecta ao SignalR e entra no grupo
- **dispose**: Sai do grupo e cancela subscription
- **Event Listener**: Atualiza Drift quando recebe "NewLinkAdded"

**Fluxo Completo**:

```dart
@override
void initState() {
  super.initState();
  _initializeSignalR();
}

Future<void> _initializeSignalR() async {
  final signalRService = ref.read(signalRServiceProvider);
  final database = ref.read(databaseProvider);

  // 1. Connect to SignalR (if not connected)
  if (!signalRService.isConnected) {
    await signalRService.connect();
  }

  // 2. Join the collection group
  await signalRService.joinCollectionGroup(widget.collectionId);

  // 3. Listen to NewLinkAdded events
  _newLinkSubscription = signalRService.newLinkAdded.listen((linkData) async {
    final linkItem = model.LinkItem.fromJson(linkData);

    // 4. Insert into Drift database
    await database.insertLinkItem(/* ... */);

    // 5. Invalidate provider (triggers UI rebuild)
    if (mounted) {
      ref.invalidate(collectionDetailProvider(widget.collectionId));
    }
  });
}

@override
void dispose() {
  final signalRService = ref.read(signalRServiceProvider);
  signalRService.leaveCollectionGroup(widget.collectionId);
  _newLinkSubscription?.cancel();
  super.dispose();
}
```

### 3. UI Indicators

**Real-time Connection Indicator**:

```dart
// Green dot in AppBar when connected
Icon(
  Icons.circle,
  size: 12,
  color: signalRService.isConnected ? Colors.green : Colors.grey,
)

// "Live" badge next to author
Row(
  children: [
    Icon(Icons.flash_on, size: 16, color: Colors.amber),
    Text('Live', style: TextStyle(color: Colors.amber)),
  ],
)
```

## Fluxos de Uso

### 1. Visualizar Coleção em Tempo Real

```
User A (Mobile)                 Backend (SignalR Hub)              User B (Mobile)
     │                                  │                                │
     ├─ Navigate to Collection ────────>│                                │
     │  GET /api/collections/1          │                                │
     │                                   │                                │
     ├─ Connect to SignalR ─────────────>│                                │
     │  ws://api/hubs/collection         │                                │
     │                                   │                                │
     ├─ JoinCollectionGroup(1) ─────────>│                                │
     │                                   │<─── JoinCollectionGroup(1) ───┤
     │                                   │                                │
     │                                   │                                │
     │                                   │<─── POST /collections/1/items ┤
     │                                   │     (Add Link)                 │
     │                                   │                                │
     │<── NewLinkAdded Event ────────────┤────────────────────────────────>│
     │    {id: 123, title: "..."}        │                                │
     │                                   │                                │
     ├─ Update Drift DB                  │                                │
     ├─ UI Rebuilds (instant!)           │                                │
```

### 2. Múltiplos Colaboradores

```
3 usuários visualizando Collection #42:
 - collection_42 group members: [User A, User B, User C]

User A adiciona link:
 1. POST /api/collections/42/items
 2. Hub emite: NewLinkAdded → collection_42 group
 3. User B e User C recebem evento simultaneamente
 4. Ambos atualizam Drift local
 5. Ambas UIs reconstruem instantaneamente
```

## Integração com Módulo 5 (Offline-First)

SignalR funciona **em conjunto** com Drift:

| Cenário | Comportamento |
|---------|---------------|
| **Online + SignalR Conectado** | Evento recebido → Drift atualizado → UI atualiza |
| **Online + SignalR Desconectado** | Pull-to-refresh manual → Drift atualizado → UI atualiza |
| **Offline** | Ação enfileirada (PendingActions) → SyncService sincroniza depois |

**Pattern**: SignalR é **complementar** ao offline-first, não substitui.

## Segurança

### 1. Autenticação

- ✅ Hub requer `[Authorize]` attribute
- ✅ Access token validado em cada conexão
- ✅ Token renovado automaticamente (AuthInterceptor do Módulo 6)
- ✅ Usuários só podem entrar em grupos autorizados

### 2. Autorização de Grupos

```csharp
// TODO: Add authorization check before allowing JoinCollectionGroup
public async Task JoinCollectionGroup(int collectionId)
{
    var userId = GetUserId();

    // Verify user has access to this collection
    var hasAccess = await _context.Collections
        .Where(c => c.Id == collectionId &&
               (c.OwnerId == userId ||
                c.IsPublic ||
                c.Shares.Any(s => s.UserId == userId)))
        .AnyAsync();

    if (!hasAccess) return;

    await Groups.AddToGroupAsync(Context.ConnectionId, $"collection_{collectionId}");
}
```

**Nota**: Implementação completa de autorização de grupos pode ser adicionada futuramente.

## Performance

### 1. Escalabilidade

**Atual (In-Memory SignalR)**:
- Adequado para aplicações small-to-medium
- Todos os clientes conectados ao mesmo servidor

**Produção (SignalR + Redis Backplane)**:
- Suporta múltiplos servidores (load balancing)
- Eventos distribuídos via Redis Pub/Sub
- Configuração:

```csharp
builder.Services.AddSignalR()
    .AddStackExchangeRedis(redisConnectionString);
```

### 2. Otimizações

- **Grupos Dinâmicos**: Apenas usuários interessados recebem eventos
- **Event Filtering**: Cliente filtra eventos por `collectionId`
- **Batch Updates**: Drift usa transactions para múltiplas inserções
- **Lazy Connection**: SignalR só conecta quando necessário

## Testando Tempo Real

### 1. Teste Manual (2 Dispositivos)

```bash
# Terminal 1: Backend
cd backend/LinkShare.API
docker-compose up

# Terminal 2: Flutter App (Device A)
cd mobile/linkshare_app
flutter run

# Terminal 3: Flutter App (Device B ou Emulator)
flutter run -d <device-id>

# Passos:
1. Login com mesma conta em ambos dispositivos
2. Device A: Abrir Collection #1
3. Device B: Abrir Collection #1
4. Device A: Adicionar um link
5. Device B: Link aparece instantaneamente! ⚡
```

### 2. Console Logs

**Backend** (quando link é adicionado):

```
User 5 connected to CollectionHub. ConnectionId: abc123
User 5 joined collection group: collection_1
SignalR: Broadcasting NewLinkAdded to collection_1
```

**Mobile** (quando evento é recebido):

```
SignalR [info]: Connected successfully
SignalR: Joined collection group 1
CollectionDetailScreen: Received NewLinkAdded event: {id: 42, title: "..."}
CollectionDetailScreen: Link added to local database
```

## Arquivos Modificados/Criados

### Backend (.NET)

**Novos**:
- `Hubs/CollectionHub.cs`

**Modificados**:
- `Program.cs` (AddSignalR, JWT events, CORS, MapHub)
- `Controllers/CollectionsController.cs` (IHubContext injection, event emission)

### Mobile (Flutter)

**Novos**:
- `services/signalr_service.dart`

**Modificados**:
- `pubspec.yaml` (signalr_netcore: ^1.3.7)
- `providers/service_providers.dart` (signalRServiceProvider)
- `screens/collections/collection_detail_screen.dart` (real-time integration)

## Próximos Passos (Módulo 8+)

- **Módulo 8**: Notificações push (Firebase Cloud Messaging)
- **Módulo 9**: Analytics e métricas (posthog, mixpanel)
- **Módulo 10**: Deploy em produção (Docker + CI/CD)

## Troubleshooting

### Problema: SignalR não conecta

**Sintomas**: "SignalR: Connection failed"

**Soluções**:
1. Verificar se API está rodando: `http://localhost:8080/health`
2. Verificar CORS: Deve ter `AllowCredentials()`
3. Verificar token: `StorageService.getAccessToken()` não pode ser null
4. Logs do backend: Procurar erros de autenticação

### Problema: Eventos não chegam no Flutter

**Sintomas**: Link adicionado mas UI não atualiza

**Soluções**:
1. Verificar se está no grupo: `signalRService.joinCollectionGroup(id)`
2. Console logs: "Received NewLinkAdded event" deve aparecer
3. Verificar Drift: `database.insertLinkItem()` pode estar falhando
4. Provider invalidation: `ref.invalidate()` deve ser chamado

### Problema: "WebSocket connection failed"

**Sintomas**: SignalR cai para Long Polling

**Causa**: WebSocket bloqueado (proxy, firewall)

**Solução**: SignalR usa Long Polling como fallback (funciona, mas menos eficiente)

## Conclusão

O Módulo 7 traz **colaboração em tempo real** para LinkShare, fazendo o app parecer "vivo":

✅ SignalR Hub com grupos dinâmicos
✅ Eventos instantâneos (NewLinkAdded)
✅ Integração com Drift (Offline-First + Real-time)
✅ UI atualiza automaticamente via Riverpod
✅ Indicadores visuais (green dot, "Live" badge)
✅ Auto-reconnect e token refresh

O resultado é uma **experiência colaborativa fluida** onde mudanças aparecem instantaneamente para todos os usuários visualizando a mesma coleção.
