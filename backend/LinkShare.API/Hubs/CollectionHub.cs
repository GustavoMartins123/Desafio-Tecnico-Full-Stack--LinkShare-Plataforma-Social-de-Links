using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using System.IdentityModel.Tokens.Jwt;

namespace LinkShare.API.Hubs;

[Authorize]
public class CollectionHub : Hub
{
    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId();
        Console.WriteLine($"User {userId} connected to CollectionHub. ConnectionId: {Context.ConnectionId}");
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = GetUserId();
        Console.WriteLine($"User {userId} disconnected from CollectionHub. ConnectionId: {Context.ConnectionId}");
        await base.OnDisconnectedAsync(exception);
    }

    /// <summary>
    /// Join a collection group to receive real-time updates
    /// </summary>
    public async Task JoinCollectionGroup(int collectionId)
    {
        var groupName = GetCollectionGroupName(collectionId);
        await Groups.AddToGroupAsync(Context.ConnectionId, groupName);

        var userId = GetUserId();
        Console.WriteLine($"User {userId} joined collection group: {groupName}");
    }

    /// <summary>
    /// Leave a collection group
    /// </summary>
    public async Task LeaveCollectionGroup(int collectionId)
    {
        var groupName = GetCollectionGroupName(collectionId);
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);

        var userId = GetUserId();
        Console.WriteLine($"User {userId} left collection group: {groupName}");
    }

    /// <summary>
    /// Join friendship notification group to receive friend request updates
    /// </summary>
    public async Task JoinFriendshipGroup()
    {
        var userId = GetUserId();
        var groupName = GetFriendshipGroupName(userId);
        await Groups.AddToGroupAsync(Context.ConnectionId, groupName);

        Console.WriteLine($"User {userId} joined friendship group: {groupName}");
    }

    /// <summary>
    /// Leave friendship notification group
    /// </summary>
    public async Task LeaveFriendshipGroup()
    {
        var userId = GetUserId();
        var groupName = GetFriendshipGroupName(userId);
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, groupName);

        Console.WriteLine($"User {userId} left friendship group: {groupName}");
    }

    private int GetUserId()
    {
        var userIdClaim = Context.User?.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;
        return int.TryParse(userIdClaim, out var userId) ? userId : 0;
    }

    private static string GetCollectionGroupName(int collectionId) => $"collection_{collectionId}";
    private static string GetFriendshipGroupName(int userId) => $"friendship_{userId}";
}
