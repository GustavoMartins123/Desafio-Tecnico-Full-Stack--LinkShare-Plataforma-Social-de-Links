namespace LinkShare.API.DTOs.Device;

public class RegisterDeviceDto
{
    public string FcmToken { get; set; } = string.Empty;
    public string DeviceName { get; set; } = string.Empty;
    public string Platform { get; set; } = string.Empty; // "android" or "ios"
}
