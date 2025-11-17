Entendendo o Desafio
Título: Desafio Técnico Full Stack: "LinkShare" (Plataforma Social de Links)

Descrição do Desafio: Construir uma plataforma social completa chamada "LinkShare". A plataforma permite que usuários criem perfis, adicionem amigos e compartilhem "Coleções" de links (artigos, vídeos, produtos) de forma pública ou privada com seus amigos.

Arquitetura e Tecnologias:

Backend: C# (.NET 8) API, Entity Framework Core

Frontend: Flutter (Mobile)

Banco de Dados: PostgreSQL

Containerização: Docker e Docker Compose

Módulo 1: Backend API (C# .NET)
O objetivo é construir uma API robusta que gerencia usuários, perfis, amizades e as coleções de links.

Tarefas:

Modelagem de Dados (Entidades EF Core):

User: (Id, Email, PasswordHash, Username [único], CreatedAt).

Profile: (Id, UserId [FK 1-para-1 para User], DisplayName, Bio, ProfilePictureUrl [string, nullable]).

Friendship: (Id, RequesterId [FK para User], AddresseeId [FK para User], Status [Pending, Accepted, Declined, Blocked], RequestedAt, UpdatedAt).

Collection: (Id, Title, Description, OwnerId [FK para User], IsPublic [bool]).

LinkItem: (Id, Title, URL, Description, CollectionId [FK para Collection]).

CollectionShare: (Id, CollectionId [FK], UserId [FK]) - Tabela de junção para compartilhar coleções privadas com amigos específicos.

Autenticação (Endpoints de JWT):

Crie um AuthController.

POST /api/auth/register: Recebe (Email, Username, Password). Cria o User e um Profile vazio vinculado.

POST /api/auth/login: Retorna um token JWT.

API de Perfis e Amizades:

Crie um ProfileController.

GET /api/profiles/{username}: Retorna o perfil público de um usuário (DisplayName, Bio, ProfilePictureUrl).

PUT /api/profiles/me: (Protegido) Atualiza o perfil do usuário autenticado (DisplayName, Bio).

GET /api/profiles/search?query={query}: Busca usuários por Username ou DisplayName.

Crie um FriendshipController.

POST /api/friends/request/{userId}: (Protegido) Envia um pedido de amizade.

GET /api/friends/requests: (Protegido) Lista pedidos de amizade pendentes recebidos.

PUT /api/friends/requests/{requestId}/accept: (Protegido) Aceita um pedido.

DELETE /api/friends/requests/{requestId}: (Protegido) Recusa um pedido.

GET /api/friends: (Protegido) Lista todos os amigos (status Accepted).

DELETE /api/friends/{friendId}: (Protegido) Remove uma amizade.

API de Coleções e Links:

Crie um CollectionController.

POST /api/collections: (Protegido) Cria uma nova Collection (IsPublic = false/true).

GET /api/collections/me: (Protegido) Lista todas as coleções do usuário autenticado.

GET /api/collections/user/{username}: Lista as coleções públicas de um usuário.

POST /api/collections/{collectionId}/items: (Protegido) Adiciona um novo LinkItem a uma coleção. (Validar se o usuário é o dono).

GET /api/collections/{collectionId}: (Protegido) Detalhes de uma coleção.

Lógica de Permissão: O usuário deve ser o Owner OU a coleção deve ser IsPublic OU o usuário deve estar na tabela CollectionShare.

POST /api/collections/{collectionId}/share/{friendId}: (Protegido) Compartilha uma coleção privada com um amigo (adiciona na CollectionShare).

Módulo 2: Frontend (Flutter)
O objetivo é construir o cliente mobile para interagir com a API.

Tarefas:

Configuração e Autenticação:

Configure o app com dio (ou http), flutter_riverpod e shared_preferences.

Crie as telas de LoginScreen e RegisterScreen (incluindo campo Username).

Implemente o fluxo de login/logout e armazenamento de token.

Layout Principal (Navegação com Tabs):

Crie uma tela principal (HomeScreen) com BottomNavigationBar contendo 3 ou 4 tabs:

Tab 1: Home/Feed (Bônus): (Se houver tempo) Um feed de coleções públicas recentes.

Tab 2: Minhas Coleções: (Essencial) Chama GET /api/collections/me.

Tab 3: Amigos: (Essencial) Tela para gerenciar amizades.

Tab 4: Perfil: (Essencial) Tela para ver e editar o perfil (GET /api/profiles/me).

Fluxo de Coleções:

Na Tab "Minhas Coleções", exiba as listas.

Implemente a navegação para CollectionDetailScreen ao tocar em uma coleção.

CollectionDetailScreen: Chama GET /api/collections/{collectionId} e exibe os LinkItem.

Adicione botões para "Adicionar Item" (chama POST .../items) e "Compartilhar" (chama POST .../share/{friendId}).

Fluxo Social (Amigos e Perfis):

Na Tab "Amigos":

Crie uma TabBar (sub-tabs) para "Meus Amigos" (GET /api/friends) e "Pedidos Pendentes" (GET /api/friends/requests).

Implemente os botões de "Aceitar", "Recusar" e "Remover Amigo".

Adicione um botão de "Procurar Amigos" que navega para uma SearchScreen.

SearchScreen: Usa um TextField para chamar GET /api/profiles/search?query=.... Exibe os resultados e um botão "Adicionar" (chama POST /api/friends/request/{userId}).

Na Tab "Perfil":

Exiba os dados de GET /api/profiles/me.

Adicione um botão "Editar" que permite ao usuário atualizar DisplayName e Bio (chama PUT /api/profiles/me).

Módulo 3: Containerização (Docker)
O objetivo é orquestrar a API e o Banco de Dados para execução em qualquer ambiente.

Tarefas:

Dockerfile para a API (.NET):

Crie um Dockerfile na raiz do projeto C# (Módulo 1).

Use uma build multi-stage:

Estágio 1: (Base: mcr.microsoft.com/dotnet/sdk:8.0) Restaura, constrói e publica a aplicação.

Estágio 2: (Base: mcr.microsoft.com/dotnet/aspnet:8.0) Copia a DLL publicada e define o ENTRYPOINT.

Arquivo docker-compose.yml:

Crie um docker-compose.yml na raiz do repositório.

Defina dois serviços:

db (PostgreSQL):

Imagem: postgres:16-alpine.

Variáveis de ambiente (ex: POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB).

Volume: Defina um volume nomeado ou bind mount para persistência (ex: pgdata:/var/lib/postgresql/data).

api (Backend):

build: (contexto: ./backend).

depends_on: db.

ports: (ex: 8080:8080).

environment: Injetar a ConnectionString (apontando para Host=db) e chaves do JWT.

Módulo 4: Bônus Avançado (Upload de Imagem)
O objetivo é implementar o upload da foto de perfil, exigindo modificações full stack.

Tarefas:

Backend (API):

Modifique o docker-compose.yml (serviço api) para incluir um volume para uploads (ex: - ./api_uploads:/app/wwwroot/uploads).

Modifique o Program.cs para servir arquivos estáticos dessa nova pasta (ex: app.UseStaticFiles(new StaticFileOptions { FileProvider = ..., RequestPath = "/api/uploads" })).

Crie um novo endpoint: POST /api/profiles/me/picture.

Use [FromForm] para aceitar IFormFile.

Salve o arquivo no volume (/app/wwwroot/uploads).

Salve a URL (ex: /api/uploads/arquivo.jpg) na coluna ProfilePictureUrl da entidade Profile.

Frontend (Flutter):

Adicione o pacote image_picker.

Na ProfileScreen, adicione um botão "Editar Foto".

Use o image_picker para selecionar uma imagem.

Use a lógica condicional (kIsWeb) para MultipartFile.fromBytes (Web) ou MultipartFile.fromFile (Mobile) para enviar o arquivo como FormData para POST /api/profiles/me/picture.

Módulo 5: Capacidade "Offline-First" (Flutter com Drift)
Objetivo: Fazer o aplicativo funcionar sem internet. O usuário deve ser capaz de ver suas coleções, links e amigos que já foram carregados anteriormente. Isso muda o app de "dependente de API" para "offline-first".

Tecnologias-Chave: drift (para o banco local) e flutter_riverpod (para gerenciar o estado e os repositórios).

Tarefas:

Configuração do Drift (Banco Local):

Adicione drift, sqlite3_flutter_libs e drift_dev ao pubspec.yaml.

Defina suas tabelas locais. Elas serão espelhos das suas entidades da API (ex: LocalUsers, LocalCollections, LocalLinkItems, LocalFriendships).

Crie o AppDatabase (classe principal do drift) e o instancie como um Provider (Riverpod) global.

Refatoração do Repositório (A "Mágica"):

Onde você tinha um Repository que apenas chamava o dio (API), você agora terá uma "Fonte da Verdade" (Source of Truth).

O Riverpod é perfeito para isso. O seu Provider do repositório vai gerenciar a lógica de sincronização.

Lógica de Leitura (Fluxo Offline):

Quando a UI (ex: CollectionScreen) pedir dados (ex: ref.watch(collectionsProvider)), o fluxo será:

O collectionsProvider (Riverpod) chama o Repository.

O Repository imediatamente lê e retorna os dados do banco drift local. (Isso é quase instantâneo).

A UI exibe os dados locais (antigos, mas presentes).

Em paralelo, o Repository faz uma chamada dio (API) para GET /api/collections/me.

Quando a API responde, o Repository limpa as coleções antigas do drift e insere os novos dados do JSON.

Como a UI está "assistindo" (watching) o drift, ela se atualiza automaticamente com os novos dados.

Lógica de Escrita (Fila de Sincronização):

E se o usuário estiver offline e tentar adicionar um novo link?

Crie uma tabela no drift chamada PendingActions.

Quando o usuário (offline) clica em "Salvar Link":

O Repository tenta chamar o POST /api/collections/.../items.

O dio falha (sem internet).

No catch (e), em vez de dar erro, o Repository salva essa ação na tabela PendingActions (ex: action: 'create_link', payload: '{...}').

Ele também salva o novo link no drift local (com um status "pendente"), para que a UI mostre o item.

Crie um SyncService que, periodicamente (ou quando o app detectar internet), lê a tabela PendingActions e tenta executar as ações contra a API real.

Módulo 6: Segurança de API Avançada (JTI, Blacklist e Refresh Tokens)
Objetivo: Aumentar drasticamente a segurança da autenticação. JWTs puros são "burros" (não podem ser revogados). Se um token vazar, ele é válido até expirar. Vamos consertar isso.

Tecnologias-Chave: Redis (para a blacklist), JTI (JWT ID) e Refresh Tokens.

Tarefas (Backend - C#):

Adicione o Redis ao Compose:

A "blacklist" precisa ser extremamente rápida. Um banco SQL é lento demais para isso. O Redis (cache em memória) é a ferramenta padrão.

Adicione um novo serviço redis ao seu docker-compose.yml (imagem: redis:alpine).

Configure a API .NET para se conectar ao Redis (ex: StackExchange.Redis).

Implemente "Refresh Tokens":

Se vamos invalidar tokens, eles precisam ter vida curta (ex: 15 minutos).

Access Token (JWT): Vida curta (15 min). Usado para acessar endpoints ([Authorize]).

Refresh Token (Opaque): Vida longa (ex: 7 dias). É uma string aleatória (ex: Guid) salva no banco de dados (numa tabela UserTokens).

No POST /api/auth/login, você agora retorna ambos os tokens.

Implemente o JTI (JWT ID):

Ao criar o "Access Token" (o JWT de 15 min), adicione um Claim especial:

new Claim("jti", Guid.NewGuid().ToString())

O JTI (JWT ID) é um ID único para aquele token específico.

Crie o Endpoint POST /api/auth/refresh:

Este endpoint não é protegido.

Ele recebe o RefreshToken (o de 7 dias).

A API valida esse token contra o banco de dados.

Se for válido, a API gera um novo Access Token (com um novo JTI) e um novo Refresh Token (para rotação).

Crie o Endpoint POST /api/auth/logout (A Blacklist):

Este endpoint é protegido (requer o Access Token).

Lógica:

Extraia o jti do token que o usuário está usando para fazer logout.

Extraia a data de expiração (exp) do token.

Salve o jti no Redis.

Configure o jti no Redis para expirar exatamente quando o token original expiraria. (Isso evita que seu Redis encha de lixo para sempre).

Crie o Middleware de Verificação:

Em .NET, crie um IMiddleware ou IAuthenticationFilter.

Este middleware roda em toda requisição protegida.

Lógica:

Valida a assinatura do token (o .NET já faz).

Extrai o jti do token.

Faz uma consulta super rápida ao Redis para ver se esse jti está na blacklist.

Se estiver, a API retorna 401 Unauthorized, mesmo que a assinatura e a data de expiração do token estejam válidas.

Tarefas (Frontend - Flutter):

O Repository (ou um AuthService) agora precisa salvar dois tokens (Access e Refresh).

Use um Interceptor do dio para lidar com 401 Unauthorized:

O Flutter faz uma chamada GET /api/collections com um token de 15 min expirado.

A API retorna 401.

O Interceptor do dio "pega" esse erro.

Ele pausa a requisição original e faz uma nova chamada para POST /api/auth/refresh (enviando o Refresh Token).

A API retorna um novo Access Token.

O Interceptor salva esse novo token e refaz a chamada original (GET /api/collections), que agora funciona.

Tudo isso acontece sem o usuário perceber.

Módulo 7: Colaboração e UI em Tempo Real
Objetivo: Fazer o aplicativo parecer "vivo". Quando um amigo aceita seu convite, ou quando um colaborador adiciona um link a uma coleção que você está vendo, a sua tela deve atualizar instantaneamente, sem precisar de um "puxar para atualizar".

Tecnologias-Chave: SignalR (no .NET) e signalr_flutter (no Flutter).

Tarefas (Backend - C#):

Adicionar SignalR: Adicione o serviço do SignalR ao Program.cs.

Criar um "Hub": Crie um CollectionHub (que herda de Hub).

Gerenciar Conexões: Quando um usuário abrir uma coleção no app, o Flutter deve se conectar ao Hub e entrar em um "Grupo" do SignalR (ex: await Groups.AddToGroupAsync(Context.ConnectionId, $"collection_{collectionId}");).

Disparar Eventos: No CollectionController, depois de salvar um novo LinkItem no banco, você deve também notificar o Hub.

Ex: await _hubContext.Clients.Group($"collection_{collectionId}").SendAsync("NewLinkAdded", newLinkDto);

Tarefas (Frontend - Flutter):

Adicionar Pacote: Use o signalr_flutter.

Conectar ao Hub: No initState (ou no Provider) da sua CollectionDetailScreen, conecte-se ao Hub do SignalR e entre no grupo (ex: hubConnection.invoke("JoinCollectionGroup", args: [collectionId]);).

Ouvir Eventos: Crie um listener para o evento NewLinkAdded.

hubConnection.on("NewLinkAdded", (data) => { ... });

Atualizar o Cache: Quando esse evento for recebido, pegue o DTO do novo link e insira-o diretamente no banco de dados local (Drift). Como o seu Riverpod está "assistindo" o Drift, a UI será atualizada automaticamente em tempo real.

Módulo 8: Notificações Push
Objetivo: Engajar o usuário quando ele não está com o app aberto. Ele deve receber uma notificação push para interações sociais importantes.

Tecnologias-Chave: Firebase Cloud Messaging (FCM) e firebase_messaging (Flutter).

Tarefas (Frontend - Flutter):

Configurar Firebase: Adicione o Firebase ao projeto Flutter.

Pedir Permissão: Solicite permissão de notificação ao usuário.

Obter Token: No login (ou inicialização), obtenha o Token FCM do dispositivo: final fcmToken = await FirebaseMessaging.instance.getToken();

Enviar Token à API: Crie um endpoint (ex: POST /api/profiles/me/device) e envie esse fcmToken para o backend.

Ouvir Notificações: Configure os handlers de notificação (em background, foreground e terminated).

Tarefas (Backend - C#):

Armazenar Tokens: Adicione uma nova tabela (ex: UserDevice) para armazenar múltiplos fcmToken por usuário.

Adicionar Admin SDK: Use o pacote FirebaseAdmin.

Disparar Notificações: Em pontos críticos, envie a notificação.

Exemplo: No FriendshipController, após um POST /api/friends/request/{userId}:

O serviço encontra o userId do destinatário.

Busca os fcmTokens daquele usuário na tabela UserDevice.

Monta uma mensagem (ex: title: "Novo Pedido de Amizade", body: "Usuário X quer ser seu amigo.").

Usa o FirebaseMessaging.DefaultInstance.SendMulticastAsync(...) para enviar a notificação para a Google, que a repassa para o dispositivo.

Módulo 9: Processamento Assíncrono e Filas (Nível Avançado)
Objetivo: Lidar com tarefas lentas sem travar a API ou a experiência do usuário. Exemplo: Ao adicionar um link (URL), o sistema deve, em background, buscar o título da página, uma descrição e uma imagem (web scraping).

Tecnologias-Chave: RabbitMQ (fila de mensagens), HtmlAgilityPack (Web Scraping) e .NET Worker Service.

Tarefas (Infraestrutura):

Adicionar RabbitMQ: Adicione um serviço rabbitmq ao seu docker-compose.yml.

Adicionar um "Worker": Crie um novo projeto .NET na sua solução (ex: LinkShare.Worker, usando o template "Worker Service").

Tarefas (Backend - API):

Mudar o Fluxo: O POST /api/collections/{collectionId}/items agora é muito mais rápido:

O usuário envia apenas a URL.

A API salva o LinkItem no banco com Title = "Processando...".

A API publica uma mensagem (ex: { "LinkItemId": 123, "Url": "http..." }) na fila do RabbitMQ.

A API retorna 202 Accepted para o Flutter imediatamente.

Tarefas (Backend - Worker):

Ouvir a Fila: O Worker se conecta ao RabbitMQ e fica ouvindo por novas mensagens.

Processar a Mensagem: Ao receber uma mensagem:

Ele usa o HtmlAgilityPack para acessar a URL.

Ele extrai a tag <title>, a meta description e a og:image.

Ele se conecta ao PostgreSQL e atualiza a linha do LinkItem (ID 123) com os dados reais.

Resultado: O usuário vê o link aparecer como "Processando..." e, segundos depois (graças ao Módulo 7: SignalR), o título e a descrição aparecem magicamente na tela.

Módulo 10: DevOps e Observabilidade
Objetivo: Automatizar a entrega e monitorar a saúde do aplicativo em produção.

Tecnologias-Chave: GitHub Actions (CI/CD) e Serilog + Seq/ELK (Logging).

Tarefas (CI/CD):

Criar Workflow: Crie um arquivo .github/workflows/build-and-push.yml.

Definir Gatilho: Rodar on: push para a branch main.

Definir "Jobs":

Job 1: build_and_test:

Checkout do código.

Configurar o .NET SDK.

Rodar dotnet restore, dotnet build e dotnet test.

Job 2: build_docker:

(Depende do Job 1) Fazer login no Docker Hub (usando secrets).

Rodar docker build para a API.

Rodar docker push seu-usuario/linkshare-api:latest.

(Bônus): Ter um segundo workflow que roda flutter analyze e flutter test no código do app.

Tarefas (Observabilidade - Backend):

Logging Estruturado: Adicione o Serilog à API .NET. Em vez de ILogger.LogInformation("Erro... {var}"), você usará logging estruturado.

Centralizar Logs:

Adicione um serviço seq (ou o stack ELK) ao docker-compose.yml.

Configure o Serilog para enviar todos os logs (da API, do Worker) para este serviço central.

Resultado: Em vez de dar docker logs [container], você terá uma UI onde pode pesquisar todos os logs de todos os serviços, podendo filtrar por UserId, CollectionId, etc.
