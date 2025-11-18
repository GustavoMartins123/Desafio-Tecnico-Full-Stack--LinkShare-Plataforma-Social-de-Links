namespace LinkShare.API.Services;

public interface IPushNotificationService
{
    /// <summary>
    /// Send push notification to a single user by their user ID
    /// </summary>
    Task<bool> SendToUserAsync(int userId, string title, string body, Dictionary<string, string>? data = null);

    /// <summary>
    /// Send push notification to multiple users by their user IDs
    /// </summary>
    Task<bool> SendToUsersAsync(List<int> userIds, string title, string body, Dictionary<string, string>? data = null);

    /// <summary>
    /// Send push notification to specific FCM tokens
    /// </summary>
    Task<bool> SendToTokensAsync(List<string> tokens, string title, string body, Dictionary<string, string>? data = null);
}
