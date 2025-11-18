# Módulo 4 - Upload de Foto de Perfil

## Descrição

Este módulo implementa a funcionalidade de upload de foto de perfil, permitindo que usuários carreguem, atualizem e excluam suas fotos de perfil através da aplicação móvel.

## Implementação

### Backend (.NET 8 API)

#### 1. Configuração de Arquivos Estáticos

**Arquivo:** `backend/LinkShare.API/Program.cs`

- Registrado serviço `IFileUploadService` no container de DI
- Configurado middleware `UseStaticFiles` para servir arquivos da pasta `wwwroot/uploads`
- Rota de acesso: `/uploads/{filename}`

```csharp
builder.Services.AddScoped<IFileUploadService, FileUploadService>();

app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(
        Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "uploads")
    ),
    RequestPath = "/uploads"
});
```

#### 2. Serviço de Upload de Arquivos

**Arquivos:**
- `backend/LinkShare.API/Services/IFileUploadService.cs`
- `backend/LinkShare.API/Services/FileUploadService.cs`

**Funcionalidades:**
- Validação de tamanho (máximo 5 MB)
- Validação de extensões permitidas (.jpg, .jpeg, .png, .gif, .webp)
- Geração de nomes únicos usando GUID
- Salvamento seguro em `wwwroot/uploads/`
- Exclusão de arquivos antigos

**Métodos:**
- `SaveProfilePictureAsync(IFormFile? file)`: Salva imagem e retorna URL
- `DeleteFileAsync(string? fileUrl)`: Remove arquivo do sistema

#### 3. Endpoints de Perfil

**Arquivo:** `backend/LinkShare.API/Controllers/ProfilesController.cs`

##### POST /api/profiles/me/picture
Faz upload de uma nova foto de perfil.

**Request:**
- Content-Type: `multipart/form-data`
- Body: `file` (IFormFile)

**Response:** `ProfileDto` atualizado com `profilePictureUrl`

**Processo:**
1. Valida arquivo (tamanho e extensão)
2. Deleta foto anterior se existir
3. Salva nova foto
4. Atualiza campo `ProfilePictureUrl` no banco
5. Retorna perfil atualizado

##### DELETE /api/profiles/me/picture
Remove a foto de perfil atual.

**Response:** `ProfileDto` com `profilePictureUrl = null`

**Processo:**
1. Busca perfil do usuário autenticado
2. Deleta arquivo do sistema
3. Define `ProfilePictureUrl = null`
4. Retorna perfil atualizado

### Frontend (Flutter)

#### 1. Dependências

**Arquivo:** `mobile/linkshare_app/pubspec.yaml`

Adicionadas dependências:
- `image_picker: ^1.0.7` - Seleção de imagens da câmera/galeria
- `http_parser: ^4.0.2` - Parse de MIME types para upload

#### 2. Serviço de Perfil

**Arquivo:** `mobile/linkshare_app/lib/services/profile_service.dart`

##### Método: `uploadProfilePicture(File imageFile)`
- Detecta MIME type baseado na extensão do arquivo
- Cria `MultipartFile` com tipo correto
- Envia requisição POST para `/api/profiles/me/picture`
- Retorna `Profile` atualizado

##### Método: `deleteProfilePicture()`
- Envia requisição DELETE para `/api/profiles/me/picture`
- Retorna `Profile` com foto removida

#### 3. Tela de Edição de Perfil

**Arquivo:** `mobile/linkshare_app/lib/screens/profile/edit_profile_screen.dart`

**Funcionalidades Implementadas:**

##### Seleção de Imagem
- Modal bottom sheet com opções: "Take Photo" e "Choose from Gallery"
- Integração com `ImagePicker`
- Compressão automática (1024x1024, qualidade 85%)

##### Upload de Foto
- Indicador de progresso durante upload (`_isUploadingPhoto`)
- Atualização em tempo real da foto exibida
- Feedback visual com `SnackBar`

##### Menu de Ações
- `PopupMenuButton` sobreposto ao avatar
- Opção "Change Photo": Abre seleção de imagem
- Opção "Delete Photo": Exibe confirmação antes de deletar

##### Exclusão de Foto
- Dialog de confirmação
- Remoção do arquivo no servidor
- Atualização imediata da UI

##### UI/UX
- Avatar com raio de 60
- Placeholder com inicial do nome quando sem foto
- Tratamento de erro ao carregar imagem da rede
- Loading indicator durante operações

## Estrutura de Arquivos Criados/Modificados

```
backend/LinkShare.API/
├── Services/
│   ├── IFileUploadService.cs          (NOVO)
│   └── FileUploadService.cs           (NOVO)
├── Controllers/
│   └── ProfilesController.cs          (MODIFICADO - 2 endpoints adicionados)
├── Program.cs                         (MODIFICADO - static files + DI)
└── wwwroot/
    └── uploads/                       (CRIADO - pasta para imagens)

mobile/linkshare_app/
├── pubspec.yaml                       (MODIFICADO - image_picker)
├── lib/
│   ├── services/
│   │   └── profile_service.dart       (MODIFICADO - 2 métodos adicionados)
│   └── screens/profile/
│       └── edit_profile_screen.dart   (MODIFICADO - upload completo)
```

## Fluxo de Upload

```
1. Usuário abre EditProfileScreen
2. Clica no ícone de câmera
3. Seleciona "Take Photo" ou "Choose from Gallery"
4. ImagePicker abre câmera/galeria
5. Usuário seleciona/captura imagem
6. Flutter comprime imagem (1024x1024, 85%)
7. ProfileService cria FormData com multipart
8. POST /api/profiles/me/picture
9. Backend valida arquivo (tamanho, extensão)
10. Backend deleta foto antiga (se existir)
11. Backend gera nome único (GUID)
12. Backend salva em wwwroot/uploads/
13. Backend atualiza Profile.ProfilePictureUrl
14. Backend retorna ProfileDto atualizado
15. Flutter atualiza estado local
16. Avatar exibe nova foto
17. SnackBar confirma sucesso
```

## Fluxo de Exclusão

```
1. Usuário clica no ícone de câmera
2. Seleciona "Delete Photo"
3. Dialog de confirmação aparece
4. Usuário confirma exclusão
5. DELETE /api/profiles/me/picture
6. Backend deleta arquivo físico
7. Backend define ProfilePictureUrl = null
8. Backend retorna ProfileDto atualizado
9. Flutter atualiza estado local
10. Avatar exibe placeholder com inicial
11. SnackBar confirma exclusão
```

## Validações e Segurança

### Backend
- ✅ Tamanho máximo: 5 MB
- ✅ Extensões permitidas: .jpg, .jpeg, .png, .gif, .webp
- ✅ Nomes únicos (GUID) para evitar conflitos
- ✅ Validação de existência de arquivo antes de deletar
- ✅ Autenticação JWT obrigatória nos endpoints
- ✅ Logs de erro para debugging

### Frontend
- ✅ Compressão automática para reduzir tamanho
- ✅ Tratamento de erros de rede
- ✅ Feedback visual durante operações
- ✅ Confirmação antes de deletar
- ✅ Estado de loading durante upload

## URLs de Acesso

Após upload, a foto fica acessível em:
```
http://localhost:8080/uploads/{guid}.{ext}
```

Exemplo:
```
http://localhost:8080/uploads/a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg
```

## Tecnologias Utilizadas

### Backend
- **ASP.NET Core 8.0** - Framework web
- **IFormFile** - Manipulação de arquivos enviados
- **PhysicalFileProvider** - Servir arquivos estáticos
- **GUID** - Geração de nomes únicos
- **Path.Combine** - Manipulação segura de caminhos

### Frontend
- **image_picker** - Seleção de imagens
- **MultipartFile** - Upload de arquivos
- **http_parser** - Parse de MIME types
- **File I/O** - Leitura de arquivos locais

## Como Usar

### 1. Iniciar Backend
```bash
cd backend/LinkShare.API
dotnet run
```

### 2. Iniciar App Flutter
```bash
cd mobile/linkshare_app
flutter pub get
flutter run
```

### 3. No Aplicativo
1. Faça login
2. Navegue para a aba "Profile"
3. Toque em "Edit Profile"
4. Toque no ícone de câmera no avatar
5. Escolha "Take Photo" ou "Choose from Gallery"
6. Selecione/capture imagem
7. Aguarde upload
8. Foto atualizada automaticamente

### 4. Para Deletar Foto
1. Em "Edit Profile"
2. Toque no ícone de câmera
3. Escolha "Delete Photo"
4. Confirme exclusão
5. Avatar volta ao placeholder

## Observações Importantes

1. **Pasta wwwroot/uploads**: Criada automaticamente pelo serviço se não existir
2. **Persistência**: Arquivos são salvos em disco (não em memória)
3. **Docker**: A pasta `wwwroot/uploads` deve ser mapeada como volume para persistência
4. **Produção**: Considerar uso de CDN (S3, Azure Blob, CloudFlare R2) para escalabilidade
5. **Limpeza**: Arquivos órfãos (de perfis deletados) devem ser removidos periodicamente

## Melhorias Futuras (Fora do Escopo)

- [ ] Upload para cloud storage (S3, Azure Blob)
- [ ] Redimensionamento server-side com ImageSharp
- [ ] Cache de imagens no app com cached_network_image
- [ ] Suporte a WebP no backend para melhor compressão
- [ ] Cropping de imagem antes do upload
- [ ] Progress indicator durante upload
- [ ] Limite de taxa de upload (rate limiting)
- [ ] Scan de vírus em arquivos enviados

---

**Módulo 4 concluído com sucesso!** ✅

Todos os recursos de upload de foto de perfil estão funcionais e integrados entre backend e frontend.
