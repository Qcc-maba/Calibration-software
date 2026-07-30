using Maba.Core.Interfaces;

namespace Maba.Api.Services;

public class PrioritySyncBackgroundService(
    IServiceScopeFactory scopeFactory,
    ILogger<PrioritySyncBackgroundService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Wait for app startup + config seed to complete
        await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);

        logger.LogInformation("Priority sync background service started");

        while (!stoppingToken.IsCancellationRequested)
        {
            bool enabled;
            int intervalMinutes;

            // Read config from DB each iteration (runtime-configurable via Settings page)
            using (var scope = scopeFactory.CreateScope())
            {
                var cfgSvc = scope.ServiceProvider.GetRequiredService<IAppConfigService>();
                var cat = await cfgSvc.GetCategoryAsync("PrioritySync", stoppingToken);
                enabled = cat.TryGetValue("Enabled", out var e) && bool.TryParse(e, out var b) && b;
                intervalMinutes = cat.TryGetValue("IntervalMinutes", out var m) && int.TryParse(m, out var i) && i > 0 ? i : 30;
            }

            if (!enabled)
            {
                // Re-check every 5 minutes in case admin enables sync via UI
                await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
                continue;
            }

            await Task.Delay(TimeSpan.FromMinutes(intervalMinutes), stoppingToken);

            try
            {
                using var scope = scopeFactory.CreateScope();
                var syncService = scope.ServiceProvider.GetRequiredService<IPrioritySyncService>();
                var result = await syncService.PullAllAsync("auto", stoppingToken);
                logger.LogInformation("Background sync completed: {Count} items synced", result.ItemsSynced);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Background sync failed");
            }
        }
    }
}
