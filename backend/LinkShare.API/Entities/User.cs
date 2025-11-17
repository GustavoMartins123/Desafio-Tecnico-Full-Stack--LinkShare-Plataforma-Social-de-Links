namespace LinkShare.API.Entities;

public class User
{
    public int Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navegação
    public Profile? Profile { get; set; }
    public ICollection<Friendship> RequestedFriendships { get; set; } = new List<Friendship>();
    public ICollection<Friendship> ReceivedFriendships { get; set; } = new List<Friendship>();
    public ICollection<Collection> Collections { get; set; } = new List<Collection>();
    public ICollection<CollectionShare> SharedCollections { get; set; } = new List<CollectionShare>();
}
