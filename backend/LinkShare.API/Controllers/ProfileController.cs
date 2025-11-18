using System.Security.Claims;
using LinkShare.API.Data;
using LinkShare.API.DTOs.Device;
using LinkShare.API.DTOs.Profile;
using LinkShare.API.Entities;
using LinkShare.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace LinkShare.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ProfilesController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IFileUploadService _fileUploadService;

    public ProfilesController(ApplicationDbContext context, IFileUploadService fileUploadService)
    {
        _context = context;
        _fileUploadService = fileUploadService;
    }

    /// <summary>
    /// Get public profile by username
    /// </summary>
    /// <param name="username">Username to search for</param>
    /// <returns>Public profile data</returns>
    [HttpGet("{username}")]
    public async Task<ActionResult<ProfileDto>> GetProfileByUsername(string username)
    {
        var user = await _context.Users
            .Include(u => u.Profile)
            .FirstOrDefaultAsync(u => u.Username == username);

        if (user == null || user.Profile == null)
        {
            return NotFound(new { message = "Profile not found" });
        }

        return Ok(new ProfileDto
        {
            Id = user.Profile.Id,
            UserId = user.Id,
            Username = user.Username,
            DisplayName = user.Profile.DisplayName,
            Bio = user.Profile.Bio,
            ProfilePictureUrl = user.Profile.ProfilePictureUrl
        });
    }

    /// <summary>
    /// Get current authenticated user's profile
    /// </summary>
    /// <returns>Current user's profile data</returns>
    [Authorize]
    [HttpGet("me")]
    public async Task<ActionResult<ProfileDto>> GetMyProfile()
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var user = await _context.Users
            .Include(u => u.Profile)
            .FirstOrDefaultAsync(u => u.Id == userId);

        if (user == null || user.Profile == null)
        {
            return NotFound(new { message = "Profile not found" });
        }

        return Ok(new ProfileDto
        {
            Id = user.Profile.Id,
            UserId = user.Id,
            Username = user.Username,
            DisplayName = user.Profile.DisplayName,
            Bio = user.Profile.Bio,
            ProfilePictureUrl = user.Profile.ProfilePictureUrl
        });
    }

    /// <summary>
    /// Update current user's profile
    /// </summary>
    /// <param name="updateDto">Updated profile data (DisplayName, Bio)</param>
    /// <returns>Updated profile data</returns>
    [Authorize]
    [HttpPut("me")]
    public async Task<ActionResult<ProfileDto>> UpdateMyProfile([FromBody] UpdateProfileDto updateDto)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var user = await _context.Users
            .Include(u => u.Profile)
            .FirstOrDefaultAsync(u => u.Id == userId);

        if (user == null || user.Profile == null)
        {
            return NotFound(new { message = "Profile not found" });
        }

        // Update profile
        user.Profile.DisplayName = updateDto.DisplayName;
        user.Profile.Bio = updateDto.Bio;

        await _context.SaveChangesAsync();

        return Ok(new ProfileDto
        {
            Id = user.Profile.Id,
            UserId = user.Id,
            Username = user.Username,
            DisplayName = user.Profile.DisplayName,
            Bio = user.Profile.Bio,
            ProfilePictureUrl = user.Profile.ProfilePictureUrl
        });
    }

    /// <summary>
    /// Upload profile picture for current user
    /// </summary>
    /// <param name="file">Image file (jpg, png, gif, webp - max 5MB)</param>
    /// <returns>Updated profile with new picture URL</returns>
    [Authorize]
    [HttpPost("me/picture")]
    public async Task<ActionResult<ProfileDto>> UploadProfilePicture([FromForm] IFormFile file)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var user = await _context.Users
            .Include(u => u.Profile)
            .FirstOrDefaultAsync(u => u.Id == userId);

        if (user == null || user.Profile == null)
        {
            return NotFound(new { message = "Profile not found" });
        }

        try
        {
            // Delete old profile picture if exists
            if (!string.IsNullOrWhiteSpace(user.Profile.ProfilePictureUrl))
            {
                await _fileUploadService.DeleteFileAsync(user.Profile.ProfilePictureUrl);
            }

            // Save new profile picture
            var fileUrl = await _fileUploadService.SaveProfilePictureAsync(file);

            if (fileUrl == null)
            {
                return BadRequest(new { message = "Failed to upload file" });
            }

            // Update profile with new picture URL
            user.Profile.ProfilePictureUrl = fileUrl;
            await _context.SaveChangesAsync();

            return Ok(new ProfileDto
            {
                Id = user.Profile.Id,
                UserId = user.Id,
                Username = user.Username,
                DisplayName = user.Profile.DisplayName,
                Bio = user.Profile.Bio,
                ProfilePictureUrl = user.Profile.ProfilePictureUrl
            });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { message = "An error occurred while uploading the file", error = ex.Message });
        }
    }

    /// <summary>
    /// Delete profile picture for current user
    /// </summary>
    /// <returns>Updated profile without picture</returns>
    [Authorize]
    [HttpDelete("me/picture")]
    public async Task<ActionResult<ProfileDto>> DeleteProfilePicture()
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var user = await _context.Users
            .Include(u => u.Profile)
            .FirstOrDefaultAsync(u => u.Id == userId);

        if (user == null || user.Profile == null)
        {
            return NotFound(new { message = "Profile not found" });
        }

        // Delete profile picture file
        if (!string.IsNullOrWhiteSpace(user.Profile.ProfilePictureUrl))
        {
            await _fileUploadService.DeleteFileAsync(user.Profile.ProfilePictureUrl);
        }

        // Remove URL from profile
        user.Profile.ProfilePictureUrl = null;
        await _context.SaveChangesAsync();

        return Ok(new ProfileDto
        {
            Id = user.Profile.Id,
            UserId = user.Id,
            Username = user.Username,
            DisplayName = user.Profile.DisplayName,
            Bio = user.Profile.Bio,
            ProfilePictureUrl = user.Profile.ProfilePictureUrl
        });
    }

    /// <summary>
    /// Register device for push notifications
    /// </summary>
    /// <param name="deviceDto">Device information with FCM token</param>
    /// <returns>Success message</returns>
    [Authorize]
    [HttpPost("me/device")]
    public async Task<ActionResult> RegisterDevice([FromBody] RegisterDeviceDto deviceDto)
    {
        var userId = int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        // Check if device with this token already exists
        var existingDevice = await _context.UserDevices
            .FirstOrDefaultAsync(d => d.FcmToken == deviceDto.FcmToken);

        if (existingDevice != null)
        {
            // Update existing device
            existingDevice.UserId = userId; // In case user changed
            existingDevice.DeviceName = deviceDto.DeviceName;
            existingDevice.Platform = deviceDto.Platform;
            existingDevice.LastUsedAt = DateTime.UtcNow;
            existingDevice.IsActive = true;
        }
        else
        {
            // Create new device
            var device = new UserDevice
            {
                UserId = userId,
                FcmToken = deviceDto.FcmToken,
                DeviceName = deviceDto.DeviceName,
                Platform = deviceDto.Platform,
                CreatedAt = DateTime.UtcNow,
                LastUsedAt = DateTime.UtcNow,
                IsActive = true
            };

            _context.UserDevices.Add(device);
        }

        await _context.SaveChangesAsync();

        return Ok(new { message = "Device registered successfully" });
    }

    /// <summary>
    /// Unregister device for push notifications
    /// </summary>
    /// <param name="fcmToken">FCM token to unregister</param>
    /// <returns>Success message</returns>
    [Authorize]
    [HttpDelete("me/device")]
    public async Task<ActionResult> UnregisterDevice([FromQuery] string fcmToken)
    {
        var device = await _context.UserDevices
            .FirstOrDefaultAsync(d => d.FcmToken == fcmToken);

        if (device != null)
        {
            device.IsActive = false;
            await _context.SaveChangesAsync();
        }

        return Ok(new { message = "Device unregistered successfully" });
    }

    /// <summary>
    /// Search users by username or display name
    /// </summary>
    /// <param name="query">Search query</param>
    /// <returns>List of matching profiles</returns>
    [HttpGet("search")]
    public async Task<ActionResult<List<ProfileDto>>> SearchProfiles([FromQuery] string query)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            return BadRequest(new { message = "Query parameter is required" });
        }

        var profiles = await _context.Users
            .Include(u => u.Profile)
            .Where(u => u.Username.Contains(query) ||
                       (u.Profile != null && u.Profile.DisplayName.Contains(query)))
            .Select(u => new ProfileDto
            {
                Id = u.Profile!.Id,
                UserId = u.Id,
                Username = u.Username,
                DisplayName = u.Profile.DisplayName,
                Bio = u.Profile.Bio,
                ProfilePictureUrl = u.Profile.ProfilePictureUrl
            })
            .Take(20) // Limit results
            .ToListAsync();

        return Ok(profiles);
    }
}
