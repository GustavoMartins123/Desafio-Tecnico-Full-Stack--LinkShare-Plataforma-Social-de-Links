using LinkShare.API.Data;
using LinkShare.API.DTOs.Auth;
using LinkShare.API.Entities;
using LinkShare.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.IdentityModel.Tokens.Jwt;
using BCrypt.Net;

namespace LinkShare.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly ITokenService _tokenService;
    private readonly IConfiguration _configuration;
    private readonly IRedisService _redisService;

    public AuthController(
        ApplicationDbContext context,
        ITokenService tokenService,
        IConfiguration configuration,
        IRedisService redisService)
    {
        _context = context;
        _tokenService = tokenService;
        _configuration = configuration;
        _redisService = redisService;
    }

    /// <summary>
    /// Register a new user
    /// </summary>
    /// <param name="request">Registration data (Email, Username, Password)</param>
    /// <returns>Authentication token and user data</returns>
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponseDto>> Register([FromBody] RegisterRequestDto request)
    {
        // Check if email already exists
        if (await _context.Users.AnyAsync(u => u.Email == request.Email))
        {
            return BadRequest(new { message = "Email already exists" });
        }

        // Check if username already exists
        if (await _context.Users.AnyAsync(u => u.Username == request.Username))
        {
            return BadRequest(new { message = "Username already exists" });
        }

        // Hash password
        var passwordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);

        // Create user
        var user = new User
        {
            Email = request.Email,
            Username = request.Username,
            PasswordHash = passwordHash,
            CreatedAt = DateTime.UtcNow
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        // Create empty profile linked to user
        var profile = new Profile
        {
            UserId = user.Id,
            DisplayName = request.Username, // Initialize with username
            Bio = string.Empty
        };

        _context.Profiles.Add(profile);
        await _context.SaveChangesAsync();

        // Generate tokens
        var accessToken = _tokenService.GenerateToken(user);
        var refreshToken = _tokenService.GenerateRefreshToken();

        // Get refresh token expiration from configuration
        var jwtSettings = _configuration.GetSection("JwtSettings");
        var refreshTokenExpirationDays = int.Parse(jwtSettings["RefreshTokenExpirationDays"] ?? "7");

        // Save refresh token to database
        var userToken = new UserToken
        {
            UserId = user.Id,
            RefreshToken = refreshToken,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(refreshTokenExpirationDays),
            IsRevoked = false
        };

        _context.UserTokens.Add(userToken);
        await _context.SaveChangesAsync();

        return Ok(new AuthResponseDto
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            UserId = user.Id,
            Username = user.Username,
            Email = user.Email
        });
    }

    /// <summary>
    /// Login with existing credentials
    /// </summary>
    /// <param name="request">Login data (Email, Password)</param>
    /// <returns>Authentication token and user data</returns>
    [HttpPost("login")]
    public async Task<ActionResult<AuthResponseDto>> Login([FromBody] LoginRequestDto request)
    {
        // Find user by email
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Email == request.Email);

        if (user == null)
        {
            return Unauthorized(new { message = "Invalid credentials" });
        }

        // Verify password
        if (!BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            return Unauthorized(new { message = "Invalid credentials" });
        }

        // Generate tokens
        var accessToken = _tokenService.GenerateToken(user);
        var refreshToken = _tokenService.GenerateRefreshToken();

        // Get refresh token expiration from configuration
        var jwtSettings = _configuration.GetSection("JwtSettings");
        var refreshTokenExpirationDays = int.Parse(jwtSettings["RefreshTokenExpirationDays"] ?? "7");

        // Save refresh token to database
        var userToken = new UserToken
        {
            UserId = user.Id,
            RefreshToken = refreshToken,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(refreshTokenExpirationDays),
            IsRevoked = false
        };

        _context.UserTokens.Add(userToken);
        await _context.SaveChangesAsync();

        return Ok(new AuthResponseDto
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            UserId = user.Id,
            Username = user.Username,
            Email = user.Email
        });
    }

    /// <summary>
    /// Refresh access token using refresh token
    /// </summary>
    /// <param name="request">Refresh token data</param>
    /// <returns>New access token and refresh token</returns>
    [HttpPost("refresh")]
    public async Task<ActionResult<AuthResponseDto>> Refresh([FromBody] RefreshTokenRequestDto request)
    {
        // Find the refresh token in database
        var userToken = await _context.UserTokens
            .Include(ut => ut.User)
            .FirstOrDefaultAsync(ut => ut.RefreshToken == request.RefreshToken);

        if (userToken == null)
        {
            return Unauthorized(new { message = "Invalid refresh token" });
        }

        // Check if token is expired
        if (userToken.ExpiresAt < DateTime.UtcNow)
        {
            return Unauthorized(new { message = "Refresh token expired" });
        }

        // Check if token is revoked
        if (userToken.IsRevoked)
        {
            return Unauthorized(new { message = "Refresh token revoked" });
        }

        // Revoke old refresh token
        userToken.IsRevoked = true;
        userToken.RevokedAt = DateTime.UtcNow;

        // Generate new tokens
        var accessToken = _tokenService.GenerateToken(userToken.User);
        var newRefreshToken = _tokenService.GenerateRefreshToken();

        // Get refresh token expiration from configuration
        var jwtSettings = _configuration.GetSection("JwtSettings");
        var refreshTokenExpirationDays = int.Parse(jwtSettings["RefreshTokenExpirationDays"] ?? "7");

        // Save new refresh token to database
        var newUserToken = new UserToken
        {
            UserId = userToken.UserId,
            RefreshToken = newRefreshToken,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(refreshTokenExpirationDays),
            IsRevoked = false
        };

        _context.UserTokens.Add(newUserToken);
        await _context.SaveChangesAsync();

        return Ok(new AuthResponseDto
        {
            AccessToken = accessToken,
            RefreshToken = newRefreshToken,
            UserId = userToken.User.Id,
            Username = userToken.User.Username,
            Email = userToken.User.Email
        });
    }

    /// <summary>
    /// Logout and blacklist the current access token
    /// </summary>
    /// <returns>Success message</returns>
    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout()
    {
        // Get the Authorization header
        var authHeader = Request.Headers["Authorization"].ToString();
        if (string.IsNullOrEmpty(authHeader) || !authHeader.StartsWith("Bearer "))
        {
            return BadRequest(new { message = "Invalid token" });
        }

        var token = authHeader.Substring("Bearer ".Length).Trim();

        // Parse the token to extract JTI
        var handler = new JwtSecurityTokenHandler();
        var jwtToken = handler.ReadJwtToken(token);
        var jti = jwtToken.Claims.FirstOrDefault(c => c.Type == JwtRegisteredClaimNames.Jti)?.Value;

        if (string.IsNullOrEmpty(jti))
        {
            return BadRequest(new { message = "Invalid token: no JTI found" });
        }

        // Get token expiration to set Redis TTL
        var exp = jwtToken.ValidTo;
        var ttl = exp - DateTime.UtcNow;

        // Add JTI to blacklist with expiration
        if (ttl.TotalSeconds > 0)
        {
            await _redisService.BlacklistTokenAsync(jti, ttl);
        }

        // Get user ID from claims
        var userIdClaim = User.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;
        if (!string.IsNullOrEmpty(userIdClaim) && int.TryParse(userIdClaim, out var userId))
        {
            // Revoke all refresh tokens for this user
            var userTokens = await _context.UserTokens
                .Where(ut => ut.UserId == userId && !ut.IsRevoked)
                .ToListAsync();

            foreach (var userToken in userTokens)
            {
                userToken.IsRevoked = true;
                userToken.RevokedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync();
        }

        return Ok(new { message = "Logged out successfully" });
    }
}
