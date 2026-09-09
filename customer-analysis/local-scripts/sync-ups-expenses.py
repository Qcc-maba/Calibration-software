#!/usr/bin/env python3
"""
סקריפט סנכרון הוצאות UPS מ-Priority ERP

גרסה: 1.0
מושך נתוני הוצאות משילוח UPS ומחשבוניות ספק UPS

שימוש:
    python sync-ups-expenses.py
"""

VERSION = "1.0"

import pyodbc
import requests
import json
import argparse
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional

# ========== טעינת הגדרות ==========
try:
    from config import SQL_CONFIG, REPLIT_API_URL
    print(f"[CONFIG] Server: {SQL_CONFIG['server']}/{SQL_CONFIG['database']}")
except ImportError:
    import os
    SQL_CONFIG = {
        'server': os.environ.get('SQL_SERVER', r'maba-priority\pri'),
        'database': os.environ.get('SQL_DATABASE', 'amaba'),
        'username': os.environ.get('SQL_UID', ''),
        'password': os.environ.get('SQL_PWD', '')
    }
    REPLIT_API_URL = os.environ.get('REPLIT_API_URL', 'https://your-replit-url.replit.dev/api/sync/customer-data')
    if not SQL_CONFIG['username']:
        print("[ERROR] חסר קובץ config.py או environment variables")

# Get base URL for UPS expenses endpoint
if '/api/sync' in REPLIT_API_URL:
    BASE_URL = REPLIT_API_URL.rsplit('/api/sync', 1)[0]
else:
    BASE_URL = REPLIT_API_URL.rstrip('/')

UPS_EXPENSES_URL = f"{BASE_URL}/api/sync/ups-expenses"

# ========== פונקציות עזר לתאריכים ==========
PRIORITY_EPOCH = datetime(1988, 1, 1)

def priority_date_to_datetime(priority_date: int) -> Optional[datetime]:
    if not priority_date or priority_date <= 0:
        return None
    try:
        return PRIORITY_EPOCH + timedelta(minutes=priority_date)
    except:
        return None

def format_date(dt: datetime) -> str:
    if dt:
        return dt.strftime('%d/%m/%Y')
    return ''

def _detect_driver():
    """Auto-detect available ODBC driver for SQL Server"""
    drivers = pyodbc.drivers()
    for d in drivers:
        if "ODBC Driver 18 for SQL Server" in d:
            return d
        if "ODBC Driver 17 for SQL Server" in d:
            return d
    for d in drivers:
        if "SQL Server" in d:
            return d
    raise RuntimeError(f"No SQL Server ODBC driver found. Available: {drivers}")

def get_connection():
    """Create connection to SQL Server with auto-detected driver"""
    driver = _detect_driver()
    conn_str = (
        f"DRIVER={{{driver}}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE={SQL_CONFIG['database']};"
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']};"
        f"TrustServerCertificate=yes"
    )
    return pyodbc.connect(conn_str)

def fetch_ups_shipping_costs(conn) -> List[Dict]:
    """Query 1: Get UPS shipping costs from invoice items with PART = '7720'"""
    query = """
    SELECT 
        INVOICES.IV,
        INVOICES.IVNUM,
        INVOICES.DOC,
        INVOICES.IVDATE,
        INVOICES.CUST,
        CUSTOMERS.CUSTDES as CustomerName,
        INVOICES.CURRENCY,
        INVOICEITEMS.PRICE,
        INVOICEITEMS.VPRICE,
        INVOICEITEMS.PART
    FROM INVOICES
    INNER JOIN INVOICEITEMS ON INVOICES.IV = INVOICEITEMS.IV
    INNER JOIN CUSTOMERS ON INVOICES.CUST = CUSTOMERS.CUST
    WHERE INVOICEITEMS.PART = '7720'
    """
    
    cursor = conn.cursor()
    cursor.execute(query)
    
    rows = []
    columns = [column[0] for column in cursor.description]
    
    for row in cursor.fetchall():
        row_dict = dict(zip(columns, row))
        
        ivdate_raw = row_dict.get('IVDATE')
        if ivdate_raw:
            dt = priority_date_to_datetime(ivdate_raw)
            row_dict['ivdate_formatted'] = format_date(dt) if dt else ''
            row_dict['ivdate_year'] = dt.year if dt else None
            row_dict['ivdate_month'] = dt.month if dt else None
        else:
            row_dict['ivdate_formatted'] = ''
            row_dict['ivdate_year'] = None
            row_dict['ivdate_month'] = None
        
        rows.append({
            'iv': str(row_dict.get('IV', '')),
            'ivnum': str(row_dict.get('IVNUM', '')),
            'doc': str(row_dict.get('DOC', '')),
            'ivdate': row_dict['ivdate_formatted'],
            'cust': str(row_dict.get('CUST', '')),
            'customerName': row_dict.get('CustomerName', ''),
            'currency': row_dict.get('CURRENCY', ''),
            'amount': float(row_dict.get('PRICE', 0) or 0),
            'vatPrice': float(row_dict.get('VPRICE', 0) or 0),
            'source': 'part_7720',
            'part': str(row_dict.get('PART', '7720')),
            'data': row_dict
        })
    
    return rows

def fetch_ups_supplier_invoices(conn) -> List[Dict]:
    """Query 2: Get supplier invoices from UPS (CUST = 833, IVNUM like 'SI%')"""
    query = """
    SELECT 
        IV,
        IVNUM,
        DOC,
        IVDATE,
        CUST,
        CURRENCY,
        QPRICE,
        TOTPRICE,
        VATPRICE,
        VAT,
        DISCOUNT,
        DISPRICE
    FROM INVOICES
    WHERE CUST = '833' AND IVNUM LIKE 'SI%'
    """
    
    cursor = conn.cursor()
    cursor.execute(query)
    
    rows = []
    columns = [column[0] for column in cursor.description]
    
    for row in cursor.fetchall():
        row_dict = dict(zip(columns, row))
        
        ivdate_raw = row_dict.get('IVDATE')
        if ivdate_raw:
            dt = priority_date_to_datetime(ivdate_raw)
            row_dict['ivdate_formatted'] = format_date(dt) if dt else ''
            row_dict['ivdate_year'] = dt.year if dt else None
            row_dict['ivdate_month'] = dt.month if dt else None
        else:
            row_dict['ivdate_formatted'] = ''
            row_dict['ivdate_year'] = None
            row_dict['ivdate_month'] = None
        
        rows.append({
            'iv': str(row_dict.get('IV', '')),
            'ivnum': str(row_dict.get('IVNUM', '')),
            'doc': str(row_dict.get('DOC', '')),
            'ivdate': row_dict['ivdate_formatted'],
            'cust': '833',
            'customerName': 'UPS',
            'currency': row_dict.get('CURRENCY', ''),
            'amount': float(row_dict.get('TOTPRICE', 0) or 0),
            'vatPrice': float(row_dict.get('VATPRICE', 0) or 0),
            'source': 'ups_supplier',
            'part': None,
            'data': row_dict
        })
    
    return rows

def sync_expenses(expenses: List[Dict]) -> int:
    """Send expenses to Replit server"""
    synced = 0
    
    for expense in expenses:
        try:
            response = requests.post(
                UPS_EXPENSES_URL,
                json=expense,
                headers={'Content-Type': 'application/json'},
                timeout=30
            )
            
            if response.status_code == 200:
                synced += 1
                if synced % 100 == 0:
                    print(f"  Synced {synced} expenses...")
            else:
                print(f"[ERROR] Failed to sync expense {expense.get('ivnum')}: {response.status_code}")
        except Exception as e:
            print(f"[ERROR] Exception syncing expense: {e}")
    
    return synced

def main():
    global UPS_EXPENSES_URL
    
    # Parse command line arguments
    parser = argparse.ArgumentParser(description='סנכרון הוצאות UPS מ-Priority ERP')
    parser.add_argument('--url', type=str, help='כתובת שרת Replit (למשל: https://your-app.replit.app)')
    args = parser.parse_args()
    
    # Update URL if specified
    if args.url:
        base_url = args.url.rstrip('/')
        UPS_EXPENSES_URL = f"{base_url}/api/sync/ups-expenses"
        print(f"[CONFIG] Using custom URL: {UPS_EXPENSES_URL}")
    
    print(f"=== UPS Expenses Sync v{VERSION} ===")
    print(f"Target: {UPS_EXPENSES_URL}")
    print()
    
    try:
        conn = get_connection()
        print("[OK] Connected to SQL Server")
    except Exception as e:
        print(f"[ERROR] Failed to connect: {e}")
        return
    
    try:
        print("\n[1/2] Fetching UPS shipping costs (PART = 7720)...")
        shipping_costs = fetch_ups_shipping_costs(conn)
        print(f"      Found {len(shipping_costs)} records")
        
        print("\n[2/2] Fetching UPS supplier invoices (CUST = 833)...")
        supplier_invoices = fetch_ups_supplier_invoices(conn)
        print(f"      Found {len(supplier_invoices)} records")
        
        all_expenses = shipping_costs + supplier_invoices
        print(f"\n[SYNC] Total expenses to sync: {len(all_expenses)}")
        
        if all_expenses:
            synced = sync_expenses(all_expenses)
            print(f"\n[DONE] Successfully synced {synced} expenses")
        else:
            print("\n[WARN] No expenses found to sync")
            
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
    finally:
        conn.close()

if __name__ == '__main__':
    main()
