namespace LinkShare.API.Services;

public interface IMessageQueueService
{
    void PublishLinkMetadataJob(int linkItemId, int collectionId, string url);
}
