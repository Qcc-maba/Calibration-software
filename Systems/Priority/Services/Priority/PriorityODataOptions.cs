namespace Maba.Api.Services.Priority;

/// <summary>
/// Configuration for the Priority OData REST transport. Bound from the
/// <c>PrioritySync:OData</c> section of appsettings.json.
/// </summary>
public class PriorityODataOptions
{
    /// <summary>
    /// Full OData service-root URL, e.g.
    /// <c>https://server/odata/Priority/tabula.ini/{environment}</c>
    /// (environment = the company internal name in Priority).
    /// </summary>
    public string? BaseUrl { get; set; }

    /// <summary>
    /// REST authentication token (PAT). When set, Basic-Auth is sent as
    /// <c>{Token}:PAT</c> per the Priority OData guide. Preferred for
    /// Priority Accounts / AD / SSO installations.
    /// </summary>
    public string? Token { get; set; }

    /// <summary>On-prem fallback: the value of the "API username" field on the employee card.</summary>
    public string? Username { get; set; }

    /// <summary>On-prem fallback: the Priority user's password.</summary>
    public string? Password { get; set; }

    /// <summary>
    /// OData entity (Priority screen internal-name) per logical table. Defaults
    /// mirror the legacy SQL load-table names; adjust to match the screens you
    /// exposed to the API ("פתוח לרשיון API") and the $metadata document.
    /// </summary>
    public PriorityEntityNames Entities { get; set; } = new();
}

public class PriorityEntityNames
{
    public string Users { get; set; } = "MBA_USERSLOAD";
    public string Customers { get; set; } = "MBA_CUSTLOAD";
    public string Documents { get; set; } = "MBA_DOCLOAD";
    public string CalibStatus { get; set; } = "MBA_CALIBLOAD";
}
