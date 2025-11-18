using System.Security.Claims;
using LinkShare.API.Data;
using LinkShare.API.DTOs.Collection;
using LinkShare.API.DTOs.LinkItem;
using LinkShare.API.Entities;
using LinkShare.API.Hubs;
using LinkShare.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace LinkShare.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CollectionsController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IHubContext<CollectionHub> _hubContext;
    private readonly IPushNotificationService _pushNotificationService;

    public CollectionsController(
        ApplicationDbContext context,
        IHubContext<CollectionHub> hubContext,
        IPushNotificationService pushNotificationService)
    {
        _context = context;
        _hubContext = hubContext;
        _pushNotificationService = pushNotificationService;
    }

    /// <summary>
    /// Create a new collection
    /// </summary>
    /// <param name="createDto">Collection data (Title, Description, IsPublic)</param>
    /// <returns>Created collection</returns>
    [Authorize]
    [HttpPost]
    public async Task<ActionResult<CollectionDto>> CreateCollection([FromBody] CreateCollectionDto createDto)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var collection = new Collection
        {
            Title = createDto.Title,
            Description = createDto.Description,
            IsPublic = createDto.IsPublic,
            OwnerId = userId,
            CreatedAt = DateTime.UtcNow
        };

        _context.Collections.Add(collection);
        await _context.SaveChangesAsync();

        var user = await _context.Users.FindAsync(userId);

        return CreatedAtAction(nameof(GetCollectionById), new { collectionId = collection.Id }, new CollectionDto
        {
            Id = collection.Id,
            Title = collection.Title,
            Description = collection.Description,
            OwnerId = collection.OwnerId,
            OwnerUsername = user!.Username,
            IsPublic = collection.IsPublic,
            CreatedAt = collection.CreatedAt,
            LinkItemsCount = 0
        });
    }

    /// <summary>
    /// Get all collections owned by the authenticated user
    /// </summary>
    /// <returns>List of user's collections</returns>
    [Authorize]
    [HttpGet("me")]
    public async Task<ActionResult<List<CollectionDto>>> GetMyCollections()
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var collections = await _context.Collections
            .Include(c => c.Owner)
            .Include(c => c.LinkItems)
            .Where(c => c.OwnerId == userId)
            .Select(c => new CollectionDto
            {
                Id = c.Id,
                Title = c.Title,
                Description = c.Description,
                OwnerId = c.OwnerId,
                OwnerUsername = c.Owner.Username,
                IsPublic = c.IsPublic,
                CreatedAt = c.CreatedAt,
                LinkItemsCount = c.LinkItems.Count
            })
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync();

        return Ok(collections);
    }

    /// <summary>
    /// Get public collections of a user by username
    /// </summary>
    /// <param name="username">Username to get collections from</param>
    /// <returns>List of public collections</returns>
    [HttpGet("user/{username}")]
    public async Task<ActionResult<List<CollectionDto>>> GetUserPublicCollections(string username)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Username == username);
        if (user == null)
        {
            return NotFound(new { message = "User not found" });
        }

        var collections = await _context.Collections
            .Include(c => c.Owner)
            .Include(c => c.LinkItems)
            .Where(c => c.OwnerId == user.Id && c.IsPublic)
            .Select(c => new CollectionDto
            {
                Id = c.Id,
                Title = c.Title,
                Description = c.Description,
                OwnerId = c.OwnerId,
                OwnerUsername = c.Owner.Username,
                IsPublic = c.IsPublic,
                CreatedAt = c.CreatedAt,
                LinkItemsCount = c.LinkItems.Count
            })
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync();

        return Ok(collections);
    }

    /// <summary>
    /// Get collection details by ID with permission check
    /// </summary>
    /// <param name="collectionId">Collection ID</param>
    /// <returns>Collection with all link items</returns>
    [Authorize]
    [HttpGet("{collectionId}")]
    public async Task<ActionResult<CollectionDetailDto>> GetCollectionById(int collectionId)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var collection = await _context.Collections
            .Include(c => c.Owner)
            .Include(c => c.LinkItems)
            .Include(c => c.Shares)
            .FirstOrDefaultAsync(c => c.Id == collectionId);

        if (collection == null)
        {
            return NotFound(new { message = "Collection not found" });
        }

        // Permission check: Must be owner, public, or explicitly shared
        var hasAccess = collection.OwnerId == userId ||
                       collection.IsPublic ||
                       collection.Shares.Any(s => s.UserId == userId);

        if (!hasAccess)
        {
            return Forbid();
        }

        return Ok(new CollectionDetailDto
        {
            Id = collection.Id,
            Title = collection.Title,
            Description = collection.Description,
            OwnerId = collection.OwnerId,
            OwnerUsername = collection.Owner.Username,
            IsPublic = collection.IsPublic,
            CreatedAt = collection.CreatedAt,
            LinkItems = collection.LinkItems.Select(li => new LinkItemDto
            {
                Id = li.Id,
                Title = li.Title,
                URL = li.URL,
                Description = li.Description,
                CollectionId = li.CollectionId,
                CreatedAt = li.CreatedAt
            }).OrderByDescending(li => li.CreatedAt).ToList()
        });
    }

    /// <summary>
    /// Add a new link item to a collection
    /// </summary>
    /// <param name="collectionId">Collection ID</param>
    /// <param name="createDto">Link item data (Title, URL, Description)</param>
    /// <returns>Created link item</returns>
    [Authorize]
    [HttpPost("{collectionId}/items")]
    public async Task<ActionResult<LinkItemDto>> AddLinkItem(int collectionId, [FromBody] CreateLinkItemDto createDto)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var collection = await _context.Collections
            .Include(c => c.Shares)
            .FirstOrDefaultAsync(c => c.Id == collectionId);

        if (collection == null)
        {
            return NotFound(new { message = "Collection not found" });
        }

        // Owner can add items, or users with edit permission
        var canEdit = collection.OwnerId == userId ||
                     collection.Shares.Any(s => s.UserId == userId && s.CanEdit);

        if (!canEdit)
        {
            return Forbid();
        }

        var linkItem = new LinkItem
        {
            Title = createDto.Title,
            URL = createDto.URL,
            Description = createDto.Description,
            CollectionId = collectionId,
            CreatedAt = DateTime.UtcNow
        };

        _context.LinkItems.Add(linkItem);
        await _context.SaveChangesAsync();

        var linkItemDto = new LinkItemDto
        {
            Id = linkItem.Id,
            Title = linkItem.Title,
            URL = linkItem.URL,
            Description = linkItem.Description,
            CollectionId = linkItem.CollectionId,
            CreatedAt = linkItem.CreatedAt
        };

        // Notify SignalR clients about the new link
        await _hubContext.Clients
            .Group($"collection_{collectionId}")
            .SendAsync("NewLinkAdded", linkItemDto);

        return CreatedAtAction(nameof(GetCollectionById), new { collectionId }, linkItemDto);
    }

    /// <summary>
    /// Share a collection with a friend
    /// </summary>
    /// <param name="collectionId">Collection ID</param>
    /// <param name="request">Share request with user ID and permissions</param>
    /// <returns>Created share</returns>
    [Authorize]
    [HttpPost("{collectionId}/share")]
    public async Task<ActionResult<CollectionShareDto>> ShareCollection(int collectionId, [FromBody] ShareCollectionRequest request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var collection = await _context.Collections
            .Include(c => c.Owner)
            .FirstOrDefaultAsync(c => c.Id == collectionId);

        if (collection == null)
        {
            return NotFound(new { message = "Collection not found" });
        }

        // Only owner can share
        if (collection.OwnerId != userId)
        {
            return Forbid();
        }

        // Check if they are friends
        var areFriends = await _context.Friendships
            .AnyAsync(f => ((f.RequesterId == userId && f.AddresseeId == request.SharedWithUserId) ||
                           (f.RequesterId == request.SharedWithUserId && f.AddresseeId == userId)) &&
                          f.Status == FriendshipStatus.Accepted);

        if (!areFriends)
        {
            return BadRequest(new { message = "You can only share with friends" });
        }

        // Check if already shared
        var existingShare = await _context.CollectionShares
            .FirstOrDefaultAsync(cs => cs.CollectionId == collectionId && cs.UserId == request.SharedWithUserId);

        if (existingShare != null)
        {
            return BadRequest(new { message = "Collection already shared with this user" });
        }

        var share = new CollectionShare
        {
            CollectionId = collectionId,
            UserId = request.SharedWithUserId,
            CanEdit = request.CanEdit,
            SharedAt = DateTime.UtcNow
        };

        _context.CollectionShares.Add(share);
        await _context.SaveChangesAsync();

        // Send push notification to the shared user
        var ownerName = collection.Owner.Profile?.DisplayName ?? collection.Owner.Username;
        await _pushNotificationService.SendToUserAsync(
            request.SharedWithUserId,
            "Collection Shared",
            $"{ownerName} shared \"{collection.Title}\" with you",
            new Dictionary<string, string>
            {
                { "type", "collection_shared" },
                { "collectionId", collectionId.ToString() },
                { "ownerId", userId.ToString() },
                { "canEdit", request.CanEdit.ToString() }
            }
        );

        // Load user info for response
        var sharedWithUser = await _context.Users
            .Include(u => u.Profile)
            .FirstOrDefaultAsync(u => u.Id == request.SharedWithUserId);

        return CreatedAtAction(nameof(GetCollectionById), new { collectionId }, new CollectionShareDto
        {
            Id = share.Id,
            CollectionId = collectionId,
            CollectionName = collection.Title,
            SharedWithUserId = request.SharedWithUserId,
            SharedWithUsername = sharedWithUser!.Username,
            SharedWithDisplayName = sharedWithUser.Profile!.DisplayName,
            SharedAt = share.SharedAt,
            CanEdit = share.CanEdit
        });
    }

    /// <summary>
    /// Get all shares for a specific collection (owner only)
    /// </summary>
    /// <param name="collectionId">Collection ID</param>
    /// <returns>List of shares</returns>
    [Authorize]
    [HttpGet("{collectionId}/shares")]
    public async Task<ActionResult<List<CollectionShareDto>>> GetCollectionShares(int collectionId)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var collection = await _context.Collections.FindAsync(collectionId);
        if (collection == null)
        {
            return NotFound(new { message = "Collection not found" });
        }

        // Only owner can view shares
        if (collection.OwnerId != userId)
        {
            return Forbid();
        }

        var shares = await _context.CollectionShares
            .Where(cs => cs.CollectionId == collectionId)
            .Include(cs => cs.User)
            .ThenInclude(u => u.Profile)
            .Include(cs => cs.Collection)
            .Select(cs => new CollectionShareDto
            {
                Id = cs.Id,
                CollectionId = cs.CollectionId,
                CollectionName = cs.Collection.Title,
                SharedWithUserId = cs.UserId,
                SharedWithUsername = cs.User.Username,
                SharedWithDisplayName = cs.User.Profile!.DisplayName,
                SharedAt = cs.SharedAt,
                CanEdit = cs.CanEdit
            })
            .OrderByDescending(cs => cs.SharedAt)
            .ToListAsync();

        return Ok(shares);
    }

    /// <summary>
    /// Get all collections shared with me
    /// </summary>
    /// <returns>List of shared collections</returns>
    [Authorize]
    [HttpGet("shared-with-me")]
    public async Task<ActionResult<List<SharedCollectionDto>>> GetSharedWithMe()
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var sharedCollections = await _context.CollectionShares
            .Where(cs => cs.UserId == userId)
            .Include(cs => cs.Collection)
            .ThenInclude(c => c.Owner)
            .ThenInclude(o => o.Profile)
            .Include(cs => cs.Collection.LinkItems)
            .Select(cs => new SharedCollectionDto
            {
                Id = cs.Collection.Id,
                Name = cs.Collection.Title,
                Description = cs.Collection.Description,
                IsPublic = cs.Collection.IsPublic,
                OwnerId = cs.Collection.OwnerId,
                OwnerUsername = cs.Collection.Owner.Username,
                OwnerDisplayName = cs.Collection.Owner.Profile!.DisplayName,
                SharedAt = cs.SharedAt,
                CanEdit = cs.CanEdit,
                LinkCount = cs.Collection.LinkItems.Count
            })
            .OrderByDescending(sc => sc.SharedAt)
            .ToListAsync();

        return Ok(sharedCollections);
    }

    /// <summary>
    /// Update share permissions (owner only)
    /// </summary>
    /// <param name="collectionId">Collection ID</param>
    /// <param name="shareId">Share ID</param>
    /// <param name="request">Updated permissions</param>
    /// <returns>Updated share</returns>
    [Authorize]
    [HttpPut("{collectionId}/share/{shareId}")]
    public async Task<ActionResult<CollectionShareDto>> UpdateSharePermissions(
        int collectionId,
        int shareId,
        [FromBody] ShareCollectionRequest request)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var collection = await _context.Collections.FindAsync(collectionId);
        if (collection == null)
        {
            return NotFound(new { message = "Collection not found" });
        }

        // Only owner can update permissions
        if (collection.OwnerId != userId)
        {
            return Forbid();
        }

        var share = await _context.CollectionShares
            .Include(cs => cs.User)
            .ThenInclude(u => u.Profile)
            .Include(cs => cs.Collection)
            .FirstOrDefaultAsync(cs => cs.Id == shareId && cs.CollectionId == collectionId);

        if (share == null)
        {
            return NotFound(new { message = "Share not found" });
        }

        share.CanEdit = request.CanEdit;
        await _context.SaveChangesAsync();

        return Ok(new CollectionShareDto
        {
            Id = share.Id,
            CollectionId = share.CollectionId,
            CollectionName = share.Collection.Title,
            SharedWithUserId = share.UserId,
            SharedWithUsername = share.User.Username,
            SharedWithDisplayName = share.User.Profile!.DisplayName,
            SharedAt = share.SharedAt,
            CanEdit = share.CanEdit
        });
    }

    /// <summary>
    /// Remove a share (owner only)
    /// </summary>
    /// <param name="collectionId">Collection ID</param>
    /// <param name="shareId">Share ID</param>
    /// <returns>No content</returns>
    [Authorize]
    [HttpDelete("{collectionId}/share/{shareId}")]
    public async Task<ActionResult> RemoveShare(int collectionId, int shareId)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var collection = await _context.Collections.FindAsync(collectionId);
        if (collection == null)
        {
            return NotFound(new { message = "Collection not found" });
        }

        // Only owner can remove shares
        if (collection.OwnerId != userId)
        {
            return Forbid();
        }

        var share = await _context.CollectionShares
            .FirstOrDefaultAsync(cs => cs.Id == shareId && cs.CollectionId == collectionId);

        if (share == null)
        {
            return NotFound(new { message = "Share not found" });
        }

        _context.CollectionShares.Remove(share);
        await _context.SaveChangesAsync();

        return NoContent();
    }
}
