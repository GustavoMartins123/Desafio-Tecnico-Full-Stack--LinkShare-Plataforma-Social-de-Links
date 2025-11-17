namespace LinkShare.API.Entities;

public class Profile
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public string Bio { get; set; } = string.Empty;
    public string? ProfilePictureUrl { get; set; }

    // Navegação
    public User User { get; set; } = null!;
}
