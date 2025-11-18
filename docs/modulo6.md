# Módulo 6: Segurança Avançada da API (JTI, Blacklist, Refresh Tokens)

## Visão Geral

Este módulo implementa um sistema robusto de autenticação JWT com suporte a **refresh tokens** e **blacklist de tokens revogados**, usando Redis para cache de alta performance.

## Arquitetura

### 1. **Access Token (JWT)**
- **Vida Curta**: 15 minutos
- **Contém JTI**: Identificador único (Guid) para rastreamento
- **Claims**: `sub` (userId), `email`, `username`, `jti`
- **Uso**: Enviado em todas as requisições autenticadas via header `Authorization: Bearer {token}`

### 2. **Refresh Token (Opaque Token)**
- **Vida Longa**: 7 dias
- **Formato**: String aleatória (2 Guids concatenados)
- **Armazenamento**: Banco de dados PostgreSQL (tabela `UserTokens`)
- **Uso**: Obter novos access tokens sem login

### 3. **Redis Blacklist**
- **Propósito**: Invalidar tokens antes da expiração natural
- **Chave**: `blacklist:{jti}`
- **TTL**: Tempo restante até expiração do token
- **Performance**: O(1) para verificação

## Componentes Backend (.NET)

### 1. Entidade `UserToken`

**Arquivo**: `backend/LinkShare.API/Entities/UserToken.cs`

```csharp
public class UserToken
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string RefreshToken { get; set; } // Guid duplo
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public bool IsRevoked { get; set; }
    public DateTime? RevokedAt { get; set; }
    public User User { get; set; } = null!;
}
```

### 2. RedisService

**Arquivo**: `backend/LinkShare.API/Services/RedisService.cs`

Gerencia a blacklist de tokens:

```csharp
public interface IRedisService
{
    Task BlacklistTokenAsync(string jti, TimeSpan expiration);
    Task<bool> IsTokenBlacklistedAsync(string jti);
}
```

**Funcionamento**:
- `BlacklistTokenAsync`: Adiciona JTI ao Redis com TTL
- `IsTokenBlacklistedAsync`: Verifica se JTI está na blacklist

### 3. Middleware `JwtBlacklistMiddleware`

**Arquivo**: `backend/LinkShare.API/Middleware/JwtBlacklistMiddleware.cs`

**Pipeline**:
1. `UseAuthentication()` → Valida JWT e popula `User.Claims`
2. `UseJwtBlacklist()` → **Verifica blacklist**
3. `UseAuthorization()` → Verifica permissões

**Lógica**:
```csharp
if (context.User.Identity?.IsAuthenticated == true)
{
    var jti = context.User.FindFirst(JwtRegisteredClaimNames.Jti)?.Value;
    if (await redisService.IsTokenBlacklistedAsync(jti))
    {
        // Retorna 401 Unauthorized
    }
}
```

### 4. Endpoints de Autenticação

#### POST `/api/auth/login`

**Request**:
```json
{
  "email": "user@example.com",
  "password": "senha123"
}
```

**Response** (200 OK):
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "abc123def456...",
  "userId": 1,
  "username": "johndoe",
  "email": "user@example.com"
}
```

**Comportamento**:
1. Valida credenciais
2. Gera access token (15 min) com JTI
3. Gera refresh token (7 dias)
4. Salva refresh token no PostgreSQL

#### POST `/api/auth/refresh`

**Request**:
```json
{
  "refreshToken": "abc123def456..."
}
```

**Response** (200 OK):
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "xyz789uvw012...",
  "userId": 1,
  "username": "johndoe",
  "email": "user@example.com"
}
```

**Comportamento**:
1. Valida refresh token (existe, não expirou, não revogado)
2. Revoga o refresh token antigo
3. Gera novo access token + refresh token
4. Salva novo refresh token
5. Retorna ambos os tokens

**Erros**:
- `401`: Token inválido, expirado ou revogado

#### POST `/api/auth/logout` (Requer autenticação)

**Headers**:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response** (200 OK):
```json
{
  "message": "Logged out successfully"
}
```

**Comportamento**:
1. Extrai JTI do access token
2. Adiciona JTI à blacklist do Redis (TTL = tempo restante)
3. Revoga todos os refresh tokens do usuário no PostgreSQL

## Componentes Mobile (Flutter)

### 1. StorageService Atualizado

**Arquivo**: `mobile/linkshare_app/lib/services/storage_service.dart`

**Mudanças**:
```dart
// Antes (Módulo 4)
Future<void> saveToken(String token);
String? getToken();

// Agora (Módulo 6)
Future<void> saveTokens({
  required String accessToken,
  required String refreshToken,
});
String? getAccessToken();
String? getRefreshToken();
```

**Chaves no SharedPreferences**:
- `access_token`: JWT de acesso
- `refresh_token`: Token opaco para renovação

### 2. AuthInterceptor

**Arquivo**: `mobile/linkshare_app/lib/services/auth_interceptor.dart`

**Fluxo de Renovação Automática**:

```
┌─────────────────────────────────────────────────────┐
│ 1. Request com Access Token no header               │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│ 2. API retorna 401 Unauthorized                     │
└────────────────┬────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────┐
│ 3. Interceptor detecta 401                          │
│    - Chama POST /auth/refresh com refresh token     │
└────────────────┬────────────────────────────────────┘
                 │
         ┌───────┴───────┐
         │               │
         ▼               ▼
   ┌─────────┐     ┌──────────┐
   │ Sucesso │     │  Falha   │
   └────┬────┘     └─────┬────┘
        │                │
        ▼                ▼
┌───────────────┐  ┌─────────────┐
│ 4a. Salva     │  │ 4b. Logout  │
│ novos tokens  │  │ (clearAll)  │
│ 5a. Retry     │  │             │
│ request       │  │             │
└───────────────┘  └─────────────┘
```

## Configuração Docker

### Redis Adicionado ao `docker-compose.yml`

```yaml
redis:
  image: redis:alpine
  container_name: linkshare-redis
  restart: unless-stopped
  ports:
    - "6379:6379"
  volumes:
    - redis_data:/data
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 5s
    retries: 5
```

### Variáveis de Ambiente

```env
# JWT Configuration
JWT_SECRET_KEY=YourSuperSecretKeyThatIsAtLeast32CharactersLongForProduction!
JWT_ISSUER=LinkShareAPI
JWT_AUDIENCE=LinkShareClient
JWT_EXPIRATION_MINUTES=15
REFRESH_TOKEN_EXPIRATION_DAYS=7

# Redis Configuration
REDIS_CONNECTION=redis:6379
```

## Segurança

### Proteções Implementadas

✅ **JTI (JWT ID)**: Cada token tem ID único para rastreamento
✅ **Blacklist**: Tokens revogados são bloqueados antes da expiração
✅ **Refresh Token Rotation**: Cada refresh invalida o token antigo
✅ **Tokens de Vida Curta**: Access token expira em 15 minutos
✅ **Armazenamento Seguro**: Refresh tokens no PostgreSQL (não em localStorage)
✅ **Middleware de Verificação**: Toda requisição valida blacklist
✅ **Logout Completo**: Revoga access token E todos os refresh tokens do usuário

## Arquivos Modificados/Criados

### Backend (.NET)

**Novos Arquivos**:
- `Entities/UserToken.cs`
- `Services/IRedisService.cs`
- `Services/RedisService.cs`
- `Middleware/JwtBlacklistMiddleware.cs`
- `DTOs/Auth/RefreshTokenRequestDto.cs`

**Modificados**:
- `Data/ApplicationDbContext.cs` (adicionado `DbSet<UserToken>`)
- `Controllers/AuthController.cs` (login, refresh, logout)
- `Services/TokenService.cs` (adicionado `GenerateRefreshToken()`)
- `Services/ITokenService.cs` (nova interface)
- `DTOs/Auth/AuthResponseDto.cs` (adicionado `RefreshToken`)
- `Program.cs` (Redis, middleware)
- `LinkShare.API.csproj` (StackExchange.Redis)

### Mobile (Flutter)

**Novos Arquivos**:
- `services/auth_interceptor.dart`

**Modificados**:
- `services/storage_service.dart` (tokens duplos)
- `services/api_client.dart` (usa AuthInterceptor)

### Infraestrutura

**Modificados**:
- `docker-compose.yml` (serviço Redis, variáveis de ambiente)

---

**Módulo 6 concluído com sucesso!** ✅

Sistema de autenticação robusto com JWT, refresh tokens e blacklist Redis.
