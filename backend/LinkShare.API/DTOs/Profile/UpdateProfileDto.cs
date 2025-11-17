using System.ComponentModel.DataAnnotations;

namespace LinkShare.API.DTOs.Profile;

public class UpdateProfileDto
{
    [MaxLength(200)]
    public string DisplayName { get; set; } = string.Empty;

    [MaxLength(500)]
    public string Bio { get; set; } = string.Empty;
}
