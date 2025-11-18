using System.Text;
using System.Text.Json;
using LinkShare.API.Data;
using LinkShare.Worker.Services;
using Microsoft.EntityFrameworkCore;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace LinkShare.Worker;

public class Worker : BackgroundService
{
    private readonly ILogger<Worker> _logger;
    private readonly IConfiguration _configuration;
    private readonly IServiceProvider _serviceProvider;
    private IConnection? _connection;
    private IModel? _channel;

    public Worker(
        ILogger<Worker> logger,
        IConfiguration configuration,
        IServiceProvider serviceProvider)
    {
        _logger = logger;
        _configuration = configuration;
        _serviceProvider = serviceProvider;
    }

    public override Task StartAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("LinkShare Worker starting at: {time}", DateTimeOffset.Now);
        InitializeRabbitMQ();
        return base.StartAsync(cancellationToken);
    }

    private void InitializeRabbitMQ()
    {
        var factory = new ConnectionFactory
        {
            HostName = _configuration["RabbitMQ:HostName"] ?? "localhost",
            Port = int.Parse(_configuration["RabbitMQ:Port"] ?? "5672"),
            UserName = _configuration["RabbitMQ:UserName"] ?? "guest",
            Password = _configuration["RabbitMQ:Password"] ?? "guest",
            DispatchConsumersAsync = true
        };

        try
        {
            _connection = factory.CreateConnection();
            _channel = _connection.CreateModel();

            var queueName = _configuration["RabbitMQ:QueueName"] ?? "link-metadata-queue";

            // Declare queue (idempotent)
            _channel.QueueDeclare(
                queue: queueName,
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: null);

            // Set QoS to process one message at a time
            _channel.BasicQos(prefetchSize: 0, prefetchCount: 1, global: false);

            _logger.LogInformation("Successfully connected to RabbitMQ at {HostName}:{Port}",
                factory.HostName, factory.Port);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to connect to RabbitMQ");
            throw;
        }
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (_channel == null)
        {
            _logger.LogError("RabbitMQ channel is not initialized");
            return;
        }

        var queueName = _configuration["RabbitMQ:QueueName"] ?? "link-metadata-queue";

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.Received += async (model, ea) =>
        {
            try
            {
                var body = ea.Body.ToArray();
                var message = Encoding.UTF8.GetString(body);

                _logger.LogInformation("Received message: {Message}", message);

                // Deserialize the message
                var linkJob = JsonSerializer.Deserialize<LinkMetadataJob>(message);

                if (linkJob == null)
                {
                    _logger.LogWarning("Failed to deserialize message: {Message}", message);
                    _channel.BasicAck(deliveryTag: ea.DeliveryTag, multiple: false);
                    return;
                }

                // Process the link
                await ProcessLinkMetadataAsync(linkJob, stoppingToken);

                // Acknowledge the message
                _channel.BasicAck(deliveryTag: ea.DeliveryTag, multiple: false);

                _logger.LogInformation("Message processed successfully for LinkItemId: {LinkItemId}",
                    linkJob.LinkItemId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing message");

                // Reject and requeue the message (will retry)
                _channel.BasicNack(deliveryTag: ea.DeliveryTag, multiple: false, requeue: true);
            }
        };

        _channel.BasicConsume(queue: queueName, autoAck: false, consumer: consumer);

        _logger.LogInformation("Worker is now listening for messages on queue: {QueueName}", queueName);

        // Keep the worker running
        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(1000, stoppingToken);
        }
    }

    private async Task ProcessLinkMetadataAsync(LinkMetadataJob job, CancellationToken cancellationToken)
    {
        using var scope = _serviceProvider.CreateScope();

        var scrapingService = scope.ServiceProvider.GetRequiredService<IWebScrapingService>();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        // Extract metadata from the URL
        _logger.LogInformation("Extracting metadata for URL: {Url}", job.Url);
        var metadata = await scrapingService.ExtractMetadataAsync(job.Url);

        // Update the LinkItem in the database
        var linkItem = await dbContext.LinkItems.FindAsync(job.LinkItemId);

        if (linkItem == null)
        {
            _logger.LogWarning("LinkItem not found with ID: {LinkItemId}", job.LinkItemId);
            return;
        }

        // Update with extracted metadata
        linkItem.Title = metadata.Title;
        linkItem.Description = metadata.Description;

        // Store image URL if available (you might want to add this field to LinkItem)
        // linkItem.ImageUrl = metadata.ImageUrl;

        await dbContext.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Updated LinkItem {LinkItemId} with metadata - Title: {Title}",
            job.LinkItemId, metadata.Title);

        // Notify via SignalR (optional - will be implemented later)
        await NotifyClientsAsync(job.CollectionId, linkItem, cancellationToken);
    }

    private async Task NotifyClientsAsync(int collectionId, LinkShare.API.Entities.LinkItem linkItem, CancellationToken cancellationToken)
    {
        try
        {
            _logger.LogInformation("Notifying clients about updated link in collection {CollectionId}", collectionId);

            // In a production environment, you would use SignalR Client to connect to the Hub
            // and send the notification. For simplicity, we're noting that the frontend
            // can refresh when they see the "Processando..." status, or implement polling.

            // Alternative: Use SignalR .NET Client
            // var hubConnection = new HubConnectionBuilder()
            //     .WithUrl(signalRHubUrl)
            //     .Build();
            // await hubConnection.StartAsync();
            // await hubConnection.SendAsync("LinkUpdated", linkItemDto);
            // await hubConnection.StopAsync();

            // For this implementation, the client will see the update on next refresh
            // or when they navigate back to the collection

            _logger.LogInformation("Link metadata updated successfully: {Title}", linkItem.Title);
            await Task.CompletedTask;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to notify clients via SignalR");
        }
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("LinkShare Worker stopping at: {time}", DateTimeOffset.Now);

        _channel?.Close();
        _connection?.Close();

        await base.StopAsync(cancellationToken);
    }

    public override void Dispose()
    {
        _channel?.Dispose();
        _connection?.Dispose();
        base.Dispose();
    }
}

public class LinkMetadataJob
{
    public int LinkItemId { get; set; }
    public int CollectionId { get; set; }
    public string Url { get; set; } = string.Empty;
}
