using LinkShare.API.DTOs.LinkItem;

namespace LinkShare.API.DTOs.Collection;

public class CollectionDetailDto
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int OwnerId { get; set; }
    public string OwnerUsername { get; set; } = string.Empty;
    public bool IsPublic { get; set; }
    public DateTime CreatedAt { get; set; }
    public List<LinkItemDto> LinkItems { get; set; } = new();
}
