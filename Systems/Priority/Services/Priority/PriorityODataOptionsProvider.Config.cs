using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;

namespace Maba.Api.Services.Priority;

/// <summary>
/// Resolves the effective OData options. In this standalone Maba.VCT.Priority build the values come
/// from configuration ("PrioritySync:OData:*") layered over the bound appsettings defaults.
/// (maba2000-web additionally layers DB-backed settings via its IAppConfigService; that provider is
/// excluded here because it is coupled to that application's database — see README.)
/// </summary>
public interface IPriorityODataOptionsProvider
{
    Task<PriorityODataOptions> GetAsync(CancellationToken ct = default);
}

public class PriorityODataOptionsProvider(
    IOptions<PriorityODataOptions> appsettings,
    IConfiguration config) : IPriorityODataOptionsProvider
{
    public Task<PriorityODataOptions> GetAsync(CancellationToken ct = default)
    {
        var baseOpt = appsettings.Value;

        string? Get(string key)
        {
            var v = config[$"PrioritySync:OData:{key}"];
            return string.IsNullOrWhiteSpace(v) ? null : v.Trim();
        }

        return Task.FromResult(new PriorityODataOptions
        {
            BaseUrl  = Get("BaseUrl")  ?? baseOpt.BaseUrl,
            Token    = Get("Token")    ?? baseOpt.Token,
            Username = Get("Username") ?? baseOpt.Username,
            Password = Get("Password") ?? baseOpt.Password,
            Entities = new PriorityEntityNames
            {
                Users       = Get("Entities:Users")       ?? baseOpt.Entities.Users,
                Customers   = Get("Entities:Customers")   ?? baseOpt.Entities.Customers,
                Documents   = Get("Entities:Documents")   ?? baseOpt.Entities.Documents,
                CalibStatus = Get("Entities:CalibStatus") ?? baseOpt.Entities.CalibStatus,
            }
        });
    }
}
