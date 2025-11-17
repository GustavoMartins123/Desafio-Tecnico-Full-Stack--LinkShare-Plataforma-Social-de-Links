using System.Security.Claims;
using LinkShare.API.Data;
using LinkShare.API.DTOs.Collection;
using LinkShare.API.DTOs.LinkItem;
using LinkShare.API.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LinkShare.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CollectionsController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public CollectionsController(ApplicationDbContext context)
    {
        _context = context;
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

        var collection = await _context.Collections.FindAsync(collectionId);
        if (collection == null)
        {
            return NotFound(new { message = "Collection not found" });
        }

        // Only owner can add items
        if (collection.OwnerId != userId)
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

        return CreatedAtAction(nameof(GetCollectionById), new { collectionId }, new LinkItemDto
        {
            Id = linkItem.Id,
            Title = linkItem.Title,
            URL = linkItem.URL,
            Description = linkItem.Description,
            CollectionId = linkItem.CollectionId,
            CreatedAt = linkItem.CreatedAt
        });
    }

    /// <summary>
    /// Share a private collection with a friend
    /// </summary>
    /// <param name="collectionId">Collection ID</param>
    /// <param name="friendId">Friend user ID to share with</param>
    /// <returns>No content</returns>
    [Authorize]
    [HttpPost("{collectionId}/share/{friendId}")]
    public async Task<ActionResult> ShareCollection(int collectionId, int friendId)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var collection = await _context.Collections.FindAsync(collectionId);
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
            .AnyAsync(f => ((f.RequesterId == userId && f.AddresseeId == friendId) ||
                           (f.RequesterId == friendId && f.AddresseeId == userId)) &&
                          f.Status == FriendshipStatus.Accepted);

        if (!areFriends)
        {
            return BadRequest(new { message = "You can only share with friends" });
        }

        // Check if already shared
        var existingShare = await _context.CollectionShares
            .FirstOrDefaultAsync(cs => cs.CollectionId == collectionId && cs.UserId == friendId);

        if (existingShare != null)
        {
            return BadRequest(new { message = "Collection already shared with this user" });
        }

        var share = new CollectionShare
        {
            CollectionId = collectionId,
            UserId = friendId,
            SharedAt = DateTime.UtcNow
        };

        _context.CollectionShares.Add(share);
        await _context.SaveChangesAsync();

        return NoContent();
    }
}
