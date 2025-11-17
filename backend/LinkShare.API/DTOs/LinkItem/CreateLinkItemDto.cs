using System.ComponentModel.DataAnnotations;

namespace LinkShare.API.DTOs.LinkItem;

public class CreateLinkItemDto
{
    [Required]
    [MaxLength(300)]
    public string Title { get; set; } = string.Empty;

    [Required]
    [Url]
    [MaxLength(2000)]
    public string URL { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string Description { get; set; } = string.Empty;
}
