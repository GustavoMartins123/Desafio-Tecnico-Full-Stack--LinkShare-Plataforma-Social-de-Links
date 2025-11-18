using System.Security.Claims;
using LinkShare.API.Data;
using LinkShare.API.DTOs.Feed;
using LinkShare.API.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LinkShare.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class FeedController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public FeedController(ApplicationDbContext context)
    {
        _context = context;
    }

    /// <summary>
    /// Get activity feed from friends
    /// </summary>
    /// <param name="limit">Maximum number of activities to return (default: 50, max: 100)</param>
    /// <returns>List of recent activities from friends</returns>
    [Authorize]
    [HttpGet("activities")]
    public async Task<ActionResult<List<ActivityDto>>> GetFeedActivities([FromQuery] int limit = 50)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // Limit cap
        if (limit > 100) limit = 100;
        if (limit < 1) limit = 50;

        // Get friend IDs (both requester and addressee)
        var friendIds = await _context.Friendships
            .Where(f => (f.RequesterId == userId || f.AddresseeId == userId) &&
                       f.Status == FriendshipStatus.Accepted)
            .Select(f => f.RequesterId == userId ? f.AddresseeId : f.RequesterId)
            .ToListAsync();

        if (friendIds.Count == 0)
        {
            return Ok(new List<ActivityDto>());
        }

        var activities = new List<ActivityDto>();

        // Get recent collections from friends (public only or shared with me)
        var recentCollections = await _context.Collections
            .Where(c => friendIds.Contains(c.OwnerId) &&
                       (c.IsPublic || c.Shares.Any(s => s.UserId == userId)))
            .Include(c => c.Owner)
            .ThenInclude(o => o.Profile)
            .OrderByDescending(c => c.CreatedAt)
            .Take(limit)
            .ToListAsync();

        foreach (var collection in recentCollections)
        {
            activities.Add(new ActivityDto
            {
                UserId = collection.OwnerId,
                Username = collection.Owner.Username,
                UserDisplayName = collection.Owner.Profile!.DisplayName,
                UserProfilePictureUrl = collection.Owner.Profile.ProfilePictureUrl,
                ActivityType = ActivityType.CollectionCreated,
                Timestamp = collection.CreatedAt,
                CollectionId = collection.Id,
                CollectionTitle = collection.Title,
                CollectionIsPublic = collection.IsPublic
            });
        }

        // Get recent links from friends' public collections or collections shared with me
        var recentLinks = await _context.LinkItems
            .Where(li => friendIds.Contains(li.Collection.OwnerId) &&
                        (li.Collection.IsPublic || li.Collection.Shares.Any(s => s.UserId == userId)))
            .Include(li => li.Collection)
            .ThenInclude(c => c.Owner)
            .ThenInclude(o => o.Profile)
            .OrderByDescending(li => li.CreatedAt)
            .Take(limit)
            .ToListAsync();

        foreach (var link in recentLinks)
        {
            activities.Add(new ActivityDto
            {
                UserId = link.Collection.OwnerId,
                Username = link.Collection.Owner.Username,
                UserDisplayName = link.Collection.Owner.Profile!.DisplayName,
                UserProfilePictureUrl = link.Collection.Owner.Profile.ProfilePictureUrl,
                ActivityType = ActivityType.LinkAdded,
                Timestamp = link.CreatedAt,
                CollectionId = link.CollectionId,
                CollectionTitle = link.Collection.Title,
                CollectionIsPublic = link.Collection.IsPublic,
                LinkItemId = link.Id,
                LinkItemTitle = link.Title,
                LinkItemUrl = link.URL,
                LinkItemDescription = link.Description
            });
        }

        // Get recent shares (collections shared with me by friends)
        var recentShares = await _context.CollectionShares
            .Where(cs => cs.UserId == userId && friendIds.Contains(cs.Collection.OwnerId))
            .Include(cs => cs.Collection)
            .ThenInclude(c => c.Owner)
            .ThenInclude(o => o.Profile)
            .OrderByDescending(cs => cs.SharedAt)
            .Take(limit / 2) // Less shares to avoid overwhelming the feed
            .ToListAsync();

        foreach (var share in recentShares)
        {
            activities.Add(new ActivityDto
            {
                UserId = share.Collection.OwnerId,
                Username = share.Collection.Owner.Username,
                UserDisplayName = share.Collection.Owner.Profile!.DisplayName,
                UserProfilePictureUrl = share.Collection.Owner.Profile.ProfilePictureUrl,
                ActivityType = ActivityType.CollectionShared,
                Timestamp = share.SharedAt,
                CollectionId = share.CollectionId,
                CollectionTitle = share.Collection.Title,
                CollectionIsPublic = share.Collection.IsPublic
            });
        }

        // Sort all activities by timestamp and take limit
        var sortedActivities = activities
            .OrderByDescending(a => a.Timestamp)
            .Take(limit)
            .ToList();

        return Ok(sortedActivities);
    }
}
