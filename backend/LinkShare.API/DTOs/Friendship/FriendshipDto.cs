using LinkShare.API.Entities;

namespace LinkShare.API.DTOs.Friendship;

public class FriendshipDto
{
    public int Id { get; set; }
    public int RequesterId { get; set; }
    public string RequesterUsername { get; set; } = string.Empty;
    public string RequesterDisplayName { get; set; } = string.Empty;
    public int AddresseeId { get; set; }
    public string AddresseeUsername { get; set; } = string.Empty;
    public string AddresseeDisplayName { get; set; } = string.Empty;
    public FriendshipStatus Status { get; set; }
    public DateTime RequestedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
