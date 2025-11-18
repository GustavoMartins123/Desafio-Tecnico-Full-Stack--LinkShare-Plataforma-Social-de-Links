using System.Text;
using System.Text.Json;
using RabbitMQ.Client;

namespace LinkShare.API.Services;

public class MessageQueueService : IMessageQueueService, IDisposable
{
    private readonly IConnection _connection;
    private readonly IModel _channel;
    private readonly ILogger<MessageQueueService> _logger;
    private readonly string _queueName;

    public MessageQueueService(IConfiguration configuration, ILogger<MessageQueueService> logger)
    {
        _logger = logger;

        var factory = new ConnectionFactory
        {
            HostName = configuration["RabbitMQ:HostName"] ?? "localhost",
            Port = int.Parse(configuration["RabbitMQ:Port"] ?? "5672"),
            UserName = configuration["RabbitMQ:UserName"] ?? "guest",
            Password = configuration["RabbitMQ:Password"] ?? "guest"
        };

        _queueName = configuration["RabbitMQ:QueueName"] ?? "link-metadata-queue";

        try
        {
            _connection = factory.CreateConnection();
            _channel = _connection.CreateModel();

            // Declare queue (idempotent)
            _channel.QueueDeclare(
                queue: _queueName,
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: null);

            _logger.LogInformation("MessageQueueService connected to RabbitMQ at {HostName}:{Port}",
                factory.HostName, factory.Port);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to connect to RabbitMQ");
            throw;
        }
    }

    public void PublishLinkMetadataJob(int linkItemId, int collectionId, string url)
    {
        try
        {
            var job = new
            {
                LinkItemId = linkItemId,
                CollectionId = collectionId,
                Url = url
            };

            var message = JsonSerializer.Serialize(job);
            var body = Encoding.UTF8.GetBytes(message);

            var properties = _channel.CreateBasicProperties();
            properties.Persistent = true;

            _channel.BasicPublish(
                exchange: "",
                routingKey: _queueName,
                basicProperties: properties,
                body: body);

            _logger.LogInformation("Published link metadata job for LinkItemId: {LinkItemId}, URL: {Url}",
                linkItemId, url);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to publish message to RabbitMQ for LinkItemId: {LinkItemId}",
                linkItemId);
            throw;
        }
    }

    public void Dispose()
    {
        _channel?.Close();
        _channel?.Dispose();
        _connection?.Close();
        _connection?.Dispose();
    }
}
