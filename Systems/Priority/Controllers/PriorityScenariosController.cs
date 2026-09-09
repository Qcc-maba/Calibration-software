using Maba.Api.Services.Priority.Scenarios;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Maba.Api.Controllers;

/// <summary>
/// Automated Priority workflows (OData). Scenario 1: "Return of Goods from
/// Customer" external-calibration intake. See
/// docs/scenarios/return-goods-external-calibration.md.
/// </summary>
[ApiController]
[Route("api/priority/scenarios")]
[Authorize]
public class PriorityScenariosController(
    IReturnGoodsScenarioService returnGoods,
    IShipmentScenarioService shipment) : ControllerBase
{
    // POST api/priority/scenarios/return-goods?preview=true&verify=true
    // preview=true (default) plans the OData calls without sending them — safe to run
    // before OData access exists. preview=false actually creates the document.
    // verify=true (default) re-reads every write to confirm it took; verify=false skips
    // the read-backs for a faster run with fewer transactions.
    // batch=true bundles the whole flow into 2–3 OData $batch requests (far fewer transactions).
    [HttpPost("return-goods")]
    public async Task<ActionResult<ReturnGoodsResult>> ReturnGoods(
        ReturnGoodsRequest req, CancellationToken ct, bool preview = true, bool verify = true, bool batch = false)
    {
        var result = await returnGoods.ExecuteAsync(req, preview, verify, batch, ct);
        return result.Success ? Ok(result) : StatusCode(StatusCodes.Status422UnprocessableEntity, result);
    }

    // POST api/priority/scenarios/return-goods-many
    // Processes a list of documents via chunked $batch (≤16 docs/chunk) — a few HTTP
    // requests for the whole batch instead of one flow per document.
    [HttpPost("return-goods-many")]
    public async Task<ActionResult<ReturnGoodsManyResult>> ReturnGoodsMany(
        List<ReturnGoodsRequest> reqs, CancellationToken ct)
    {
        var result = await returnGoods.ExecuteManyAsync(reqs, ct);
        return result.Success ? Ok(result) : StatusCode(StatusCodes.Status422UnprocessableEntity, result);
    }

    // POST api/priority/scenarios/shipment?preview=true&verify=true
    // Scenario 2 — "הוצאת תעודת משלוח": shipment from an intake doc (full / partial /
    // no-billing / quantity-update variants).
    [HttpPost("shipment")]
    public async Task<ActionResult<ReturnGoodsResult>> Shipment(
        ShipmentRequest req, CancellationToken ct, bool preview = true, bool verify = true)
    {
        var result = await shipment.ExecuteAsync(req, preview, verify, ct);
        return result.Success ? Ok(result) : StatusCode(StatusCodes.Status422UnprocessableEntity, result);
    }
}
