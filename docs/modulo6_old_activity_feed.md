# Módulo 6 - Feed de Atividades Social

## Descrição

Este módulo implementa um feed de atividades que exibe as ações recentes dos amigos do usuário, criando uma timeline social que aumenta o engajamento e a descoberta de conteúdo na plataforma.

## Funcionalidades Implementadas

### 1. Timeline de Atividades
- Exibir atividades recentes de amigos em ordem cronológica
- Três tipos de atividades rastreadas:
  - **Link Adicionado**: Quando um amigo adiciona um novo link
  - **Coleção Criada**: Quando um amigo cria uma nova coleção
  - **Coleção Compartilhada**: Quando um amigo compartilha uma coleção com você

### 2. Agregação Inteligente
- Combina atividades de múltiplas fontes (coleções, links, compartilhamentos)
- Ordena por timestamp (mais recente primeiro)
- Limita resultados para performance (máximo 100 itens)
- Aplica filtros de privacidade automaticamente

### 3. Interface Rica
- Cards visuais diferenciados por tipo de atividade
- Avatar do usuário com foto de perfil
- Timestamps relativos ("2h ago", "5d ago")
- Links clicáveis para abrir URLs externas
- Navegação para detalhes da coleção
- Pull-to-refresh para atualizar feed

### 4. Controle de Privacidade
- Apenas mostra atividades de coleções públicas ou compartilhadas com o usuário
- Respeita permissões de amizade
- Não expõe coleções privadas de amigos

## Implementação

### Backend (.NET 8 API)

#### 1. DTOs de Feed

**Arquivo:** `backend/LinkShare.API/DTOs/Feed/ActivityType.cs`

```csharp
public enum ActivityType
{
    LinkAdded,          // 0
    CollectionCreated,  // 1
    CollectionShared    // 2
}
```

**Arquivo:** `backend/LinkShare.API/DTOs/Feed/ActivityDto.cs`

```csharp
public class ActivityDto
{
    public int UserId { get; set; }
    public string Username { get; set; }
    public string UserDisplayName { get; set; }
    public string? UserProfilePictureUrl { get; set; }
    public ActivityType ActivityType { get; set; }
    public DateTime Timestamp { get; set; }

    // Collection-related
    public int? CollectionId { get; set; }
    public string? CollectionTitle { get; set; }
    public bool? CollectionIsPublic { get; set; }

    // Link-related
    public int? LinkItemId { get; set; }
    public string? LinkItemTitle { get; set; }
    public string? LinkItemUrl { get; set; }
    public string? LinkItemDescription { get; set; }
}
```

#### 2. Endpoint de Feed

**Arquivo:** `backend/LinkShare.API/Controllers/FeedController.cs`

##### GET /api/feed/activities?limit=50

Retorna atividades recentes de amigos.

**Parâmetros:**
- `limit` (query, opcional): Número máximo de atividades (1-100, padrão: 50)

**Response:** `List<ActivityDto>`

**Lógica de Agregação:**

1. **Buscar IDs dos amigos:**
   ```csharp
   var friendIds = await _context.Friendships
       .Where(f => (f.RequesterId == userId || f.AddresseeId == userId) &&
                  f.Status == FriendshipStatus.Accepted)
       .Select(f => f.RequesterId == userId ? f.AddresseeId : f.RequesterId)
       .ToListAsync();
   ```

2. **Buscar coleções recentes:**
   - Filtro: Coleções de amigos que sejam públicas OU compartilhadas comigo
   - Inclui: Owner, Profile
   - Ordena: CreatedAt descendente

3. **Buscar links recentes:**
   - Filtro: Links de coleções de amigos (públicas ou compartilhadas)
   - Inclui: Collection, Owner, Profile
   - Ordena: CreatedAt descendente

4. **Buscar compartilhamentos recentes:**
   - Filtro: Coleções compartilhadas comigo por amigos
   - Inclui: Collection, Owner, Profile
   - Ordena: SharedAt descendente
   - Limite: limit / 2 (para não sobrecarregar o feed)

5. **Combinar e ordenar:**
   ```csharp
   var sortedActivities = activities
       .OrderByDescending(a => a.Timestamp)
       .Take(limit)
       .ToList();
   ```

### Frontend (Flutter)

#### 1. Modelo de Dados

**Arquivo:** `mobile/linkshare_app/lib/models/activity.dart`

```dart
enum ActivityType {
  linkAdded,
  collectionCreated,
  collectionShared,
}

class Activity {
  final int userId;
  final String username;
  final String userDisplayName;
  final String? userProfilePictureUrl;
  final ActivityType activityType;
  final DateTime timestamp;

  final int? collectionId;
  final String? collectionTitle;
  final bool? collectionIsPublic;

  final int? linkItemId;
  final String? linkItemTitle;
  final String? linkItemUrl;
  final String? linkItemDescription;

  // fromJson, toJson, _parseActivityType
}
```

#### 2. Serviço de Feed

**Arquivo:** `mobile/linkshare_app/lib/services/feed_service.dart`

```dart
class FeedService {
  final ApiClient _apiClient;

  FeedService(this._apiClient);

  Future<List<Activity>> getFeedActivities({int limit = 50}) async {
    final response = await _apiClient.get(
      '/feed/activities',
      queryParameters: {'limit': limit},
    );
    return (response.data as List)
        .map((json) => Activity.fromJson(json))
        .toList();
  }
}
```

#### 3. Providers

**Arquivo:** `mobile/linkshare_app/lib/providers/service_providers.dart`

```dart
final feedServiceProvider = Provider<FeedService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FeedService(apiClient);
});
```

**Arquivo:** `mobile/linkshare_app/lib/providers/feed_provider.dart`

```dart
final feedActivitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final feedService = ref.watch(feedServiceProvider);
  return await feedService.getFeedActivities(limit: 50);
});
```

#### 4. Tela de Feed

**Arquivo:** `mobile/linkshare_app/lib/screens/home/feed_tab.dart`

**Componentes:**

- **FeedTab (ConsumerWidget):**
  - AppBar com título "Feed" e botão de refresh
  - Usa `feedActivitiesProvider` para dados
  - Estados: Loading, Error, Empty, Data
  - RefreshIndicator para pull-to-refresh
  - ListView com `_ActivityCard`

- **_ActivityCard (StatelessWidget):**
  - Card clicável que navega para CollectionDetailScreen
  - Header com avatar, nome, ação, timestamp
  - Conteúdo diferenciado por tipo de atividade

**Renderização por Tipo:**

1. **Link Adicionado** (`_buildLinkActivity`):
   - Container azul com ícone de link
   - Título do link em negrito
   - Descrição (se houver)
   - URL clicável com ícone `open_in_new`
   - Nome da coleção em itálico

2. **Coleção Criada/Compartilhada** (`_buildCollectionActivity`):
   - Container laranja (criada) ou verde (compartilhada)
   - Ícone público/privado
   - Título da coleção
   - Status: "Public collection" ou "Private collection"
   - Ícone de chevron indicando navegação

**Timestamps Relativos:**

```dart
String _getTimeAgo() {
  final difference = now.difference(activity.timestamp);

  if (difference.inDays > 7) return DateFormat.MMMd().format(timestamp);
  if (difference.inDays > 0) return '${difference.inDays}d ago';
  if (difference.inHours > 0) return '${difference.inHours}h ago';
  if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
  return 'Just now';
}
```

## Estrutura de Arquivos Criados/Modificados

```
backend/LinkShare.API/
├── DTOs/Feed/
│   ├── ActivityType.cs                    (NOVO)
│   └── ActivityDto.cs                     (NOVO)
└── Controllers/
    └── FeedController.cs                  (NOVO)

mobile/linkshare_app/
├── lib/
│   ├── models/
│   │   └── activity.dart                  (NOVO)
│   ├── services/
│   │   └── feed_service.dart              (NOVO)
│   ├── providers/
│   │   ├── service_providers.dart         (MODIFICADO - feedServiceProvider)
│   │   └── feed_provider.dart             (NOVO)
│   └── screens/home/
│       └── feed_tab.dart                  (MODIFICADO - implementação completa)
```

## Fluxos de Uso

### Fluxo 1: Visualizar Feed

```
1. Usuário abre app e está autenticado
2. HomeScreen mostra FeedTab (primeira tab)
3. FeedProvider carrega automaticamente
4. GET /api/feed/activities?limit=50
5. Backend busca amigos do usuário
6. Backend agrega atividades (coleções, links, shares)
7. Backend filtra por privacidade
8. Backend ordena por timestamp
9. Backend retorna List<ActivityDto>
10. Flutter mapeia para List<Activity>
11. UI renderiza cards diferenciados
12. Usuário vê timeline de atividades
```

### Fluxo 2: Atualizar Feed

```
1. Usuário puxa lista para baixo (pull-to-refresh)
2. RefreshIndicator ativa
3. ref.refresh(feedActivitiesProvider.future)
4. Nova requisição ao backend
5. Feed atualiza com novas atividades
6. Indicador desaparece
```

### Fluxo 3: Navegar para Coleção

```
1. Usuário toca em card de atividade
2. Navigator.push → CollectionDetailScreen(collectionId)
3. Usuário vê detalhes da coleção
4. Pode visualizar links (sempre)
5. Pode adicionar links (se tiver permissão)
```

### Fluxo 4: Abrir Link Externo

```
1. Usuário vê atividade de "link adicionado"
2. Toca na URL destacada em azul
3. url_launcher abre navegador externo
4. Link abre fora do app
```

## Tipos de Atividades

### 1. Link Adicionado

**Quando é criado:**
- Um amigo adiciona um link a uma coleção pública
- Um amigo adiciona um link a uma coleção compartilhada com você

**Dados exibidos:**
- Nome do amigo
- Título do link
- Descrição do link (opcional)
- URL do link (clicável)
- Nome da coleção

**Ações possíveis:**
- Clicar no card → Ver coleção
- Clicar na URL → Abrir link no navegador

### 2. Coleção Criada

**Quando é criado:**
- Um amigo cria uma coleção pública
- Um amigo cria uma coleção e compartilha com você

**Dados exibidos:**
- Nome do amigo
- Título da coleção
- Status: Pública ou Privada

**Ações possíveis:**
- Clicar no card → Ver coleção e seus links

### 3. Coleção Compartilhada

**Quando é criado:**
- Um amigo compartilha uma coleção com você

**Dados exibidos:**
- Nome do amigo
- Título da coleção
- Status: Pública ou Privada
- Mensagem: "shared a collection with you"

**Ações possíveis:**
- Clicar no card → Ver coleção compartilhada

## Controle de Privacidade e Segurança

### Backend
- ✅ Apenas amigos aceitos (FriendshipStatus.Accepted)
- ✅ Apenas coleções públicas ou compartilhadas
- ✅ Validação de autenticação JWT
- ✅ Limite de resultados (cap em 100)
- ✅ Filtragem automática de conteúdo privado

### Frontend
- ✅ Navegação segura para coleções
- ✅ Tratamento de erros com feedback visual
- ✅ Estados vazios informativos
- ✅ Links externos abertos em navegador (não dentro do app)

## Performance

**Otimizações implementadas:**

1. **Limit parameter:**
   - Padrão: 50 atividades
   - Máximo: 100 atividades
   - Previne sobrecarga do backend

2. **Shares limitados:**
   - Shares pegam apenas `limit / 2`
   - Evita feed dominado por compartilhamentos

3. **Eager loading:**
   - `Include(c => c.Owner).ThenInclude(o => o.Profile)`
   - Reduz N+1 queries

4. **Ordenação in-memory:**
   - Todas as atividades agregadas e ordenadas uma vez
   - Take(limit) aplicado após ordenação

5. **Caching no cliente:**
   - FutureProvider cacheia automaticamente
   - Refresh manual via pull-to-refresh

## Tecnologias Utilizadas

### Backend
- **ASP.NET Core 8.0** - Framework web
- **Entity Framework Core** - ORM
- **LINQ** - Queries e agregações
- **Include/ThenInclude** - Eager loading

### Frontend
- **Flutter Riverpod** - State management
- **FutureProvider** - Async data fetching
- **RefreshIndicator** - Pull-to-refresh
- **url_launcher** - Abrir links externos
- **intl** - Formatação de datas
- **NetworkImage** - Carregamento de avatares

## Endpoint API

| Método | Endpoint | Descrição | Auth | Params |
|--------|----------|-----------|------|--------|
| GET | `/api/feed/activities` | Feed de atividades | ✅ | `limit` (1-100) |

## Como Usar

### 1. Iniciar Ambiente

```bash
# Backend + Database
cd backend/LinkShare.API
docker-compose up -d

# Flutter App
cd mobile/linkshare_app
flutter run
```

### 2. Visualizar Feed

1. Faça login no app
2. A primeira tab é automaticamente o "Feed"
3. Veja atividades dos seus amigos
4. Puxe para baixo para atualizar

### 3. Interagir com Atividades

1. **Ver Coleção**: Toque em qualquer card
2. **Abrir Link**: Toque na URL azul em atividades de link
3. **Atualizar**: Puxe lista para baixo

## Melhorias Futuras (Fora do Escopo)

- [ ] Paginação infinita (scroll infinito)
- [ ] Cache local de atividades
- [ ] Notificações push de novas atividades
- [ ] Filtros por tipo de atividade
- [ ] Busca no feed
- [ ] Reações/curtidas em atividades
- [ ] Comentários em atividades
- [ ] Compartilhar atividade externa
- [ ] Feed personalizado com algoritmo de relevância
- [ ] Atividades agrupadas ("João e 3 outros adicionaram links")
- [ ] Analytics de engajamento
- [ ] Sugestões baseadas em atividades (discover)

---

**Módulo 6 concluído com sucesso!** ✅

Feed social completo com agregação inteligente e interface rica para aumentar engajamento na plataforma.
