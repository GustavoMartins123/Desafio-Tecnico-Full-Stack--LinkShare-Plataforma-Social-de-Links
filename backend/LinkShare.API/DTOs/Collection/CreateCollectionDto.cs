using System.ComponentModel.DataAnnotations;

namespace LinkShare.API.DTOs.Collection;

public class CreateCollectionDto
{
    [Required]
    [MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string Description { get; set; } = string.Empty;

    public bool IsPublic { get; set; } = false;
}
