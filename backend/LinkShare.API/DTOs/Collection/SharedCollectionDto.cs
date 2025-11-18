namespace LinkShare.API.DTOs.Collection;

public class SharedCollectionDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsPublic { get; set; }
    public int OwnerId { get; set; }
    public string OwnerUsername { get; set; } = string.Empty;
    public string OwnerDisplayName { get; set; } = string.Empty;
    public DateTime SharedAt { get; set; }
    public bool CanEdit { get; set; }
    public int LinkCount { get; set; }
}
