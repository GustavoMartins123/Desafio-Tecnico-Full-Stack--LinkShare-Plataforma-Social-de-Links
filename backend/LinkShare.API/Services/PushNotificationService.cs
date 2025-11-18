using FirebaseAdmin.Messaging;
using LinkShare.API.Data;
using Microsoft.EntityFrameworkCore;

namespace LinkShare.API.Services;

public class PushNotificationService : IPushNotificationService
{
    private readonly ApplicationDbContext _context;
    private readonly ILogger<PushNotificationService> _logger;

    public PushNotificationService(ApplicationDbContext context, ILogger<PushNotificationService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<bool> SendToUserAsync(int userId, string title, string body, Dictionary<string, string>? data = null)
    {
        return await SendToUsersAsync(new List<int> { userId }, title, body, data);
    }

    public async Task<bool> SendToUsersAsync(List<int> userIds, string title, string body, Dictionary<string, string>? data = null)
    {
        try
        {
            // Get all active FCM tokens for these users
            var tokens = await _context.UserDevices
                .Where(d => userIds.Contains(d.UserId) && d.IsActive)
                .Select(d => d.FcmToken)
                .Distinct()
                .ToListAsync();

            if (tokens.Count == 0)
            {
                _logger.LogWarning("No FCM tokens found for users: {UserIds}", string.Join(", ", userIds));
                return false;
            }

            return await SendToTokensAsync(tokens, title, body, data);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting FCM tokens for users: {UserIds}", string.Join(", ", userIds));
            return false;
        }
    }

    public async Task<bool> SendToTokensAsync(List<string> tokens, string title, string body, Dictionary<string, string>? data = null)
    {
        if (tokens.Count == 0)
        {
            _logger.LogWarning("No tokens provided for push notification");
            return false;
        }

        try
        {
            // Create the notification message
            var message = new MulticastMessage
            {
                Notification = new Notification
                {
                    Title = title,
                    Body = body
                },
                Data = data ?? new Dictionary<string, string>(),
                Tokens = tokens
            };

            // Send the notification via Firebase
            var response = await FirebaseMessaging.DefaultInstance.SendEachForMulticastAsync(message);

            _logger.LogInformation(
                "Push notification sent. Success: {SuccessCount}, Failure: {FailureCount}",
                response.SuccessCount,
                response.FailureCount
            );

            // Log any failures
            if (response.FailureCount > 0)
            {
                for (int i = 0; i < response.Responses.Count; i++)
                {
                    if (!response.Responses[i].IsSuccess)
                    {
                        var error = response.Responses[i].Exception;
                        _logger.LogWarning(
                            "Failed to send notification to token {Token}: {Error}",
                            tokens[i],
                            error?.Message ?? "Unknown error"
                        );

                        // Remove invalid tokens from database
                        await RemoveInvalidTokenAsync(tokens[i]);
                    }
                }
            }

            return response.SuccessCount > 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending push notification");
            return false;
        }
    }

    private async Task RemoveInvalidTokenAsync(string token)
    {
        try
        {
            var device = await _context.UserDevices
                .FirstOrDefaultAsync(d => d.FcmToken == token);

            if (device != null)
            {
                device.IsActive = false;
                await _context.SaveChangesAsync();
                _logger.LogInformation("Deactivated invalid FCM token: {Token}", token);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing invalid token: {Token}", token);
        }
    }
}
