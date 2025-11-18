namespace LinkShare.API.Services;

public interface IFileUploadService
{
    Task<string?> SaveProfilePictureAsync(IFormFile? file);
    Task<bool> DeleteFileAsync(string? fileUrl);
}
