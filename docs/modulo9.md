# Módulo 9: Processamento Assíncrono e Filas com RabbitMQ

## Visão Geral

Este módulo implementa um sistema de processamento assíncrono utilizando **RabbitMQ** como fila de mensagens e um **.NET Worker Service** para extrair metadados de URLs em background. Isso permite que a API responda instantaneamente ao usuário enquanto tarefas demoradas (como web scraping) são processadas em paralelo.

## Arquitetura do Sistema

```
┌────────────────────────────────────────────────────────────────┐
│                         Cliente (Flutter)                       │
│                                                                  │
│  POST /api/collections/1/items { "url": "..." }                │
└────────────────────────┬───────────────────────────────────────┘
                         │
                         v
┌────────────────────────────────────────────────────────────────┐
│                         API (.NET)                              │
│                                                                  │
│  1. Salva LinkItem com Title="Processando..."                  │
│  2. Publica mensagem na fila RabbitMQ                          │
│  3. Retorna 202 Accepted imediatamente                         │
│                                                                  │
│  ┌──────────────────────────────────┐                          │
│  │   MessageQueueService            │                          │
│  │  • PublishLinkMetadataJob()      │                          │
│  └──────────────────────────────────┘                          │
└────────────────────────┬───────────────────────────────────────┘
                         │
                         v
          ┌──────────────────────────┐
          │     RabbitMQ Queue       │
          │  link-metadata-queue     │
          └──────────────────────────┘
                         │
                         v
┌────────────────────────────────────────────────────────────────┐
│                    Worker Service (.NET)                        │
│                                                                  │
│  1. Consome mensagens da fila                                  │
│  2. Extrai metadados (title, description, image)               │
│  3. Atualiza LinkItem no banco de dados                        │
│  4. (Opcional) Notifica via SignalR                            │
│                                                                  │
│  ┌──────────────────────────────────┐                          │
│  │   WebScrapingService             │                          │
│  │  • ExtractMetadataAsync()        │                          │
│  │  • HtmlAgilityPack parsing       │                          │
│  └──────────────────────────────────┘                          │
└────────────────────────────────────────────────────────────────┘
```

## Por Que Usar Processamento Assíncrono?

### Problema
Ao adicionar um link, seria necessário:
1. Fazer HTTP request para a URL fornecida (pode demorar 2-10 segundos)
2. Fazer parsing do HTML (500ms - 2 segundos)
3. Extrair metadados (title, description, image)

Isso resultaria em uma resposta HTTP lenta (5-15 segundos), prejudicando a experiência do usuário.

### Solução
- **API responde em milissegundos** (apenas salva no banco e publica na fila)
- **Worker processa em background** (scraping acontece de forma assíncrona)
- **Usuário vê atualização em tempo real** (via SignalR ou refresh)

## Implementação

### 1. Infraestrutura - RabbitMQ

Adicionado ao `docker-compose.yml`:

```yaml
rabbitmq:
  image: rabbitmq:3.13-management-alpine
  container_name: linkshare-rabbitmq
  restart: unless-stopped
  environment:
    RABBITMQ_DEFAULT_USER: guest
    RABBITMQ_DEFAULT_PASS: guest
  ports:
    - "5672:5672"       # AMQP protocol
    - "15672:15672"     # Management UI (http://localhost:15672)
  volumes:
    - rabbitmq_data:/var/lib/rabbitmq
  healthcheck:
    test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
    interval: 10s
    timeout: 5s
    retries: 5
```

**Management UI:**
- Acesse http://localhost:15672
- Usuário: `guest`
- Senha: `guest`
- Visualize filas, mensagens, conexões, etc.

### 2. Backend - API

#### 2.1. MessageQueueService

Serviço responsável por publicar mensagens na fila:

```csharp
public interface IMessageQueueService
{
    void PublishLinkMetadataJob(int linkItemId, int collectionId, string url);
}

public class MessageQueueService : IMessageQueueService, IDisposable
{
    private readonly IConnection _connection;
    private readonly IModel _channel;
    private readonly string _queueName;

    public void PublishLinkMetadataJob(int linkItemId, int collectionId, string url)
    {
        var job = new
        {
            LinkItemId = linkItemId,
            CollectionId = collectionId,
            Url = url
        };

        var message = JsonSerializer.Serialize(job);
        var body = Encoding.UTF8.GetBytes(message);

        var properties = _channel.CreateBasicProperties();
        properties.Persistent = true; // Mensagens sobrevivem a restart

        _channel.BasicPublish(
            exchange: "",
            routingKey: _queueName,
            basicProperties: properties,
            body: body);
    }
}
```

**Características:**
- **Persistent messages**: Mensagens não são perdidas se RabbitMQ reiniciar
- **Singleton lifetime**: Uma conexão para toda a aplicação
- **Durable queue**: Fila sobrevive a restart do RabbitMQ

#### 2.2. Endpoint Modificado

```csharp
[HttpPost("{collectionId}/items")]
public async Task<ActionResult<LinkItemDto>> AddLinkItem(
    int collectionId,
    [FromBody] CreateLinkItemDto createDto)
{
    // ... validações ...

    // Salva com placeholder
    var linkItem = new LinkItem
    {
        Title = string.IsNullOrWhiteSpace(createDto.Title)
            ? "Processando..."
            : createDto.Title,
        URL = createDto.URL,
        Description = string.IsNullOrWhiteSpace(createDto.Description)
            ? "Extraindo informações da URL..."
            : createDto.Description,
        CollectionId = collectionId,
        CreatedAt = DateTime.UtcNow
    };

    _context.LinkItems.Add(linkItem);
    await _context.SaveChangesAsync();

    // Notifica SignalR imediatamente
    await _hubContext.Clients
        .Group($"collection_{collectionId}")
        .SendAsync("NewLinkAdded", linkItemDto);

    // Publica na fila (se necessário)
    if (string.IsNullOrWhiteSpace(createDto.Title) ||
        string.IsNullOrWhiteSpace(createDto.Description))
    {
        _messageQueueService.PublishLinkMetadataJob(
            linkItem.Id,
            collectionId,
            linkItem.URL);
    }

    // 202 Accepted = processamento assíncrono
    return AcceptedAtAction(nameof(GetCollectionById),
        new { collectionId },
        linkItemDto);
}
```

**Fluxo:**
1. ✅ Salva link com "Processando..."
2. ✅ Notifica SignalR (usuário vê imediatamente)
3. ✅ Publica job na fila
4. ✅ Retorna 202 Accepted (< 100ms)

#### 2.3. Configuração

**appsettings.json:**
```json
{
  "RabbitMQ": {
    "HostName": "localhost",
    "Port": "5672",
    "UserName": "guest",
    "Password": "guest",
    "QueueName": "link-metadata-queue"
  }
}
```

**Program.cs:**
```csharp
builder.Services.AddSingleton<IMessageQueueService, MessageQueueService>();
```

### 3. Worker Service

Projeto separado: `LinkShare.Worker`

#### 3.1. Estrutura do Projeto

```
LinkShare.Worker/
├── LinkShare.Worker.csproj
├── Program.cs
├── Worker.cs
├── appsettings.json
└── Services/
    └── WebScrapingService.cs
```

#### 3.2. Dependencies

```xml
<ItemGroup>
  <PackageReference Include="RabbitMQ.Client" Version="6.8.1" />
  <PackageReference Include="HtmlAgilityPack" Version="1.11.57" />
  <PackageReference Include="Npgsql.EntityFrameworkCore.PostgreSQL" Version="8.0.0" />
  <PackageReference Include="Microsoft.AspNetCore.SignalR.Client" Version="8.0.0" />
</ItemGroup>
```

#### 3.3. WebScrapingService

Extrai metadados das URLs usando HtmlAgilityPack:

```csharp
public class WebScrapingService : IWebScrapingService
{
    public async Task<LinkMetadata> ExtractMetadataAsync(string url)
    {
        // Fetch HTML
        var response = await _httpClient.GetAsync(url);
        var html = await response.Content.ReadAsStringAsync();

        // Parse with HtmlAgilityPack
        var htmlDoc = new HtmlDocument();
        htmlDoc.LoadHtml(html);

        // Extract metadata
        var title = ExtractTitle(htmlDoc, url);
        var description = ExtractDescription(htmlDoc);
        var imageUrl = ExtractImage(htmlDoc, url);

        return new LinkMetadata
        {
            Title = title,
            Description = description,
            ImageUrl = imageUrl,
            Success = true
        };
    }
}
```

**Estratégia de Extração:**

| Campo | Prioridade |
|-------|------------|
| **Title** | 1. `og:title`<br>2. `twitter:title`<br>3. `<title>`<br>4. hostname |
| **Description** | 1. `og:description`<br>2. `twitter:description`<br>3. `meta[name=description]`<br>4. primeiro `<p>` |
| **Image** | 1. `og:image`<br>2. `twitter:image`<br>3. primeiro `<img>` |

#### 3.4. Worker (Consumer)

Consome mensagens da fila e processa:

```csharp
public class Worker : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var consumer = new AsyncEventingBasicConsumer(_channel);

        consumer.Received += async (model, ea) =>
        {
            var body = ea.Body.ToArray();
            var message = Encoding.UTF8.GetString(body);
            var linkJob = JsonSerializer.Deserialize<LinkMetadataJob>(message);

            // Process the link
            await ProcessLinkMetadataAsync(linkJob, stoppingToken);

            // Acknowledge (remove from queue)
            _channel.BasicAck(deliveryTag: ea.DeliveryTag, multiple: false);
        };

        _channel.BasicConsume(queue: queueName, autoAck: false, consumer: consumer);

        // Keep running
        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(1000, stoppingToken);
        }
    }

    private async Task ProcessLinkMetadataAsync(LinkMetadataJob job, CancellationToken ct)
    {
        // Extract metadata
        var metadata = await _scrapingService.ExtractMetadataAsync(job.Url);

        // Update database
        var linkItem = await _dbContext.LinkItems.FindAsync(job.LinkItemId);
        linkItem.Title = metadata.Title;
        linkItem.Description = metadata.Description;
        await _dbContext.SaveChangesAsync(ct);

        // Notify clients (optional)
        await NotifyClientsAsync(job.CollectionId, linkItem, ct);
    }
}
```

**Características:**
- **Async consumer**: Usa `AsyncEventingBasicConsumer`
- **Manual ACK**: `autoAck: false` para controle manual
- **QoS**: `prefetchCount: 1` para processar uma mensagem por vez
- **Error handling**: Em caso de erro, faz `BasicNack` para requeue

## Fluxo Completo

### 1. Usuário Adiciona Link

```http
POST /api/collections/1/items
Authorization: Bearer <token>
Content-Type: application/json

{
  "url": "https://github.com/dotnet/aspnetcore"
}
```

### 2. API Responde Imediatamente

**Response (202 Accepted):**
```json
{
  "id": 123,
  "title": "Processando...",
  "url": "https://github.com/dotnet/aspnetcore",
  "description": "Extraindo informações da URL...",
  "collectionId": 1,
  "createdAt": "2025-01-18T10:30:00Z"
}
```

### 3. Mensagem Publicada no RabbitMQ

```json
{
  "LinkItemId": 123,
  "CollectionId": 1,
  "Url": "https://github.com/dotnet/aspnetcore"
}
```

### 4. Worker Processa (3-10 segundos depois)

1. Consome mensagem
2. Faz HTTP GET para a URL
3. Extrai metadados:
   - Title: "ASP.NET Core"
   - Description: "ASP.NET Core is a cross-platform .NET framework..."
   - Image: "https://github.com/dotnet.png"
4. Atualiza no banco de dados
5. ACK na mensagem (remove da fila)

### 5. Usuário Vê Atualização

**Opção A:** Refresh manual / Pull-to-refresh
**Opção B:** SignalR push notification (futuro)
**Opção C:** Polling periódico

## Configuração e Execução

### Docker Compose

```bash
# Subir todos os serviços
docker-compose up -d

# Ver logs do RabbitMQ
docker-compose logs -f rabbitmq

# Acessar Management UI
open http://localhost:15672
```

### Executar Worker Localmente

```bash
# Navegar para o projeto Worker
cd backend/LinkShare.Worker

# Restaurar dependências (se tiver dotnet)
dotnet restore

# Executar
dotnet run
```

**Logs esperados:**
```
info: LinkShare.Worker.Worker[0]
      LinkShare Worker starting at: 01/18/2025 10:30:00 +00:00
info: LinkShare.Worker.Services.MessageQueueService[0]
      MessageQueueService connected to RabbitMQ at localhost:5672
info: LinkShare.Worker.Worker[0]
      Worker is now listening for messages on queue: link-metadata-queue
```

### Testar o Fluxo

1. **Adicionar link via API:**
```bash
curl -X POST http://localhost:5000/api/collections/1/items \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://github.com/dotnet/aspnetcore"}'
```

2. **Ver mensagem no RabbitMQ:**
   - Acesse http://localhost:15672
   - Queue: `link-metadata-queue`
   - Deve mostrar 1 mensagem (ou 0 se já processada)

3. **Ver logs do Worker:**
```
info: Extracting metadata for URL: https://github.com/dotnet/aspnetcore
info: Successfully extracted metadata - Title: ASP.NET Core
info: Updated LinkItem 123 with metadata
```

4. **Verificar banco de dados:**
```sql
SELECT * FROM "LinkItems" WHERE "Id" = 123;
-- Title deve estar atualizado (não mais "Processando...")
```

## Tratamento de Erros

### 1. URL Inválida ou Inacessível

```csharp
catch (HttpRequestException ex)
{
    _logger.LogError(ex, "HTTP request failed for URL: {Url}", url);
    metadata.ErrorMessage = $"Request failed: {ex.Message}";
}
```

**Resultado:** Title permanece "Processando..." ou é definido como "Erro ao processar"

### 2. Timeout

```csharp
catch (TaskCanceledException ex)
{
    _logger.LogError(ex, "Request timeout for URL: {Url}", url);
    metadata.ErrorMessage = "Request timeout";
}
```

**HttpClient configurado:**
```csharp
_httpClient.Timeout = TimeSpan.FromSeconds(30);
```

### 3. HTML Malformado

HtmlAgilityPack é tolerante a erros. Se não encontrar metadados, retorna valores padrão:
- Title: hostname da URL
- Description: vazio
- Image: vazio

### 4. Worker Offline

- Mensagens ficam na fila (durable)
- Quando Worker voltar, processa tudo
- Usuários veem "Processando..." até Worker processar

### 5. Reprocessamento

Se Worker falhar ao processar:
```csharp
_channel.BasicNack(deliveryTag: ea.DeliveryTag, multiple: false, requeue: true);
```

Mensagem volta para a fila e será reprocessada.

## Monitoramento

### RabbitMQ Management UI

- **Queues:** Quantidade de mensagens pendentes
- **Consumers:** Quantos workers estão conectados
- **Message rates:** Mensagens/segundo (publish, deliver, ack)
- **Connections:** Quem está conectado (API, Worker)

### Logs do Worker

```
info: Received message: {"LinkItemId":123,"CollectionId":1,"Url":"..."}
info: Extracting metadata for URL: ...
info: Successfully extracted metadata - Title: ...
info: Updated LinkItem 123 with metadata
info: Message processed successfully for LinkItemId: 123
```

### Métricas Importantes

| Métrica | O que indica |
|---------|--------------|
| **Queue depth** | Backlog de processamento |
| **Message rate** | Throughput do sistema |
| **Processing time** | Tempo médio de scraping |
| **Error rate** | URLs problemáticas |

## Escalabilidade

### Múltiplos Workers

Executar múltiplas instâncias do Worker:

```bash
# Terminal 1
dotnet run --project LinkShare.Worker

# Terminal 2
dotnet run --project LinkShare.Worker

# Terminal 3
dotnet run --project LinkShare.Worker
```

RabbitMQ distribui mensagens automaticamente entre os consumers (round-robin).

**Exemplo:**
- 100 links adicionados
- 3 workers rodando
- Cada worker processa ~33 links

### Priorização

Criar filas separadas para diferentes prioridades:

```csharp
// Alta prioridade (links de usuários premium)
_channel.QueueDeclare("link-metadata-high-priority", ...)

// Prioridade normal
_channel.QueueDeclare("link-metadata-queue", ...)
```

## Melhorias Futuras

### 1. SignalR Push do Worker

Implementar SignalR Client no Worker:

```csharp
var hubConnection = new HubConnectionBuilder()
    .WithUrl("http://localhost:5000/hubs/collection")
    .Build();

await hubConnection.StartAsync();

await hubConnection.InvokeAsync("LinkUpdated", new
{
    CollectionId = job.CollectionId,
    LinkItemId = job.LinkItemId,
    Title = metadata.Title,
    Description = metadata.Description
});
```

### 2. Caching de Metadados

Cachear metadados de URLs já processadas:

```csharp
// Redis cache
var cacheKey = $"metadata:{url.GetHashCode()}";
var cached = await _redis.GetAsync(cacheKey);

if (cached != null)
    return JsonSerializer.Deserialize<LinkMetadata>(cached);

// ... scrape and cache ...
await _redis.SetAsync(cacheKey, metadata, TimeSpan.FromDays(7));
```

### 3. Retry Policy

Implementar retry com backoff exponencial:

```csharp
var retryPolicy = Policy
    .Handle<HttpRequestException>()
    .WaitAndRetryAsync(3, retryAttempt =>
        TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)));

await retryPolicy.ExecuteAsync(async () =>
{
    return await _httpClient.GetAsync(url);
});
```

### 4. Dead Letter Queue

Configurar DLQ para mensagens que falharam múltiplas vezes:

```csharp
var args = new Dictionary<string, object>
{
    { "x-dead-letter-exchange", "" },
    { "x-dead-letter-routing-key", "link-metadata-dlq" }
};

_channel.QueueDeclare("link-metadata-queue", arguments: args);
```

### 5. Image Storage

Baixar e hospedar imagens localmente:

```csharp
// Baixar imagem
var imageBytes = await _httpClient.GetByteArrayAsync(metadata.ImageUrl);

// Salvar localmente
var fileName = $"{linkItem.Id}.jpg";
await File.WriteAllBytesAsync($"wwwroot/images/{fileName}", imageBytes);

linkItem.ImageUrl = $"/images/{fileName}";
```

## Segurança

### 1. Rate Limiting

Evitar abuso do web scraping:

```csharp
// Limitar 10 requests por segundo
using var semaphore = new SemaphoreSlim(10, 10);

await semaphore.WaitAsync();
try
{
    await _httpClient.GetAsync(url);
}
finally
{
    semaphore.Release();
}
```

### 2. URL Validation

Validar URLs antes de processar:

```csharp
if (!Uri.TryCreate(url, UriKind.Absolute, out var uri))
{
    throw new ArgumentException("Invalid URL");
}

if (uri.Scheme != "http" && uri.Scheme != "https")
{
    throw new ArgumentException("Only HTTP/HTTPS URLs are allowed");
}
```

### 3. Timeout Global

Garantir que nenhum request trave o Worker:

```csharp
using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));

await Task.WhenAny(
    ProcessLinkMetadataAsync(job, cts.Token),
    Task.Delay(Timeout.Infinite, cts.Token)
);
```

## Troubleshooting

### Worker Não Conecta ao RabbitMQ

**Erro:**
```
RabbitMQ.Client.Exceptions.BrokerUnreachableException: None of the specified endpoints were reachable
```

**Solução:**
1. Verificar se RabbitMQ está rodando: `docker ps | grep rabbitmq`
2. Verificar configuração de host/port em `appsettings.json`
3. Testar conectividade: `telnet localhost 5672`

### Mensagens Não São Consumidas

**Possíveis causas:**
1. Worker não está rodando
2. Queue name diferente entre API e Worker
3. Mensagens travadas (sem ACK)

**Solução:**
1. Ver "Consumers" no RabbitMQ Management UI
2. Verificar `QueueName` em ambos appsettings.json
3. Purgar fila se necessário (Management UI > Queue > Purge)

### Scraping Falha

**Erro:**
```
HTTP request failed with status 403 Forbidden
```

**Solução:**
Adicionar User-Agent:

```csharp
_httpClient.DefaultRequestHeaders.Add("User-Agent",
    "Mozilla/5.0 (compatible; LinkShareBot/1.0)");
```

## Conclusão

O Módulo 9 implementa um sistema robusto de processamento assíncrono que:

✅ **Melhora a experiência do usuário** - API responde em milissegundos
✅ **Escalável** - Múltiplos workers podem processar em paralelo
✅ **Resiliente** - Mensagens persistentes, retry automático, DLQ
✅ **Observável** - Logs detalhados, RabbitMQ Management UI
✅ **Extensível** - Fácil adicionar novos tipos de jobs

O sistema está pronto para produção e pode processar milhares de links por hora!

## Referências

- [RabbitMQ .NET Client Guide](https://www.rabbitmq.com/dotnet-api-guide.html)
- [HtmlAgilityPack Documentation](https://html-agility-pack.net/)
- [.NET Worker Services](https://learn.microsoft.com/en-us/dotnet/core/extensions/workers)
- [Open Graph Protocol](https://ogp.me/)
