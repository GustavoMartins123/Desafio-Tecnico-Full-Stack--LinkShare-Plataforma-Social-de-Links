namespace LinkShare.API.Entities;

public class UserDevice
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string FcmToken { get; set; } = string.Empty;
    public string DeviceName { get; set; } = string.Empty;
    public string Platform { get; set; } = string.Empty; // "android", "ios"
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime LastUsedAt { get; set; } = DateTime.UtcNow;
    public bool IsActive { get; set; } = true;

    // Navigation property
    public User User { get; set; } = null!;
}
