using System.IdentityModel.Tokens.Jwt;
using LinkShare.API.Services;

namespace LinkShare.API.Middleware;

public class JwtBlacklistMiddleware
{
    private readonly RequestDelegate _next;

    public JwtBlacklistMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context, IRedisService redisService)
    {
        // Check if the user is authenticated
        if (context.User.Identity?.IsAuthenticated == true)
        {
            // Get JTI from claims
            var jti = context.User.FindFirst(JwtRegisteredClaimNames.Jti)?.Value;

            if (!string.IsNullOrEmpty(jti))
            {
                // Check if token is blacklisted
                var isBlacklisted = await redisService.IsTokenBlacklistedAsync(jti);

                if (isBlacklisted)
                {
                    context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                    context.Response.ContentType = "application/json";
                    await context.Response.WriteAsJsonAsync(new { message = "Token has been revoked" });
                    return;
                }
            }
        }

        await _next(context);
    }
}

// Extension method to register the middleware
public static class JwtBlacklistMiddlewareExtensions
{
    public static IApplicationBuilder UseJwtBlacklist(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<JwtBlacklistMiddleware>();
    }
}
