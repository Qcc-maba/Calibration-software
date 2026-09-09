#!/usr/bin/env python3
"""
סינכרון לקוח בודד - הרץ עם מספר לקוח כארגומנט
python sync-single-customer.py 396
"""

import sys
import pyodbc
import requests
from typing import Dict, Any, List
from datetime import datetime, timedelta

SQL_CONFIG = {
    'server': r'51.17.121.203\QCC,1433',
    'database': 'QCCData',
    'username': 'eliran',
    'password': 'En1013#$'
}

REPLIT_BASE_URL = "https://232ca506-7be9-4e7f-a436-7bb478f77860-00-1bf7ltq07a1po.riker.replit.dev"

def get_connection():
    connection_string = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE={SQL_CONFIG['database']};"
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']}"
    )
    return pyodbc.connect(connection_string)

def fetch_customer_data(customer_id: str) -> Dict[str, Any]:
    conn = get_connection()
    cursor = conn.cursor()
    
    print(f"  [1/5] שולף מידע בסיסי מ-datasheet...")
    cursor.execute("""
        SELECT TOP 1 [Customer_Num], [Customer_Name]
        FROM [dbo].[datasheet]
        WHERE [Customer_Num] = ?
    """, customer_id)
    
    customer_row = cursor.fetchone()
    if not customer_row:
        raise ValueError(f"לקוח {customer_id} לא נמצא בטבלת datasheet")
    
    print(f"      נמצא: {customer_row[1]}")
    
    print(f"  [2/5] שולף כתובת מ-CustomerMain...")
    cursor.execute("""
        SELECT TOP 1 [Address], [City], [STATE], [Shipping Description], [Agent name]
        FROM [dbo].[CustomerMain]
        WHERE LTRIM(RTRIM([Customer number])) = ? 
           OR [Customer number] = ?
           OR CAST([Customer number] AS VARCHAR) = ?
    """, customer_id.strip(), customer_id, customer_id)
    
    customer_main = cursor.fetchone()
    
    address = ''
    shipping_method = 'UPS'
    agent_name = ''
    
    if customer_main:
        print(f"      נמצא ב-CustomerMain!")
        addr_parts = []
        if customer_main.Address:
            addr_parts.append(customer_main.Address.strip())
        if customer_main.STATE:
            addr_parts.append(customer_main.STATE.strip())
        if customer_main.City:
            addr_parts.append(customer_main.City.strip())
        address = ', '.join(addr_parts) if addr_parts else ''
        if customer_main[3]:
            shipping_method = customer_main[3].strip()
        if customer_main[4]:
            agent_name = customer_main[4].strip()
        print(f"      כתובת: {address}")
        print(f"      סוכן: {agent_name}")
    else:
        print(f"      לא נמצא ב-CustomerMain")
    
    print(f"  [3/5] שולף אנשי קשר מ-ContactMain...")
    cursor.execute("""
        SELECT [Name], [Phone], [Mobile], [Email], [Main_Contact]
        FROM [dbo].[ContactMain]
        WHERE LTRIM(RTRIM([קשור ללקוח])) = ?
           OR [קשור ללקוח] = ?
           OR CAST([קשור ללקוח] AS VARCHAR) = ?
    """, customer_id.strip(), customer_id, customer_id)
    
    contacts = []
    for row in cursor.fetchall():
        if row.Name:
            phone = row.Phone.strip() if row.Phone else (row.Mobile.strip() if row.Mobile else '')
            contacts.append({
                'name': row.Name.strip(),
                'role': 'איש קשר ראשי' if row.Main_Contact == 'Y' else 'איש קשר',
                'phone': phone,
                'email': row.Email.strip() if row.Email else ''
            })
    print(f"      נמצאו {len(contacts)} אנשי קשר")
    for c in contacts:
        print(f"        - {c['name']}: {c['phone']}")
    
    print(f"  [4/6] שולף מכשירים מ-datasheet...")
    cursor.execute("""
        SELECT COUNT(DISTINCT [Serial_No]) as totalDevices
        FROM [dbo].[datasheet]
        WHERE [Customer_Num] = ?
    """, customer_id)
    device_row = cursor.fetchone()
    total_devices = device_row.totalDevices if device_row else 0
    print(f"      נמצאו {total_devices} מכשירים")
    
    # שליפת מכשירים שדורשים כיול (באיחור)
    print(f"  [5/6] שולף מכשירים באיחור כיול...")
    cursor.execute("""
        SELECT TOP 50
            [Serial_No] as serialNo,
            [Device description] as deviceName,
            [Cal_Date] as lastCalDate,
            [Next_Cal_Date] as nextCalDate
        FROM [dbo].[datasheet]
        WHERE [Customer_Num] = ? 
            AND [Next_Cal_Date] < GETDATE()
            AND [Next_Cal_Date] >= DATEADD(year, -1, GETDATE())
        ORDER BY [Next_Cal_Date] DESC
    """, customer_id)
    
    alerts = []
    for row in cursor.fetchall():
        device_name = row.deviceName.strip() if row.deviceName else 'מכשיר'
        serial = row.serialNo.strip() if row.serialNo else ''
        last_cal = row.lastCalDate.strftime('%d/%m/%Y') if row.lastCalDate else 'לא ידוע'
        next_cal = row.nextCalDate.strftime('%d/%m/%Y') if row.nextCalDate else 'לא ידוע'
        
        alerts.append({
            'type': 'warning',
            'title': f'{device_name} - כיול באיחור',
            'message': f'ס"נ: {serial}',
            'serialNo': serial,
            'lastCalDate': last_cal,
            'nextCalDate': next_cal
        })
    print(f"      נמצאו {len(alerts)} מכשירים באיחור")
    
    # חישוב מכשירים פעילים
    cursor.execute("""
        SELECT COUNT(DISTINCT [Serial_No]) as activeDevices
        FROM [dbo].[datasheet]
        WHERE [Customer_Num] = ? 
            AND [Next_Cal_Date] >= GETDATE()
    """, customer_id)
    active_row = cursor.fetchone()
    active_devices = active_row.activeDevices if active_row else 0
    out_for_cal = total_devices - active_devices
    print(f"      פעילים: {active_devices}, דורשים כיול: {out_for_cal}")
    
    # שליפת סוגי כיולים
    colors = ["hsl(215 100% 50%)", "hsl(180 70% 45%)", "hsl(280 60% 60%)", "hsl(40 90% 60%)", "hsl(340 70% 60%)"]
    cursor.execute("""
        SELECT 
            ISNULL([SKA], 'אחר') as calibrationType,
            COUNT(*) as count
        FROM [dbo].[datasheet]
        WHERE [Customer_Num] = ? AND [SKA] IS NOT NULL
        GROUP BY [SKA]
        ORDER BY count DESC
    """, customer_id)
    
    calibration_types = []
    for idx, row in enumerate(cursor.fetchall()):
        calibration_types.append({
            'name': row.calibrationType.strip() if row.calibrationType else 'אחר',
            'value': int(row.count),
            'color': colors[idx % len(colors)]
        })
    print(f"      נמצאו {len(calibration_types)} סוגי כיולים")
    
    print(f"  [6/6] שולף נתונים פיננסיים מ-OrdersFULL...")
    financials = []
    for year in [2023, 2024, 2025]:
        cursor.execute("""
            SELECT 
                COUNT(DISTINCT [Order Number]) as ordersCount,
                COUNT(DISTINCT CASE WHEN [Quotation] IS NOT NULL AND LEN([Quotation]) > 0 THEN [Quotation] END) as quotesCount,
                ISNULL(SUM([Price after discount]), 0) as revenue,
                ISNULL(SUM([Price after discount] * [Discount Percentage] / 100), 0) as discountsTotal
            FROM [dbo].[OrdersFULL]
            WHERE (
                LTRIM(RTRIM([Customer Number])) = ?
                OR [Customer Number] = ?
                OR CAST([Customer Number] AS VARCHAR) = ?
            )
            AND YEAR([CurrentDate]) = ?
        """, customer_id.strip(), customer_id, customer_id, year)
        
        fin_row = cursor.fetchone()
        revenue = float(fin_row.revenue) if fin_row and fin_row.revenue else 0
        orders = int(fin_row.ordersCount) if fin_row and fin_row.ordersCount else 0
        quotes = int(fin_row.quotesCount) if fin_row and fin_row.quotesCount else 0
        discounts = float(fin_row.discountsTotal) if fin_row and fin_row.discountsTotal else 0
        financials.append({'year': year, 'revenue': revenue, 'ordersCount': orders, 'quotesCount': quotes, 'discountsTotal': discounts})
        if revenue > 0 or orders > 0:
            print(f"      {year}: הכנסות {revenue:,.0f} ₪, {orders} הזמנות, {quotes} הצעות, הנחות {discounts:,.0f} ₪")
    
    cursor.close()
    conn.close()
    
    return {
        'customer': {
            'hp': customer_id,
            'companyName': customer_row[1].strip() if customer_row[1] else f'לקוח {customer_id}',
            'address': address,
            'shippingMethod': shipping_method,
            'agentName': agent_name
        },
        'contacts': contacts,
        'financials': financials,
        'deviceInventory': {
            'totalDevices': total_devices, 
            'activeDevices': active_devices, 
            'outForCalibration': out_for_cal
        },
        'calibrationTypes': calibration_types if calibration_types else [{'name': 'אין נתונים', 'value': 1, 'color': colors[0]}],
        'monthlyCalibrationDistribution': [],
        'calibrationLocationSplit': {'internal': 70, 'external': 30},
        'meetingNotes': [],
        'recentCalibrations': [],
        'alerts': alerts
    }

def sync_to_replit(customer_id: str, data: Dict[str, Any]) -> bool:
    payload = {
        'id': customer_id,
        'companyName': data['customer']['companyName'],
        'hp': data['customer']['hp'],
        'address': data['customer']['address'],
        'shippingMethod': data['customer']['shippingMethod'],
        'agentName': data['customer']['agentName'],
        'contacts': data['contacts'],
        'financials': data['financials'],
        'deviceInventory': data['deviceInventory'],
        'calibrationTypes': data['calibrationTypes'],
        'monthlyCalibrationDistribution': data['monthlyCalibrationDistribution'],
        'calibrationLocationSplit': data['calibrationLocationSplit'],
        'meetingNotes': data['meetingNotes'],
        'recentCalibrations': data['recentCalibrations'],
        'alerts': data['alerts']
    }
    
    try:
        url = f"{REPLIT_BASE_URL}/api/sync/customer-data"
        print(f"      URL: {url}")
        response = requests.post(url, json=payload, timeout=30)
        print(f"      Response status: {response.status_code}")
        if response.status_code != 200:
            print(f"      Response: {response.text[:500]}")
        return response.status_code == 200
    except Exception as e:
        print(f"      Connection error: {e}")
        return False

if __name__ == "__main__":
    print("Starting sync-single-customer script...")
    print(f"Arguments received: {sys.argv}")
    
    if len(sys.argv) < 2:
        print("Usage: python sync-single-customer.py <customer_id>")
        print("Example: python sync-single-customer.py 396")
        sys.exit(1)
    
    customer_id = sys.argv[1]
    print(f"\n{'='*50}")
    print(f"Syncing customer: {customer_id}")
    print(f"{'='*50}\n")
    
    try:
        print("Connecting to database...")
        data = fetch_customer_data(customer_id)
        
        print(f"\n--- סיכום נתונים ---")
        print(f"  שם: {data['customer']['companyName']}")
        print(f"  כתובת: {data['customer']['address'] or '(לא נמצא)'}")
        print(f"  סוכן: {data['customer']['agentName'] or '(לא נמצא)'}")
        print(f"  אנשי קשר: {len(data['contacts'])}")
        print(f"  מכשירים: {data['deviceInventory']['totalDevices']}")
        
        print(f"\n  שולח לשרת Replit...")
        success = sync_to_replit(customer_id, data)
        
        if success:
            print(f"\n✓ לקוח {customer_id} סונכרן בהצלחה!")
        else:
            print(f"\n✗ שגיאה בסינכרון לקוח {customer_id}")
    except Exception as e:
        print(f"\n✗ שגיאה: {e}")
