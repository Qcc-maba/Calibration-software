using Maba.Core.Interfaces;
using Microsoft.Extensions.Options;

namespace Maba.Api.Services.Priority;

/// <summary>
/// Resolves the effective OData options by layering DB config
/// (category "PrioritySync", editable from the Settings page) over the
/// appsettings.json defaults. DB values win when present and non-empty.
/// </summary>
public interface IPriorityODataOptionsProvider
{
    Task<PriorityODataOptions> GetAsync(CancellationToken ct = default);
}

public class PriorityODataOptionsProvider(
    IOptions<PriorityODataOptions> appsettings,
    IAppConfigService config) : IPriorityODataOptionsProvider
{
    public async Task<PriorityODataOptions> GetAsync(CancellationToken ct = default)
    {
        var baseOpt = appsettings.Value;
        var db = await config.GetCategoryAsync("PrioritySync", ct);

        string? Get(string key) =>
            db.TryGetValue(key, out var v) && !string.IsNullOrWhiteSpace(v) ? v.Trim() : null;

        return new PriorityODataOptions
        {
            BaseUrl  = Get("ODataBaseUrl")  ?? baseOpt.BaseUrl,
            Token    = Get("ODataToken")    ?? baseOpt.Token,
            Username = Get("ODataUsername") ?? baseOpt.Username,
            Password = Get("ODataPassword") ?? baseOpt.Password,
            Entities = new PriorityEntityNames
            {
                Users       = Get("ODataEntityUsers")       ?? baseOpt.Entities.Users,
                Customers   = Get("ODataEntityCustomers")   ?? baseOpt.Entities.Customers,
                Documents   = Get("ODataEntityDocuments")   ?? baseOpt.Entities.Documents,
                CalibStatus = Get("ODataEntityCalibStatus") ?? baseOpt.Entities.CalibStatus,
            }
        };
    }
}
