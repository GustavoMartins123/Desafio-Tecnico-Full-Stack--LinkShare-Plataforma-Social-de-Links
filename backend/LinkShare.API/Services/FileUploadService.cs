namespace LinkShare.API.Services;

public class FileUploadService : IFileUploadService
{
    private readonly IWebHostEnvironment _env;
    private readonly ILogger<FileUploadService> _logger;
    private const long MaxFileSize = 5 * 1024 * 1024; // 5 MB
    private static readonly string[] AllowedExtensions = { ".jpg", ".jpeg", ".png", ".gif", ".webp" };

    public FileUploadService(IWebHostEnvironment env, ILogger<FileUploadService> logger)
    {
        _env = env;
        _logger = logger;
    }

    public async Task<string?> SaveProfilePictureAsync(IFormFile? file)
    {
        if (file == null || file.Length == 0)
        {
            return null;
        }

        // Validate file size
        if (file.Length > MaxFileSize)
        {
            throw new InvalidOperationException($"File size exceeds the maximum allowed size of {MaxFileSize / 1024 / 1024} MB");
        }

        // Validate file extension
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!AllowedExtensions.Contains(extension))
        {
            throw new InvalidOperationException($"File type not allowed. Allowed types: {string.Join(", ", AllowedExtensions)}");
        }

        // Determine upload path
        var uploadPath = Path.Combine(_env.WebRootPath ?? Directory.GetCurrentDirectory(), "wwwroot", "uploads");

        // Create directory if it doesn't exist
        if (!Directory.Exists(uploadPath))
        {
            Directory.CreateDirectory(uploadPath);
            _logger.LogInformation($"Created upload directory: {uploadPath}");
        }

        // Generate unique filename
        var uniqueFileName = $"{Guid.NewGuid()}{extension}";
        var filePath = Path.Combine(uploadPath, uniqueFileName);

        try
        {
            // Save file to disk
            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
            }

            _logger.LogInformation($"File saved successfully: {uniqueFileName}");

            // Return the URL path
            return $"/uploads/{uniqueFileName}";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error saving file: {uniqueFileName}");
            throw new InvalidOperationException("Failed to save file", ex);
        }
    }

    public async Task<bool> DeleteFileAsync(string? fileUrl)
    {
        if (string.IsNullOrWhiteSpace(fileUrl))
        {
            return false;
        }

        try
        {
            // Extract filename from URL (e.g., "/uploads/abc.jpg" -> "abc.jpg")
            var fileName = Path.GetFileName(fileUrl);
            var filePath = Path.Combine(_env.WebRootPath ?? Directory.GetCurrentDirectory(), "wwwroot", "uploads", fileName);

            if (File.Exists(filePath))
            {
                await Task.Run(() => File.Delete(filePath));
                _logger.LogInformation($"File deleted successfully: {fileName}");
                return true;
            }

            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error deleting file: {fileUrl}");
            return false;
        }
    }
}
