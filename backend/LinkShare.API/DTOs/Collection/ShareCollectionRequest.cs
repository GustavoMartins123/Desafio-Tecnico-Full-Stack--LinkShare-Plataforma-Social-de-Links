using System.ComponentModel.DataAnnotations;

namespace LinkShare.API.DTOs.Collection;

public class ShareCollectionRequest
{
    [Required]
    public int SharedWithUserId { get; set; }

    public bool CanEdit { get; set; } = false;
}
