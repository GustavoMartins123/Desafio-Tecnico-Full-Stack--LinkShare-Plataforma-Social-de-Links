# Módulo 5 - Sistema de Compartilhamento de Coleções

## Descrição

Este módulo implementa um sistema completo de compartilhamento de coleções entre amigos, permitindo que usuários compartilhem suas coleções com permissões granulares (visualização ou edição) e gerenciem quem tem acesso a cada coleção.

## Funcionalidades Implementadas

### 1. Compartilhamento de Coleções
- Compartilhar coleções privadas com amigos (apenas amigos aceitos)
- Definir permissões de visualização ou edição
- Validação de amizade antes de compartilhar
- Prevenção de compartilhamentos duplicados

### 2. Gerenciamento de Permissões
- Alterar permissões de compartilhamento (view only ↔ can edit)
- Remover acesso compartilhado
- Visualizar lista de usuários com acesso a cada coleção

### 3. Coleções Compartilhadas Comigo
- Listar todas as coleções compartilhadas pelo usuário
- Visualizar permissões (view only ou can edit)
- Acessar coleções compartilhadas
- Editar coleções (se tiver permissão)

## Implementação

### Backend (.NET 8 API)

#### 1. Atualização da Entidade CollectionShare

**Arquivo:** `backend/LinkShare.API/Entities/CollectionShare.cs`

Adicionado campo `CanEdit`:
```csharp
public class CollectionShare
{
    public int Id { get; set; }
    public int CollectionId { get; set; }
    public int UserId { get; set; }
    public DateTime SharedAt { get; set; } = DateTime.UtcNow;
    public bool CanEdit { get; set; } = false; // NOVO CAMPO

    public Collection Collection { get; set; } = null!;
    public User User { get; set; } = null!;
}
```

**Migration:** A migration será criada automaticamente ao iniciar o contêiner Docker.

#### 2. DTOs de Compartilhamento

**Arquivos criados:**
- `backend/LinkShare.API/DTOs/Collection/CollectionShareDto.cs`
- `backend/LinkShare.API/DTOs/Collection/ShareCollectionRequest.cs`
- `backend/LinkShare.API/DTOs/Collection/SharedCollectionDto.cs`

**CollectionShareDto:**
```csharp
public class CollectionShareDto
{
    public int Id { get; set; }
    public int CollectionId { get; set; }
    public string CollectionName { get; set; }
    public int SharedWithUserId { get; set; }
    public string SharedWithUsername { get; set; }
    public string SharedWithDisplayName { get; set; }
    public DateTime SharedAt { get; set; }
    public bool CanEdit { get; set; }
}
```

**ShareCollectionRequest:**
```csharp
public class ShareCollectionRequest
{
    [Required]
    public int SharedWithUserId { get; set; }
    public bool CanEdit { get; set; } = false;
}
```

**SharedCollectionDto:**
```csharp
public class SharedCollectionDto
{
    public int Id { get; set; }
    public string Name { get; set; }
    public string? Description { get; set; }
    public bool IsPublic { get; set; }
    public int OwnerId { get; set; }
    public string OwnerUsername { get; set; }
    public string OwnerDisplayName { get; set; }
    public DateTime SharedAt { get; set; }
    public bool CanEdit { get; set; }
    public int LinkCount { get; set; }
}
```

#### 3. Endpoints de Compartilhamento

**Arquivo:** `backend/LinkShare.API/Controllers/CollectionsController.cs`

##### POST /api/collections/{collectionId}/share
Compartilha uma coleção com um amigo.

**Request Body:**
```json
{
  "sharedWithUserId": 2,
  "canEdit": true
}
```

**Response:** `CollectionShareDto`

**Validações:**
- Apenas o dono pode compartilhar
- Verifica se são amigos (FriendshipStatus.Accepted)
- Previne compartilhamentos duplicados

##### GET /api/collections/{collectionId}/shares
Lista todos os compartilhamentos de uma coleção (apenas owner).

**Response:** `List<CollectionShareDto>`

##### GET /api/collections/shared-with-me
Lista todas as coleções compartilhadas com o usuário autenticado.

**Response:** `List<SharedCollectionDto>`

##### PUT /api/collections/{collectionId}/share/{shareId}
Atualiza permissões de um compartilhamento (apenas owner).

**Request Body:**
```json
{
  "sharedWithUserId": 0,
  "canEdit": true
}
```

**Response:** `CollectionShareDto` atualizado

##### DELETE /api/collections/{collectionId}/share/{shareId}
Remove um compartilhamento (apenas owner).

**Response:** 204 No Content

#### 4. Controle de Acesso Atualizado

**POST /api/collections/{collectionId}/items** - Agora permite usuários com `CanEdit = true`:
```csharp
var canEdit = collection.OwnerId == userId ||
             collection.Shares.Any(s => s.UserId == userId && s.CanEdit);
```

### Frontend (Flutter)

#### 1. Modelos de Dados

**Arquivos criados:**
- `mobile/linkshare_app/lib/models/collection_share.dart`
- `mobile/linkshare_app/lib/models/shared_collection.dart`

**CollectionShare:**
```dart
class CollectionShare {
  final int id;
  final int collectionId;
  final String collectionName;
  final int sharedWithUserId;
  final String sharedWithUsername;
  final String sharedWithDisplayName;
  final DateTime sharedAt;
  final bool canEdit;
}
```

**SharedCollection:**
```dart
class SharedCollection {
  final int id;
  final String name;
  final String? description;
  final bool isPublic;
  final int ownerId;
  final String ownerUsername;
  final String ownerDisplayName;
  final DateTime sharedAt;
  final bool canEdit;
  final int linkCount;
}
```

#### 2. Serviços de Compartilhamento

**Arquivo:** `mobile/linkshare_app/lib/services/collection_service.dart`

**Métodos adicionados:**
```dart
Future<CollectionShare> shareCollection({
  required int collectionId,
  required int sharedWithUserId,
  bool canEdit = false,
}) async

Future<List<CollectionShare>> getCollectionShares(int collectionId) async

Future<List<SharedCollection>> getSharedWithMe() async

Future<CollectionShare> updateSharePermissions({
  required int collectionId,
  required int shareId,
  required bool canEdit,
}) async

Future<void> removeShare({
  required int collectionId,
  required int shareId,
}) async
```

#### 3. Tela de Compartilhamento

**Arquivo:** `mobile/linkshare_app/lib/screens/collections/share_collection_screen.dart`

**Funcionalidades:**
- Exibe informações da coleção (título, descrição, público/privado)
- Lista todos os compartilhamentos ativos com avatar e nome
- Mostra data de compartilhamento formatada
- Dropdown para selecionar amigo
- Checkbox "Can edit" para definir permissões
- Menu popup em cada share com opções:
  - Grant/Remove edit access
  - Remove access
- Dialog de confirmação para compartilhar
- Filtragem de amigos já com acesso
- Feedback visual com SnackBars

**Componentes:**
- `ShareCollectionScreen` (StatefulWidget)
- `_ShareDialog` (Dialog interno para seleção de amigo)

#### 4. Tela de Coleções Compartilhadas Comigo

**Arquivo:** `mobile/linkshare_app/lib/screens/collections/shared_with_me_screen.dart`

**Funcionalidades:**
- Lista todas as coleções compartilhadas com o usuário
- Exibe nome do dono, quantidade de links, data de compartilhamento
- Chips coloridos indicando permissões:
  - Verde "Can Edit" para coleções editáveis
  - Azul "View Only" para coleções somente leitura
- RefreshIndicator para atualizar lista
- Navegação para CollectionDetailScreen ao tocar
- Estado vazio com ícone e mensagem

#### 5. Atualizações na Tab de Coleções

**Arquivo:** `mobile/linkshare_app/lib/screens/collections/my_collections_tab.dart`

**Mudanças:**
- Adicionado botão `folder_shared` no AppBar
- Navegação para `SharedWithMeScreen`
- Tooltip explicativo "Shared with me"

#### 6. Atualização do CollectionDetailScreen

**Arquivo:** `mobile/linkshare_app/lib/screens/collections/collection_detail_screen.dart`

**Mudanças:**
- Botão "Share" agora passa objeto `Collection` completo
- Invalidação da página após compartilhar para atualizar estado

## Estrutura de Arquivos Criados/Modificados

```
backend/LinkShare.API/
├── Entities/
│   └── CollectionShare.cs                      (MODIFICADO - adicionado CanEdit)
├── DTOs/Collection/
│   ├── CollectionShareDto.cs                   (NOVO)
│   ├── ShareCollectionRequest.cs               (NOVO)
│   └── SharedCollectionDto.cs                  (NOVO)
└── Controllers/
    └── CollectionsController.cs                (MODIFICADO - 5 novos endpoints)

mobile/linkshare_app/
├── lib/
│   ├── models/
│   │   ├── collection_share.dart               (NOVO)
│   │   └── shared_collection.dart              (NOVO)
│   ├── services/
│   │   └── collection_service.dart             (MODIFICADO - 5 novos métodos)
│   └── screens/collections/
│       ├── share_collection_screen.dart        (MODIFICADO - UI completa)
│       ├── shared_with_me_screen.dart          (NOVO)
│       ├── my_collections_tab.dart             (MODIFICADO - botão shared)
│       └── collection_detail_screen.dart       (MODIFICADO - atualizado Share)
```

## Fluxos de Uso

### Fluxo 1: Compartilhar Coleção

```
1. Usuário está em CollectionDetailScreen (sua coleção)
2. Clica no botão "Share"
3. ShareCollectionScreen abre
4. Exibe informações da coleção e lista de compartilhamentos
5. Clica em "Share" (botão superior direito)
6. Dialog abre com dropdown de amigos
7. Seleciona amigo e marca/desmarca "Can edit"
8. Clica em "Share" no dialog
9. POST /api/collections/{id}/share
10. Backend valida amizade
11. Cria CollectionShare
12. Retorna CollectionShareDto
13. Lista atualiza com novo share
14. SnackBar confirma sucesso
```

### Fluxo 2: Alterar Permissões

```
1. Usuário está em ShareCollectionScreen
2. Vê lista de compartilhamentos
3. Clica no menu (⋮) de um compartilhamento
4. Seleciona "Grant edit access" ou "Remove edit access"
5. PUT /api/collections/{id}/share/{shareId}
6. Backend atualiza CanEdit
7. Retorna share atualizado
8. UI atualiza estado local
9. SnackBar confirma alteração
```

### Fluxo 3: Visualizar Coleções Compartilhadas Comigo

```
1. Usuário está em MyCollectionsTab
2. Clica no ícone folder_shared no AppBar
3. SharedWithMeScreen abre
4. GET /api/collections/shared-with-me
5. Backend busca todos CollectionShares onde UserId = current user
6. Retorna lista de SharedCollectionDto
7. Exibe cards com:
   - Nome da coleção
   - Nome do dono
   - Quantidade de links
   - Data de compartilhamento
   - Chip de permissão (Can Edit / View Only)
8. Usuário clica em uma coleção
9. Navega para CollectionDetailScreen
```

### Fluxo 4: Adicionar Link em Coleção Compartilhada

```
1. Usuário acessa coleção compartilhada (CanEdit = true)
2. Botão "Add Link" está visível
3. Clica em "Add Link"
4. Preenche formulário
5. POST /api/collections/{id}/items
6. Backend valida:
   - IsOwner OU
   - HasShare with CanEdit = true
7. Link é adicionado
8. Retorna LinkItemDto
9. Lista de links atualiza
```

## Validações e Segurança

### Backend
- ✅ Apenas o owner pode compartilhar coleções
- ✅ Apenas o owner pode gerenciar compartilhamentos (alterar, remover)
- ✅ Verifica amizade (FriendshipStatus.Accepted) antes de compartilhar
- ✅ Previne compartilhamentos duplicados
- ✅ Usuários com CanEdit podem adicionar links
- ✅ Usuários com acesso (owner, public, ou shared) podem visualizar
- ✅ Autenticação JWT em todos os endpoints

### Frontend
- ✅ Filtra amigos que já têm acesso
- ✅ Mostra mensagem quando todos os amigos já têm acesso
- ✅ Valida seleção de amigo antes de compartilhar
- ✅ Feedback visual de loading durante operações
- ✅ Tratamento de erros com SnackBars
- ✅ Estados vazios com mensagens claras

## Tecnologias Utilizadas

### Backend
- **ASP.NET Core 8.0** - Framework web
- **Entity Framework Core** - ORM para acesso a dados
- **LINQ** - Queries e transformações
- **Include/ThenInclude** - Eager loading de relacionamentos

### Frontend
- **Flutter Riverpod** - Gerenciamento de estado
- **ConsumerStatefulWidget** - Widgets com estado e providers
- **DropdownButtonFormField** - Seleção de amigos
- **CheckboxListTile** - Seleção de permissões
- **PopupMenuButton** - Menu de ações
- **AlertDialog** - Diálogos de confirmação
- **RefreshIndicator** - Pull-to-refresh
- **intl** - Formatação de datas

## Regras de Negócio

1. **Compartilhamento**:
   - Apenas coleções privadas precisam ser compartilhadas (públicas são acessíveis a todos)
   - Apenas amigos aceitos podem receber compartilhamento
   - Um usuário não pode ter acesso duplicado à mesma coleção

2. **Permissões**:
   - `View Only`: Pode visualizar coleção e links
   - `Can Edit`: Pode visualizar E adicionar/editar links

3. **Propriedade**:
   - Owner tem controle total sobre a coleção
   - Owner pode compartilhar, alterar permissões e remover acesso
   - Owner sempre tem permissão de edição (não precisa de share)

4. **Visualização**:
   - Coleções públicas são visíveis para todos (sem necessidade de compartilhamento)
   - Coleções privadas só são visíveis para owner e usuários com compartilhamento

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

### 2. Compartilhar uma Coleção

1. Crie uma coleção privada
2. Adicione alguns links
3. Toque em "Share"
4. Toque no botão "Share" (canto superior direito)
5. Selecione um amigo no dropdown
6. Marque "Can edit" se quiser dar permissão de edição
7. Confirme

### 3. Ver Coleções Compartilhadas Comigo

1. Na aba "Collections"
2. Toque no ícone de pasta compartilhada (folder_shared) no AppBar
3. Veja todas as coleções compartilhadas
4. Toque em uma para abrir

### 4. Gerenciar Compartilhamentos

1. Abra uma coleção que você é dono
2. Toque em "Share"
3. Veja lista de compartilhamentos
4. Toque no menu (⋮) em qualquer compartilhamento
5. Altere permissões ou remova acesso

## Endpoints API

| Método | Endpoint | Descrição | Auth |
|--------|----------|-----------|------|
| POST | `/api/collections/{id}/share` | Compartilhar coleção | ✅ |
| GET | `/api/collections/{id}/shares` | Listar compartilhamentos | ✅ |
| GET | `/api/collections/shared-with-me` | Minhas coleções compartilhadas | ✅ |
| PUT | `/api/collections/{id}/share/{shareId}` | Atualizar permissões | ✅ |
| DELETE | `/api/collections/{id}/share/{shareId}` | Remover compartilhamento | ✅ |

## Melhorias Futuras (Fora do Escopo)

- [ ] Notificações quando alguém compartilha uma coleção
- [ ] Notificações quando permissões são alteradas
- [ ] Histórico de mudanças de permissões
- [ ] Compartilhamento com múltiplos usuários de uma vez
- [ ] Compartilhamento por link público (sem necessidade de amizade)
- [ ] Expiração automática de compartilhamentos
- [ ] Permissão de "Admin" (pode compartilhar com outros)
- [ ] Compartilhamento com grupos de amigos
- [ ] Comentários em compartilhamentos
- [ ] Estatísticas de acessos em coleções compartilhadas

---

**Módulo 5 concluído com sucesso!** ✅

Todas as funcionalidades de compartilhamento de coleções estão implementadas e integradas entre backend e frontend.
