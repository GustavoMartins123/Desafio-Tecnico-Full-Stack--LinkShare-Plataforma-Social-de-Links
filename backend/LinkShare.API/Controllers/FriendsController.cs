using System.Security.Claims;
using LinkShare.API.Data;
using LinkShare.API.DTOs.Friendship;
using LinkShare.API.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LinkShare.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class FriendsController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public FriendsController(ApplicationDbContext context)
    {
        _context = context;
    }

    /// <summary>
    /// Send a friend request to a user
    /// </summary>
    /// <param name="userId">User ID to send request to</param>
    /// <returns>Created friendship request</returns>
    [HttpPost("request/{userId}")]
    public async Task<ActionResult<FriendshipDto>> SendFriendRequest(int userId)
    {
        var currentUserId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // Can't send request to yourself
        if (currentUserId == userId)
        {
            return BadRequest(new { message = "Cannot send friend request to yourself" });
        }

        // Check if target user exists
        var targetUser = await _context.Users.Include(u => u.Profile).FirstOrDefaultAsync(u => u.Id == userId);
        if (targetUser == null)
        {
            return NotFound(new { message = "User not found" });
        }

        // Check if friendship already exists (either direction)
        var existingFriendship = await _context.Friendships
            .FirstOrDefaultAsync(f =>
                (f.RequesterId == currentUserId && f.AddresseeId == userId) ||
                (f.RequesterId == userId && f.AddresseeId == currentUserId));

        if (existingFriendship != null)
        {
            return BadRequest(new { message = "Friendship request already exists" });
        }

        // Create friendship request
        var friendship = new Friendship
        {
            RequesterId = currentUserId,
            AddresseeId = userId,
            Status = FriendshipStatus.Pending,
            RequestedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _context.Friendships.Add(friendship);
        await _context.SaveChangesAsync();

        // Load relationships for response
        await _context.Entry(friendship)
            .Reference(f => f.Requester)
            .Query()
            .Include(u => u.Profile)
            .LoadAsync();

        await _context.Entry(friendship)
            .Reference(f => f.Addressee)
            .Query()
            .Include(u => u.Profile)
            .LoadAsync();

        return CreatedAtAction(nameof(GetFriendRequests), new FriendshipDto
        {
            Id = friendship.Id,
            RequesterId = friendship.RequesterId,
            RequesterUsername = friendship.Requester.Username,
            RequesterDisplayName = friendship.Requester.Profile?.DisplayName ?? friendship.Requester.Username,
            AddresseeId = friendship.AddresseeId,
            AddresseeUsername = friendship.Addressee.Username,
            AddresseeDisplayName = friendship.Addressee.Profile?.DisplayName ?? friendship.Addressee.Username,
            Status = friendship.Status,
            RequestedAt = friendship.RequestedAt,
            UpdatedAt = friendship.UpdatedAt
        });
    }

    /// <summary>
    /// Get pending friend requests received by current user
    /// </summary>
    /// <returns>List of pending friendship requests</returns>
    [HttpGet("requests")]
    public async Task<ActionResult<List<FriendshipDto>>> GetFriendRequests()
    {
        var currentUserId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var requests = await _context.Friendships
            .Include(f => f.Requester)
                .ThenInclude(u => u.Profile)
            .Include(f => f.Addressee)
                .ThenInclude(u => u.Profile)
            .Where(f => f.AddresseeId == currentUserId && f.Status == FriendshipStatus.Pending)
            .Select(f => new FriendshipDto
            {
                Id = f.Id,
                RequesterId = f.RequesterId,
                RequesterUsername = f.Requester.Username,
                RequesterDisplayName = f.Requester.Profile!.DisplayName,
                AddresseeId = f.AddresseeId,
                AddresseeUsername = f.Addressee.Username,
                AddresseeDisplayName = f.Addressee.Profile!.DisplayName,
                Status = f.Status,
                RequestedAt = f.RequestedAt,
                UpdatedAt = f.UpdatedAt
            })
            .ToListAsync();

        return Ok(requests);
    }

    /// <summary>
    /// Accept a friend request
    /// </summary>
    /// <param name="requestId">Friendship request ID</param>
    /// <returns>Updated friendship</returns>
    [HttpPut("requests/{requestId}/accept")]
    public async Task<ActionResult<FriendshipDto>> AcceptFriendRequest(int requestId)
    {
        var currentUserId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var friendship = await _context.Friendships
            .Include(f => f.Requester)
                .ThenInclude(u => u.Profile)
            .Include(f => f.Addressee)
                .ThenInclude(u => u.Profile)
            .FirstOrDefaultAsync(f => f.Id == requestId);

        if (friendship == null)
        {
            return NotFound(new { message = "Friend request not found" });
        }

        // Only the addressee can accept
        if (friendship.AddresseeId != currentUserId)
        {
            return Forbid();
        }

        // Must be pending
        if (friendship.Status != FriendshipStatus.Pending)
        {
            return BadRequest(new { message = "Friend request is not pending" });
        }

        friendship.Status = FriendshipStatus.Accepted;
        friendship.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();

        return Ok(new FriendshipDto
        {
            Id = friendship.Id,
            RequesterId = friendship.RequesterId,
            RequesterUsername = friendship.Requester.Username,
            RequesterDisplayName = friendship.Requester.Profile!.DisplayName,
            AddresseeId = friendship.AddresseeId,
            AddresseeUsername = friendship.Addressee.Username,
            AddresseeDisplayName = friendship.Addressee.Profile!.DisplayName,
            Status = friendship.Status,
            RequestedAt = friendship.RequestedAt,
            UpdatedAt = friendship.UpdatedAt
        });
    }

    /// <summary>
    /// Decline/delete a friend request
    /// </summary>
    /// <param name="requestId">Friendship request ID</param>
    /// <returns>No content</returns>
    [HttpDelete("requests/{requestId}")]
    public async Task<ActionResult> DeclineFriendRequest(int requestId)
    {
        var currentUserId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var friendship = await _context.Friendships
            .FirstOrDefaultAsync(f => f.Id == requestId);

        if (friendship == null)
        {
            return NotFound(new { message = "Friend request not found" });
        }

        // Only the addressee can decline
        if (friendship.AddresseeId != currentUserId)
        {
            return Forbid();
        }

        _context.Friendships.Remove(friendship);
        await _context.SaveChangesAsync();

        return NoContent();
    }

    /// <summary>
    /// Get all accepted friends of current user
    /// </summary>
    /// <returns>List of accepted friendships</returns>
    [HttpGet]
    public async Task<ActionResult<List<FriendshipDto>>> GetFriends()
    {
        var currentUserId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var friendships = await _context.Friendships
            .Include(f => f.Requester)
                .ThenInclude(u => u.Profile)
            .Include(f => f.Addressee)
                .ThenInclude(u => u.Profile)
            .Where(f => (f.RequesterId == currentUserId || f.AddresseeId == currentUserId) &&
                       f.Status == FriendshipStatus.Accepted)
            .Select(f => new FriendshipDto
            {
                Id = f.Id,
                RequesterId = f.RequesterId,
                RequesterUsername = f.Requester.Username,
                RequesterDisplayName = f.Requester.Profile!.DisplayName,
                AddresseeId = f.AddresseeId,
                AddresseeUsername = f.Addressee.Username,
                AddresseeDisplayName = f.Addressee.Profile!.DisplayName,
                Status = f.Status,
                RequestedAt = f.RequestedAt,
                UpdatedAt = f.UpdatedAt
            })
            .ToListAsync();

        return Ok(friendships);
    }

    /// <summary>
    /// Remove a friendship
    /// </summary>
    /// <param name="friendId">User ID of the friend to remove</param>
    /// <returns>No content</returns>
    [HttpDelete("{friendId}")]
    public async Task<ActionResult> RemoveFriend(int friendId)
    {
        var currentUserId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var friendship = await _context.Friendships
            .FirstOrDefaultAsync(f =>
                ((f.RequesterId == currentUserId && f.AddresseeId == friendId) ||
                 (f.RequesterId == friendId && f.AddresseeId == currentUserId)) &&
                f.Status == FriendshipStatus.Accepted);

        if (friendship == null)
        {
            return NotFound(new { message = "Friendship not found" });
        }

        _context.Friendships.Remove(friendship);
        await _context.SaveChangesAsync();

        return NoContent();
    }
}
