using StackExchange.Redis;

namespace LinkShare.API.Services;

public class RedisService : IRedisService
{
    private readonly IConnectionMultiplexer _redis;
    private readonly IDatabase _database;
    private const string BLACKLIST_PREFIX = "blacklist:";

    public RedisService(IConnectionMultiplexer redis)
    {
        _redis = redis;
        _database = _redis.GetDatabase();
    }

    public async Task BlacklistTokenAsync(string jti, TimeSpan expiration)
    {
        var key = $"{BLACKLIST_PREFIX}{jti}";
        await _database.StringSetAsync(key, "revoked", expiration);
    }

    public async Task<bool> IsTokenBlacklistedAsync(string jti)
    {
        var key = $"{BLACKLIST_PREFIX}{jti}";
        return await _database.KeyExistsAsync(key);
    }
}
