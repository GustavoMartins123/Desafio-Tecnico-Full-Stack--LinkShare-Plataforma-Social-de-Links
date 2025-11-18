namespace LinkShare.API.DTOs.Feed;

public class ActivityDto
{
    public int UserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public string UserDisplayName { get; set; } = string.Empty;
    public string? UserProfilePictureUrl { get; set; }
    public ActivityType ActivityType { get; set; }
    public DateTime Timestamp { get; set; }

    // Collection-related fields
    public int? CollectionId { get; set; }
    public string? CollectionTitle { get; set; }
    public bool? CollectionIsPublic { get; set; }

    // Link-related fields
    public int? LinkItemId { get; set; }
    public string? LinkItemTitle { get; set; }
    public string? LinkItemUrl { get; set; }
    public string? LinkItemDescription { get; set; }
}
