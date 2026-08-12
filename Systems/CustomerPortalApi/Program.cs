using Maba.VCT.CustomerPortalApi;
using Maba.VCT.CustomerPortalApi.Auth;
using Maba.VCT.CustomerPortalApi.Data;
using Maba.VCT.CustomerPortalApi.Mail;
using Maba.VCT.CustomerPortalApi.Models;
using Maba.VCT.CustomerPortalApi.Options;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using System.Net;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddOptions<CustomerPortalOptions>()
    .Bind(builder.Configuration.GetSection(CustomerPortalOptions.SectionName));

builder.Services.AddSingleton<CustomerPortalRepository>();
builder.Services.AddSingleton<IMailSender, SmtpMailSender>();
builder.Services.AddSingleton<CustomerAuthService>();
builder.Services.AddSingleton(sp =>
    new CustomerSessionService(sp.GetRequiredService<IOptions<CustomerPortalOptions>>().Value.SessionSecret));

/* The browser sends the session cookie cross-origin, so the allowed origins have to be explicit -
   AllowAnyOrigin and AllowCredentials cannot be combined. */
var allowedOrigins = builder.Configuration
    .GetSection($"{CustomerPortalOptions.SectionName}:AllowedOrigins")
    .Get<string[]>() ?? [];

builder.Services.AddCors(o => o.AddDefaultPolicy(policy => policy
    .WithOrigins(allowedOrigins)
    .AllowCredentials()
    .AllowAnyHeader()
    .AllowAnyMethod()));

var settings = builder.Configuration
    .GetSection(CustomerPortalOptions.SectionName)
    .Get<CustomerPortalOptions>() ?? new CustomerPortalOptions();

/* The database caps codes per e-mail address, which does nothing to stop one caller working
   through a list of different addresses. This caps the caller itself. */
builder.Services.AddRateLimiter(limiter =>
{
    limiter.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    limiter.AddPolicy(PerCallerPolicy, context => RateLimitPartition.GetFixedWindowLimiter(
        context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = settings.RateLimit.PermitPerWindow,
            Window = TimeSpan.FromSeconds(settings.RateLimit.WindowSeconds),
            QueueLimit = 0,
        }));
});

var app = builder.Build();

/* Behind a proxy every request arrives from the proxy's address, so without this the per-caller
   limit would be one shared bucket for all customers. Only proxies listed in configuration are
   believed - trusting the header from anyone lets a caller forge its own address. */
if (settings.TrustedProxies.Length > 0)
{
    var forwarded = new ForwardedHeadersOptions
    {
        ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
    };

    forwarded.KnownIPNetworks.Clear();
    forwarded.KnownProxies.Clear();

    foreach (var proxy in settings.TrustedProxies)
    {
        if (IPAddress.TryParse(proxy, out var address))
        {
            forwarded.KnownProxies.Add(address);
        }
    }

    app.UseForwardedHeaders(forwarded);
}

app.UseCors();
app.UseRateLimiter();

var options = app.Services.GetRequiredService<IOptions<CustomerPortalOptions>>().Value;

/* Rejects callers that do not hold the shared secret. Applied to the login endpoints only:
   /health has to stay reachable for monitoring. */
async ValueTask<object?> RequireApiKey(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
{
    var presented = context.HttpContext.Request.Headers[ProxyApiKey.HeaderName].ToString();

    return ProxyApiKey.Matches(presented, options.ProxyApiKey)
        ? await next(context)
        : Results.Json(new { error = "unauthorized" }, statusCode: StatusCodes.Status401Unauthorized);
}

CookieOptions SessionCookie(TimeSpan maxAge) => new()
{
    HttpOnly = true,
    Secure = options.SecureCookies,
    /* Lax still travels on the top-level navigation back from the portal, and keeps the cookie off
       cross-site sub-requests. */
    SameSite = SameSiteMode.Lax,
    Path = "/",
    MaxAge = maxAge,
};

app.MapGet("/health", () => Results.Ok(new
{
    status = "ok",
    database = string.IsNullOrWhiteSpace(options.ConnectionString) ? "unconfigured" : "configured",
    smtp = string.IsNullOrWhiteSpace(options.Smtp.User) ? "unconfigured" : "configured",
}));

/* Steps 1-3 of the login: is this a customer contact, and if so mail it a fresh code. */
app.MapPost("/api/customer-auth/request-otp", async (
    RequestOtpRequest request,
    CustomerAuthService auth,
    HttpContext context,
    CancellationToken cancellationToken) =>
{
    if (!CustomerAuthService.TryNormalizeEmail(request.Email, out var email))
    {
        return Results.BadRequest(new { error = "invalidEmail" });
    }

    var response = await auth.RequestOtpAsync(
        email,
        context.Connection.RemoteIpAddress?.ToString(),
        cancellationToken);

    return Results.Ok(response);
})
.AddEndpointFilter(RequireApiKey)
.RequireRateLimiting(PerCallerPolicy);

/* Step 4: redeem the code and issue the session cookie. */
app.MapPost("/api/customer-auth/verify-otp", async (
    VerifyOtpRequest request,
    CustomerAuthService auth,
    CustomerSessionService sessions,
    HttpContext context,
    CancellationToken cancellationToken) =>
{
    if (!CustomerAuthService.TryNormalizeEmail(request.Email, out var email) ||
        !OtpCode.IsWellFormed(request.Code?.Trim() ?? string.Empty))
    {
        return Results.BadRequest(new { error = "invalidInput" });
    }

    var (response, token) = await auth.VerifyOtpAsync(
        email,
        request.Code!.Trim(),
        sessions,
        cancellationToken);

    if (token is not null)
    {
        context.Response.Cookies.Append(
            CustomerSessionService.CookieName,
            token,
            SessionCookie(TimeSpan.FromSeconds(options.SessionTtlSeconds)));
    }

    return Results.Ok(response);
})
.AddEndpointFilter(RequireApiKey)
.RequireRateLimiting(PerCallerPolicy);

/* Wrapped in an object rather than returned bare: a bare null serialises to an empty body, which
   throws in the browser on res.json(). A signed-out visitor gets {"session":null}. */
app.MapGet("/api/customer-auth/me", (CustomerSessionService sessions, HttpContext context) =>
    Results.Ok(new MeResponse(sessions.Read(context.Request.Cookies[CustomerSessionService.CookieName]))))
.AddEndpointFilter(RequireApiKey);

app.MapPost("/api/customer-auth/sign-out", (HttpContext context) =>
{
    context.Response.Cookies.Delete(
        CustomerSessionService.CookieName,
        SessionCookie(TimeSpan.Zero));

    return Results.NoContent();
})
.AddEndpointFilter(RequireApiKey);

app.Run();

/* Named so the registration and the endpoints cannot drift apart. */
public partial class Program
{
    public const string PerCallerPolicy = "per-caller";
}
