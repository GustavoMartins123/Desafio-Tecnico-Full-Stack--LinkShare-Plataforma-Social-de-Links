namespace LinkShare.API.Entities;

public class LinkItem
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string URL { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int CollectionId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navegação
    public Collection Collection { get; set; } = null!;
}
