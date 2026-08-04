-- =====================================================================
-- Jira:        MBA-836  Customer Support Manager - Agents Overview screen
-- Author:      Claude (subagent) for Dako
-- Create date: 2026-08-04
-- Description: Manager/coordinator-facing per-agent WORKLOAD breakdown for
--              the Customer Support Manager "Agents Overview" screen.
--
--              Belongs to the GetLaboratoryView* family (no parameters,
--              manager-facing, all agents). The FE applies its own agent
--              allow-list (see components/dashboard/constants/agent-names.ts),
--              exactly like GetLaboratoryViewAgentsWaitingList - so this SP
--              returns every agent present in the operational waiting list.
--
--              SCOPE NOTE: The ticket asks for "sales performance + workload".
--              Only the WORKLOAD half is sourced here, because the operational
--              Calibrator model has no reliable agent<->revenue link:
--                - dbo.Customers has no agent column;
--                - the only agent/customer mapping is stg.stg_Customers
--                  .AgentUserEmail (ETL staging, ~70% populated, 9 emails
--                  that do not match the 4-name FE allow-list);
--                - OrderDetails.PRICE is a quoted calibration-line price, not
--                  confirmed sales/revenue, and cannot be attributed to an
--                  agent operationally;
--                - there are no sales targets in Calibrator.
--              True per-agent sales performance/targets live in Priority ERP
--              and must be sourced there (see MBA-836 for the blocked note).
-- =====================================================================
CREATE OR ALTER PROCEDURE [dbo].[GetLaboratoryViewAgentsOverview]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
         awl.[AgentName]                                   AS AgentName
        ,COUNT(*)                                          AS WaitingItemsCount
        ,COUNT(DISTINCT awl.[CustomerNumber])             AS CustomersCount
    FROM [dbo].[AgentsWaitingList] AS awl
    WHERE awl.[AgentName] IS NOT NULL
      AND LTRIM(RTRIM(awl.[AgentName])) <> ''
    GROUP BY awl.[AgentName]
    ORDER BY WaitingItemsCount DESC;
END
