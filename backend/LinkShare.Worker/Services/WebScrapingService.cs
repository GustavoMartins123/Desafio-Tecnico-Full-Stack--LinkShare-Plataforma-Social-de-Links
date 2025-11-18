using HtmlAgilityPack;

namespace LinkShare.Worker.Services;

public interface IWebScrapingService
{
    Task<LinkMetadata> ExtractMetadataAsync(string url);
}

public class LinkMetadata
{
    public string Title { get; set; } = "Untitled";
    public string Description { get; set; } = string.Empty;
    public string ImageUrl { get; set; } = string.Empty;
    public bool Success { get; set; }
    public string? ErrorMessage { get; set; }
}

public class WebScrapingService : IWebScrapingService
{
    private readonly ILogger<WebScrapingService> _logger;
    private readonly HttpClient _httpClient;

    public WebScrapingService(ILogger<WebScrapingService> logger, IHttpClientFactory httpClientFactory)
    {
        _logger = logger;
        _httpClient = httpClientFactory.CreateClient();
        _httpClient.Timeout = TimeSpan.FromSeconds(30);
    }

    public async Task<LinkMetadata> ExtractMetadataAsync(string url)
    {
        var metadata = new LinkMetadata();

        try
        {
            _logger.LogInformation("Starting metadata extraction for URL: {Url}", url);

            // Fetch the HTML content
            var response = await _httpClient.GetAsync(url);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning("HTTP request failed with status {StatusCode} for URL: {Url}",
                    response.StatusCode, url);
                metadata.ErrorMessage = $"HTTP {response.StatusCode}";
                return metadata;
            }

            var html = await response.Content.ReadAsStringAsync();

            // Parse HTML
            var htmlDoc = new HtmlDocument();
            htmlDoc.LoadHtml(html);

            // Extract title (priority: og:title > title tag > URL)
            metadata.Title = ExtractTitle(htmlDoc, url);

            // Extract description (priority: og:description > meta description > first paragraph)
            metadata.Description = ExtractDescription(htmlDoc);

            // Extract image (priority: og:image > twitter:image > first img tag)
            metadata.ImageUrl = ExtractImage(htmlDoc, url);

            metadata.Success = true;
            _logger.LogInformation("Successfully extracted metadata for URL: {Url} - Title: {Title}",
                url, metadata.Title);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "HTTP request failed for URL: {Url}", url);
            metadata.ErrorMessage = $"Request failed: {ex.Message}";
        }
        catch (TaskCanceledException ex)
        {
            _logger.LogError(ex, "Request timeout for URL: {Url}", url);
            metadata.ErrorMessage = "Request timeout";
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error extracting metadata for URL: {Url}", url);
            metadata.ErrorMessage = $"Error: {ex.Message}";
        }

        return metadata;
    }

    private string ExtractTitle(HtmlDocument htmlDoc, string url)
    {
        // Try Open Graph title
        var ogTitle = htmlDoc.DocumentNode.SelectSingleNode("//meta[@property='og:title']");
        if (ogTitle != null && !string.IsNullOrWhiteSpace(ogTitle.GetAttributeValue("content", "")))
        {
            return ogTitle.GetAttributeValue("content", "").Trim();
        }

        // Try Twitter title
        var twitterTitle = htmlDoc.DocumentNode.SelectSingleNode("//meta[@name='twitter:title']");
        if (twitterTitle != null && !string.IsNullOrWhiteSpace(twitterTitle.GetAttributeValue("content", "")))
        {
            return twitterTitle.GetAttributeValue("content", "").Trim();
        }

        // Try <title> tag
        var titleNode = htmlDoc.DocumentNode.SelectSingleNode("//title");
        if (titleNode != null && !string.IsNullOrWhiteSpace(titleNode.InnerText))
        {
            return System.Net.WebUtility.HtmlDecode(titleNode.InnerText.Trim());
        }

        // Fallback to URL host
        try
        {
            var uri = new Uri(url);
            return uri.Host;
        }
        catch
        {
            return "Untitled";
        }
    }

    private string ExtractDescription(HtmlDocument htmlDoc)
    {
        // Try Open Graph description
        var ogDescription = htmlDoc.DocumentNode.SelectSingleNode("//meta[@property='og:description']");
        if (ogDescription != null && !string.IsNullOrWhiteSpace(ogDescription.GetAttributeValue("content", "")))
        {
            return ogDescription.GetAttributeValue("content", "").Trim();
        }

        // Try Twitter description
        var twitterDescription = htmlDoc.DocumentNode.SelectSingleNode("//meta[@name='twitter:description']");
        if (twitterDescription != null && !string.IsNullOrWhiteSpace(twitterDescription.GetAttributeValue("content", "")))
        {
            return twitterDescription.GetAttributeValue("content", "").Trim();
        }

        // Try meta description
        var metaDescription = htmlDoc.DocumentNode.SelectSingleNode("//meta[@name='description']");
        if (metaDescription != null && !string.IsNullOrWhiteSpace(metaDescription.GetAttributeValue("content", "")))
        {
            return metaDescription.GetAttributeValue("content", "").Trim();
        }

        // Try first paragraph
        var firstParagraph = htmlDoc.DocumentNode.SelectSingleNode("//p");
        if (firstParagraph != null && !string.IsNullOrWhiteSpace(firstParagraph.InnerText))
        {
            var text = System.Net.WebUtility.HtmlDecode(firstParagraph.InnerText.Trim());
            return text.Length > 200 ? text.Substring(0, 200) + "..." : text;
        }

        return string.Empty;
    }

    private string ExtractImage(HtmlDocument htmlDoc, string url)
    {
        // Try Open Graph image
        var ogImage = htmlDoc.DocumentNode.SelectSingleNode("//meta[@property='og:image']");
        if (ogImage != null && !string.IsNullOrWhiteSpace(ogImage.GetAttributeValue("content", "")))
        {
            return MakeAbsoluteUrl(ogImage.GetAttributeValue("content", ""), url);
        }

        // Try Twitter image
        var twitterImage = htmlDoc.DocumentNode.SelectSingleNode("//meta[@name='twitter:image']");
        if (twitterImage != null && !string.IsNullOrWhiteSpace(twitterImage.GetAttributeValue("content", "")))
        {
            return MakeAbsoluteUrl(twitterImage.GetAttributeValue("content", ""), url);
        }

        // Try first img tag
        var firstImg = htmlDoc.DocumentNode.SelectSingleNode("//img[@src]");
        if (firstImg != null && !string.IsNullOrWhiteSpace(firstImg.GetAttributeValue("src", "")))
        {
            return MakeAbsoluteUrl(firstImg.GetAttributeValue("src", ""), url);
        }

        return string.Empty;
    }

    private string MakeAbsoluteUrl(string imageUrl, string baseUrl)
    {
        if (string.IsNullOrWhiteSpace(imageUrl))
            return string.Empty;

        // Already absolute
        if (Uri.IsWellFormedUriString(imageUrl, UriKind.Absolute))
            return imageUrl;

        // Make it absolute
        try
        {
            var baseUri = new Uri(baseUrl);
            var absoluteUri = new Uri(baseUri, imageUrl);
            return absoluteUri.ToString();
        }
        catch
        {
            return imageUrl;
        }
    }
}
