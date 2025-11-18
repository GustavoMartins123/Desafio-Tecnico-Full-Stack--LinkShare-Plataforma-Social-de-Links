namespace LinkShare.API.Entities;

public class CollectionShare
{
    public int Id { get; set; }
    public int CollectionId { get; set; }
    public int UserId { get; set; }
    public DateTime SharedAt { get; set; } = DateTime.UtcNow;
    public bool CanEdit { get; set; } = false;

    // Navegação
    public Collection Collection { get; set; } = null!;
    public User User { get; set; } = null!;
}
