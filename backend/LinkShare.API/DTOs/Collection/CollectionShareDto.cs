namespace LinkShare.API.DTOs.Collection;

public class CollectionShareDto
{
    public int Id { get; set; }
    public int CollectionId { get; set; }
    public string CollectionName { get; set; } = string.Empty;
    public int SharedWithUserId { get; set; }
    public string SharedWithUsername { get; set; } = string.Empty;
    public string SharedWithDisplayName { get; set; } = string.Empty;
    public DateTime SharedAt { get; set; }
    public bool CanEdit { get; set; }
}
