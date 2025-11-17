namespace LinkShare.API.Entities;

public class Collection
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int OwnerId { get; set; }
    public bool IsPublic { get; set; } = false;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navegação
    public User Owner { get; set; } = null!;
    public ICollection<LinkItem> LinkItems { get; set; } = new List<LinkItem>();
    public ICollection<CollectionShare> Shares { get; set; } = new List<CollectionShare>();
}
