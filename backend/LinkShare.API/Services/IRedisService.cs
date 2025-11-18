namespace LinkShare.API.Services;

public interface IRedisService
{
    /// <summary>
    /// Add a token JTI to the blacklist with expiration time
    /// </summary>
    Task BlacklistTokenAsync(string jti, TimeSpan expiration);

    /// <summary>
    /// Check if a token JTI is blacklisted
    /// </summary>
    Task<bool> IsTokenBlacklistedAsync(string jti);
}
