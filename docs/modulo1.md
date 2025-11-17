# Módulo 1: Backend API (C# .NET) - Documentação

## 📋 Resumo

Este módulo implementa a API backend completa da plataforma LinkShare usando C# .NET 8, Entity Framework Core e PostgreSQL. A API fornece autenticação JWT, gerenciamento de perfis, sistema de amizades e coleções de links compartilháveis.

---

## 🎯 O que foi feito

### 1. Estrutura do Projeto

Criada a estrutura completa do projeto .NET 8 Web API com organização modular:

```
backend/LinkShare.API/
├── Entities/          # Modelos de domínio (entidades do banco)
├── Controllers/       # Endpoints da API (REST)
├── DTOs/             # Data Transfer Objects (requisições/respostas)
├── Services/         # Serviços de negócio (JWT, etc)
├── Data/             # DbContext e configurações EF Core
├── Program.cs        # Ponto de entrada e configuração da aplicação
├── appsettings.json  # Configurações (conexão, JWT, etc)
└── LinkShare.API.csproj  # Arquivo de projeto .NET
```

**Por que essa estrutura?**
- **Separação de responsabilidades**: Cada camada tem uma função específica
- **Manutenibilidade**: Fácil localizar e modificar componentes
- **Escalabilidade**: Permite adicionar novos recursos sem bagunçar o código existente
- **Padrão da indústria**: Segue as melhores práticas de arquitetura .NET

---

### 2. Modelagem de Dados (Entidades)

Implementadas 6 entidades com relacionamentos bem definidos:

#### **User** (Entities/User.cs)
- Representa um usuário do sistema
- Campos: Id, Email (único), Username (único), PasswordHash, CreatedAt
- Relacionamentos: 1-para-1 com Profile, 1-para-muitos com Collections, muitos-para-muitos com Friendships

#### **Profile** (Entities/Profile.cs)
- Perfil público do usuário (separado das credenciais)
- Campos: Id, UserId (FK), DisplayName, Bio, ProfilePictureUrl
- Relacionamento: 1-para-1 com User (cascade delete)

#### **Friendship** (Entities/Friendship.cs)
- Representa conexões entre usuários (sistema de amizades)
- Campos: Id, RequesterId (FK), AddresseeId (FK), Status (enum), RequestedAt, UpdatedAt
- Status possíveis: Pending, Accepted, Declined, Blocked
- Relacionamento: Auto-referencial many-to-many em User

#### **Collection** (Entities/Collection.cs)
- Coleção de links criada por um usuário
- Campos: Id, Title, Description, OwnerId (FK), IsPublic (bool), CreatedAt
- Relacionamentos: Pertence a um User (owner), contém múltiplos LinkItems

#### **LinkItem** (Entities/LinkItem.cs)
- Item individual dentro de uma coleção (um link)
- Campos: Id, Title, URL, Description, CollectionId (FK), CreatedAt
- Relacionamento: Pertence a uma Collection (cascade delete)

#### **CollectionShare** (Entities/CollectionShare.cs)
- Tabela de junção para compartilhar coleções privadas com amigos
- Campos: Id, CollectionId (FK), UserId (FK), SharedAt
- Relacionamento: Many-to-many entre Collection e User

**Por que esse modelo?**
- **Normalização**: Evita duplicação de dados
- **Flexibilidade**: Suporta coleções públicas, privadas e compartilhadas seletivamente
- **Integridade**: Foreign keys garantem consistência dos dados
- **Privacidade**: User e Profile separados permitem controle fino de dados sensíveis

---

### 3. DbContext e Entity Framework Core

#### **ApplicationDbContext** (Data/ApplicationDbContext.cs)
- Gerencia todas as entidades e configurações do banco
- Configurações aplicadas via Fluent API:
  - Índices únicos (Email, Username)
  - Restrições de tamanho (MaxLength)
  - Relacionamentos e comportamentos de delete (Cascade, Restrict)
  - Unique constraints compostos (ex: RequesterId + AddresseeId)

**Por que Entity Framework Core?**
- **ORM poderoso**: Abstrai SQL, permite trabalhar com objetos C#
- **Migrations**: Controle de versão do schema do banco
- **Type-safe**: Validação em tempo de compilação
- **Suporte PostgreSQL**: Driver Npgsql oficial e maduro

---

### 4. Autenticação e Segurança

#### **JWT (JSON Web Tokens)**

**TokenService** (Services/TokenService.cs)
- Gera tokens JWT com claims (sub=UserId, email, username, jti)
- Configuração via appsettings.json (SecretKey, Issuer, Audience, ExpirationMinutes)
- Assinatura HMAC-SHA256

**Configuração no Program.cs**
- AddAuthentication com JwtBearer
- Validação de issuer, audience, lifetime e assinatura
- ClockSkew = 0 (sem margem de tempo para expiração)

**Por que JWT?**
- **Stateless**: Não requer armazenamento no servidor (escalável)
- **Portable**: Funciona em qualquer plataforma (Flutter, web, etc)
- **Seguro**: Assinado criptograficamente, não pode ser adulterado
- **Claims**: Carrega informações do usuário no próprio token

---

### 5. DTOs (Data Transfer Objects)

Criados DTOs organizados por domínio para desacoplar API das entidades:

**Auth**
- `RegisterRequestDto`: Email, Username, Password (validações via Data Annotations)
- `LoginRequestDto`: Email, Password
- `AuthResponseDto`: Token, UserId, Username, Email

**Profile**
- `ProfileDto`: Dados públicos do perfil (inclui Username)
- `UpdateProfileDto`: DisplayName, Bio (para atualização)

**Friendship**
- `FriendshipDto`: Dados completos da amizade (com usernames de ambos os lados)

**Collection**
- `CollectionDto`: Lista resumida (com contador de links)
- `CollectionDetailDto`: Detalhes completos (com array de LinkItems)
- `CreateCollectionDto`: Dados para criação

**LinkItem**
- `LinkItemDto`: Dados completos do link
- `CreateLinkItemDto`: Dados para criação (com validação de URL)

**Por que DTOs?**
- **Segurança**: Evita expor campos sensíveis (PasswordHash, IDs internos)
- **Versionamento**: API pode evoluir sem quebrar o modelo do banco
- **Validação**: Data Annotations centralizam regras de validação
- **Performance**: Permite projeções (SELECT apenas campos necessários)

---

### 6. Controllers (Endpoints REST)

#### **AuthController** (Controllers/AuthController.cs)

**POST /api/auth/register**
- Recebe: Email, Username, Password
- Valida unicidade de email e username
- Hash de senha com BCrypt (10 rounds, salt automático)
- Cria User E Profile vinculado (transação)
- Retorna: Token JWT

**POST /api/auth/login**
- Recebe: Email, Password
- Busca usuário por email
- Verifica hash de senha com BCrypt.Verify
- Retorna: Token JWT

**Por que BCrypt?**
- **Lento por design**: Protege contra brute-force
- **Salt automático**: Cada senha tem hash único
- **Adaptativo**: Pode aumentar rounds (work factor) no futuro

---

#### **ProfilesController** (Controllers/ProfileController.cs)

**GET /api/profiles/{username}** (público)
- Busca perfil por username
- Retorna dados públicos (DisplayName, Bio, ProfilePictureUrl)

**GET /api/profiles/me** (autenticado)
- Retorna perfil do usuário logado
- Extrai UserId do token JWT (ClaimTypes.NameIdentifier)

**PUT /api/profiles/me** (autenticado)
- Atualiza DisplayName e Bio do usuário logado
- Validações via Data Annotations no DTO

**GET /api/profiles/search?query={query}** (público)
- Busca por Username OU DisplayName (case-sensitive no PostgreSQL)
- Limita a 20 resultados (proteção contra DoS)

---

#### **FriendsController** (Controllers/FriendsController.cs)

**POST /api/friends/request/{userId}** (autenticado)
- Envia pedido de amizade
- Validações: não pode enviar para si mesmo, usuário existe, não há pedido existente
- Cria Friendship com Status=Pending

**GET /api/friends/requests** (autenticado)
- Lista pedidos RECEBIDOS pelo usuário (AddresseeId = currentUser)
- Apenas status Pending

**PUT /api/friends/requests/{requestId}/accept** (autenticado)
- Aceita pedido de amizade
- Validações: usuário é o addressee, status é Pending
- Atualiza Status para Accepted e UpdatedAt

**DELETE /api/friends/requests/{requestId}** (autenticado)
- Recusa pedido de amizade (apenas addressee pode recusar)
- Remove registro do banco

**GET /api/friends** (autenticado)
- Lista todas as amizades aceitas (RequesterId OU AddresseeId = currentUser)
- Retorna dados de ambos os usuários

**DELETE /api/friends/{friendId}** (autenticado)
- Remove amizade existente
- Busca friendship bidirecional (pode estar em qualquer direção)

**Por que esse design?**
- **Bidirecional**: Amizade funciona nos dois sentidos após aceita
- **Controle**: Apenas destinatário pode aceitar/recusar
- **Flexível**: Permite expandir para "Blocked" no futuro

---

#### **CollectionsController** (Controllers/CollectionsController.cs)

**POST /api/collections** (autenticado)
- Cria nova coleção
- OwnerId = usuário logado
- IsPublic define visibilidade

**GET /api/collections/me** (autenticado)
- Lista TODAS as coleções do usuário (públicas e privadas)
- Inclui contador de LinkItems

**GET /api/collections/user/{username}** (público)
- Lista apenas coleções PÚBLICAS de um usuário específico
- Permite descobrir conteúdo público

**GET /api/collections/{collectionId}** (autenticado)
- Retorna detalhes completos da coleção com todos os LinkItems
- **Lógica de permissão crítica**:
  - ✅ IsPublic = true (qualquer um pode ver)
  - ✅ OwnerId = currentUser (dono vê tudo)
  - ✅ UserId está em CollectionShares (compartilhado explicitamente)
  - ❌ Caso contrário: 403 Forbidden

**POST /api/collections/{collectionId}/items** (autenticado)
- Adiciona LinkItem à coleção
- Validação: apenas OWNER pode adicionar items
- Validação de URL via [Url] data annotation

**POST /api/collections/{collectionId}/share/{friendId}** (autenticado)
- Compartilha coleção privada com um amigo específico
- Validações:
  - Apenas owner pode compartilhar
  - Deve ser amigo (Status=Accepted)
  - Não pode compartilhar duas vezes

**Por que 3 níveis de visibilidade?**
- **Público**: Conteúdo aberto (descobrível)
- **Privado**: Apenas dono
- **Compartilhado**: Controle granular (amigos específicos)
- Isso permite casos de uso como "coleção privada de presentes" compartilhada apenas com família

---

### 7. Configuração da Aplicação (Program.cs)

**Serviços configurados:**
1. **DbContext**: PostgreSQL via Npgsql
2. **JWT Authentication**: Bearer tokens com validação completa
3. **CORS**: AllowAll (necessário para Flutter)
4. **Swagger**: Documentação interativa com suporte a JWT (botão Authorize)
5. **Scoped Services**: TokenService injetado via DI

**Middlewares (pipeline HTTP):**
1. Swagger (apenas em Development)
2. CORS
3. Authentication
4. Authorization
5. Controllers

**Features adicionais:**
- Health check endpoint: GET /health
- Auto-migration ao iniciar (cria/atualiza banco automaticamente)
- Logging configurado

**Por que essa ordem de middlewares?**
- CORS antes de Authentication (permite pre-flight requests)
- Authentication antes de Authorization (primeiro identifica, depois autoriza)
- Controllers por último (ponto final do pipeline)

---

### 8. Configurações (appsettings)

**appsettings.json** (para desenvolvimento local)
- ConnectionString: localhost:5432
- JwtSettings: SecretKey de 32+ caracteres

**appsettings.Development.json** (para Docker)
- ConnectionString: Host=db (nome do serviço no Docker Compose)
- Sobrescreve configurações de produção

**Por que dois arquivos?**
- Permite rodar localmente SEM Docker (desenvolvimento rápido)
- E também dentro de containers (ambiente consistente)

---

## 📁 Arquivos Criados/Alterados

### Criados:

```
backend/LinkShare.API/
├── LinkShare.API.csproj
├── Program.cs
├── appsettings.json
├── appsettings.Development.json
├── .gitignore
│
├── Entities/
│   ├── User.cs
│   ├── Profile.cs
│   ├── Friendship.cs
│   ├── Collection.cs
│   ├── LinkItem.cs
│   └── CollectionShare.cs
│
├── Data/
│   └── ApplicationDbContext.cs
│
├── Services/
│   ├── ITokenService.cs
│   └── TokenService.cs
│
├── DTOs/
│   ├── Auth/
│   │   ├── RegisterRequestDto.cs
│   │   ├── LoginRequestDto.cs
│   │   └── AuthResponseDto.cs
│   │
│   ├── Profile/
│   │   ├── ProfileDto.cs
│   │   └── UpdateProfileDto.cs
│   │
│   ├── Friendship/
│   │   └── FriendshipDto.cs
│   │
│   ├── Collection/
│   │   ├── CollectionDto.cs
│   │   ├── CreateCollectionDto.cs
│   │   └── CollectionDetailDto.cs
│   │
│   └── LinkItem/
│       ├── LinkItemDto.cs
│       └── CreateLinkItemDto.cs
│
└── Controllers/
    ├── AuthController.cs
    ├── ProfileController.cs (ProfilesController)
    ├── FriendsController.cs
    └── CollectionsController.cs

docs/
└── modulo1.md (este arquivo)
```

### Alterados:
- Nenhum (módulo inicial)

---

## 🔑 Decisões Técnicas Importantes

### 1. Por que .NET 8?
- LTS (Long Term Support) até novembro de 2026
- Performance superior (benchmarks mostram 3x mais rápido que Node.js em APIs REST)
- Type-safety nativa (menos bugs em produção)
- Ecossistema maduro (NuGet, EF Core, JWT, etc)

### 2. Por que PostgreSQL?
- Open-source e gratuito
- ACID compliant (transações confiáveis)
- Suporte a JSON (útil para features futuras)
- Excelente com Entity Framework Core

### 3. Por que JWT stateless?
- Escala horizontalmente (múltiplas instâncias da API)
- Não requer Redis/cache para sessions (simplicidade no Módulo 1)
- Módulo 6 adiciona refresh tokens e blacklist (upgrade de segurança)

### 4. Por que BCrypt?
- Padrão da indústria para hashing de senhas
- Resistente a rainbow tables e GPUs
- Usado por grandes empresas (GitHub, Cloudflare)

---

## 🚀 Como Executar

### Opção 1: Com .NET SDK instalado

```bash
cd backend/LinkShare.API

# Restaurar dependências
dotnet restore

# Criar banco de dados PostgreSQL local
# (assumindo PostgreSQL rodando em localhost:5432)

# Aplicar migrations
dotnet ef database update

# Executar API
dotnet run
```

API estará disponível em: `http://localhost:5000`
Swagger UI: `http://localhost:5000/swagger`

### Opção 2: Com Docker (Módulo 3)

Aguardar implementação do Docker Compose no próximo módulo.

---

## 🧪 Testando a API

### 1. Registrar usuário

```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "teste@example.com",
    "username": "usuario_teste",
    "password": "senha123"
  }'
```

Resposta:
```json
{
  "token": "eyJhbGc...",
  "userId": 1,
  "username": "usuario_teste",
  "email": "teste@example.com"
}
```

### 2. Login

```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "teste@example.com",
    "password": "senha123"
  }'
```

### 3. Buscar perfil (com token)

```bash
curl -X GET http://localhost:5000/api/profiles/me \
  -H "Authorization: Bearer SEU_TOKEN_AQUI"
```

### 4. Criar coleção

```bash
curl -X POST http://localhost:5000/api/collections \
  -H "Authorization: Bearer SEU_TOKEN_AQUI" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Meus Links Favoritos",
    "description": "Coleção de artigos interessantes",
    "isPublic": true
  }'
```

---

## 📊 Endpoints Disponíveis

### Auth
- `POST /api/auth/register` - Registrar usuário
- `POST /api/auth/login` - Login

### Profiles
- `GET /api/profiles/{username}` - Perfil público
- `GET /api/profiles/me` - Meu perfil (autenticado)
- `PUT /api/profiles/me` - Atualizar meu perfil (autenticado)
- `GET /api/profiles/search?query={query}` - Buscar usuários

### Friends
- `POST /api/friends/request/{userId}` - Enviar pedido de amizade
- `GET /api/friends/requests` - Listar pedidos pendentes
- `PUT /api/friends/requests/{requestId}/accept` - Aceitar pedido
- `DELETE /api/friends/requests/{requestId}` - Recusar pedido
- `GET /api/friends` - Listar amigos
- `DELETE /api/friends/{friendId}` - Remover amizade

### Collections
- `POST /api/collections` - Criar coleção
- `GET /api/collections/me` - Minhas coleções
- `GET /api/collections/user/{username}` - Coleções públicas de um usuário
- `GET /api/collections/{collectionId}` - Detalhes da coleção
- `POST /api/collections/{collectionId}/items` - Adicionar link
- `POST /api/collections/{collectionId}/share/{friendId}` - Compartilhar coleção

### Utility
- `GET /health` - Health check

---

## ✅ Checklist do Módulo 1

- [x] Modelagem de dados (6 entidades)
- [x] DbContext com Fluent API
- [x] Autenticação JWT
- [x] AuthController (register, login)
- [x] ProfileController (GET, PUT, search)
- [x] FriendsController (CRUD completo de amizades)
- [x] CollectionsController (CRUD + lógica de permissões + share)
- [x] DTOs para todas as operações
- [x] Validações com Data Annotations
- [x] Configuração de CORS (para Flutter)
- [x] Swagger com suporte a JWT
- [x] Health check endpoint
- [x] Auto-migration no startup

---

## 🔜 Próximos Passos (Módulo 2)

- Frontend Flutter
- Telas de Login/Register
- Gerenciamento de coleções
- Sistema de amizades (UI)
- Integração completa com a API

---

## 📝 Notas Adicionais

### Segurança implementada:
- ✅ Senhas hasheadas com BCrypt
- ✅ JWT com assinatura HMAC-SHA256
- ✅ Validação de ownership (apenas dono pode modificar)
- ✅ Validação de amizades (apenas amigos podem compartilhar)
- ✅ Protection contra SQL injection (EF Core parametriza queries)
- ✅ Data Annotations para validação de entrada

### Performance:
- ✅ Índices em campos de busca (Email, Username)
- ✅ Eager loading para evitar N+1 queries (Include)
- ✅ Projeções com Select (apenas campos necessários)
- ✅ Paginação em search (Take 20)

### Boas práticas:
- ✅ Async/await em todas as operações I/O
- ✅ Dependency Injection
- ✅ Separação de responsabilidades
- ✅ RESTful naming conventions
- ✅ HTTP status codes corretos (201, 204, 400, 401, 403, 404)
- ✅ Mensagens de erro descritivas

---

**Módulo 1 completo! 🎉**
