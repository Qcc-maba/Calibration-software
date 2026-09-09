"""Copy one customer's orders from CalibratorProd into Calibrator (STAGE).

STAGE knows Philips (CustomerId 6601) and even holds 8 of its work plans, but not a single
OrderDetailsItems row - so every portal screen is empty for that identity while PROD has 22 devices
across 8 other orders.

The ids of the lookup tables do NOT line up between the two servers: 69 of 158 Statuses and 608 of
610 OrdersProductTypes carry the same id with a different name. Every reference is therefore
translated by NAME, and anything that has no counterpart on STAGE is written as NULL rather than
pointed at whatever happens to sit on that id.

Nothing is deleted and nothing existing is touched: only new rows are inserted, and their ids are
written to an undo file.
"""

import io
import json
import os
import re
import sys

import pyodbc

ROOT = r"c:\Users\eliran_ha\OneDrive - MBA\Documents\Eliran\MBA\Calibration-software"
CUSTOMER_ID = 6601
UNDO_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "undo_philips_copy.sql")


def stage_cursor():
    cfg = json.load(io.open(os.path.join(ROOT, "Systems", "CustomerPortalApi", "appsettings.Development.json"), encoding="utf-8"))
    kv = dict(p.split("=", 1) for p in cfg["CustomerPortal"]["ConnectionString"].split(";") if "=" in p)
    connection = pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};SERVER=%s,1433;DATABASE=Calibrator;UID=%s;PWD=%s;TrustServerCertificate=yes"
        % (kv["Server"], kv["User Id"], kv["Password"]),
        timeout=300,
        autocommit=False,
    )
    return connection


def columns(cursor, table):
    return [r[0] for r in cursor.execute(
        "SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('dbo.%s') AND is_identity = 0 AND is_computed = 0 ORDER BY column_id" % table
    ).fetchall()]


def name_map(cursor, table, key, name):
    """PROD id -> STAGE id, matched on the name both sides agree on."""
    stage = {}
    for row in cursor.execute("SELECT %s, %s FROM dbo.%s" % (key, name, table)).fetchall():
        if row[1] is not None:
            stage.setdefault(str(row[1]).strip(), row[0])

    mapping = {}
    for row in cursor.execute("SELECT %s, %s FROM CalibratorProd.dbo.%s" % (key, name, table)).fetchall():
        if row[1] is not None:
            mapping[row[0]] = stage.get(str(row[1]).strip())

    return mapping


def main(apply_changes):
    connection = stage_cursor()
    cursor = connection.cursor()

    print("connected:", cursor.execute("SELECT @@SERVERNAME + ' / ' + DB_NAME()").fetchval())

    missing = [r[0] for r in cursor.execute("""
        SELECT p.OrderNumber
        FROM CalibratorProd.dbo.OrderWorkPlans p
        WHERE p.CustomerId = ?
          AND NOT EXISTS (SELECT 1 FROM dbo.OrderWorkPlans s WHERE s.OrderNumber = p.OrderNumber)
        ORDER BY p.OrderNumber""", CUSTOMER_ID).fetchall()]
    print("work plans on PROD that STAGE does not have:", ", ".join(missing) or "none")

    if not missing:
        return

    maps = {
        "status": name_map(cursor, "Statuses", "StatusId", "StatusDescriptionENG"),
        "productType": name_map(cursor, "OrdersProductTypes", "OrdersProductTypeId", "OrdersProductTypeName"),
        "mainCategory": name_map(cursor, "MainCategories", "ID", "MainCategoryName"),
        "secondaryCategory": name_map(cursor, "SecondaryCategories", "ID", "SecondaryCategoryName"),
    }
    print("lookup maps built:", {k: len(v) for k, v in maps.items()})

    # column -> which map translates it; anything not listed is copied as-is, and the user columns
    # are blanked because Users are numbered differently again.
    translate = {
        "OrderStatusId": "status",
        "OrderOverallStatusId": "status",
        "ClientConfirmationStatusId": "status",
        "CalibrationStatusId": "status",
        "CalibrationReportStatusId": "status",
        "OrdersProductTypeId": "productType",
        "MainCategoryId": "mainCategory",
        "SecondaryCategoryId": "secondaryCategory",
    }
    blank = {"CreatedByUserId", "UpdateUserID", "CalibratorId", "CustomerSiteId", "SpecialCareTypeId"}

    def translated(table_columns, row):
        values = []
        for column, value in zip(table_columns, row):
            if column in blank:
                values.append(None)
            elif column in translate and value is not None:
                values.append(maps[translate[column]].get(value))
            else:
                values.append(value)
        return values

    wp_columns = columns(cursor, "OrderWorkPlans")
    od_columns = columns(cursor, "OrderDetails")
    itm_columns = columns(cursor, "OrderDetailsItems")

    inserted = {"OrderWorkPlans": [], "OrderDetails": [], "OrderDetailsItems": []}
    placeholders = lambda cols: ", ".join("?" * len(cols))
    quoted = lambda cols: ", ".join("[%s]" % c for c in cols)

    for order_number in missing:
        wp = cursor.execute(
            "SELECT %s, OrderWorkPlanId FROM CalibratorProd.dbo.OrderWorkPlans WHERE OrderNumber = ? AND CustomerId = ?"
            % quoted(wp_columns), order_number, CUSTOMER_ID).fetchone()
        prod_wp_id = wp[-1]
        values = translated(wp_columns, list(wp)[:-1])

        cursor.execute(
            "INSERT INTO dbo.OrderWorkPlans (%s) OUTPUT INSERTED.OrderWorkPlanId VALUES (%s)"
            % (quoted(wp_columns), placeholders(wp_columns)), *values)
        new_wp_id = cursor.fetchval()
        inserted["OrderWorkPlans"].append(new_wp_id)

        details = cursor.execute(
            "SELECT %s, OrderDetailId FROM CalibratorProd.dbo.OrderDetails WHERE OrderWorkPlanId = ?"
            % quoted(od_columns), prod_wp_id).fetchall()

        for detail in details:
            prod_detail_id = detail[-1]
            values = translated(od_columns, list(detail)[:-1])
            values[od_columns.index("OrderWorkPlanId")] = new_wp_id

            cursor.execute(
                "INSERT INTO dbo.OrderDetails (%s) OUTPUT INSERTED.OrderDetailId VALUES (%s)"
                % (quoted(od_columns), placeholders(od_columns)), *values)
            new_detail_id = cursor.fetchval()
            inserted["OrderDetails"].append(new_detail_id)

            items = cursor.execute(
                "SELECT %s FROM CalibratorProd.dbo.OrderDetailsItems WHERE OrderDetailId = ?"
                % quoted(itm_columns), prod_detail_id).fetchall()

            for item in items:
                values = translated(itm_columns, list(item))
                values[itm_columns.index("OrderDetailId")] = new_detail_id
                cursor.execute(
                    "INSERT INTO dbo.OrderDetailsItems (%s) OUTPUT INSERTED.OrderDetailsItemId VALUES (%s)"
                    % (quoted(itm_columns), placeholders(itm_columns)), *values)
                inserted["OrderDetailsItems"].append(cursor.fetchval())

    print("inserted:", {k: len(v) for k, v in inserted.items()})

    devices = cursor.execute("""
        SELECT COUNT_BIG(DISTINCT itm.SerialNumber)
        FROM dbo.OrderWorkPlans wp
        JOIN dbo.OrderDetails od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
        JOIN dbo.OrderDetailsItems itm ON itm.OrderDetailId = od.OrderDetailId
        WHERE wp.CustomerId = ?""", CUSTOMER_ID).fetchval()
    print("distinct devices for the customer after the copy:", devices)

    if not apply_changes:
        connection.rollback()
        print("ROLLED BACK - pass --apply to keep it")
        return

    connection.commit()
    print("COMMITTED")

    io.open(UNDO_PATH, "w", encoding="utf-8", newline="").write(
        "/* Undo the Philips copy into STAGE. Run against Calibrator. */\n"
        "DELETE FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId IN (%s);\n"
        "DELETE FROM dbo.OrderDetails      WHERE OrderDetailId      IN (%s);\n"
        "DELETE FROM dbo.OrderWorkPlans    WHERE OrderWorkPlanId    IN (%s);\n"
        % (
            ", ".join(str(i) for i in inserted["OrderDetailsItems"]),
            ", ".join(str(i) for i in inserted["OrderDetails"]),
            ", ".join(str(i) for i in inserted["OrderWorkPlans"]),
        )
    )
    print("undo written to", UNDO_PATH)


if __name__ == "__main__":
    main("--apply" in sys.argv)
