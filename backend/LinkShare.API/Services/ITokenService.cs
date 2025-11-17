using LinkShare.API.Entities;

namespace LinkShare.API.Services;

public interface ITokenService
{
    string GenerateToken(User user);
}
