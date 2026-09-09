#!/usr/bin/env python3
"""
סקריפט לחקירת טבלאות מכשירים וכיולים ב-Priority ERP
טבלאות: SERNUMBERS, SERVCALLS, PART, Mba_document
"""

import pyodbc
from datetime import datetime, timedelta

try:
    from config import SQL_CONFIG
    print(f"[CONFIG] Server: {SQL_CONFIG['server']}/{SQL_CONFIG['database']}")
except ImportError:
    import os
    SQL_CONFIG = {
        'server': os.environ.get('SQL_SERVER', r'maba-priority\pri'),
        'database': os.environ.get('SQL_DATABASE', 'amaba'),
        'username': os.environ.get('SQL_UID', ''),
        'password': os.environ.get('SQL_PWD', '')
    }

PRIORITY_EPOCH = datetime(1988, 1, 1)

def priority_date_to_datetime(priority_date):
    if not priority_date or priority_date <= 0:
        return None
    try:
        return PRIORITY_EPOCH + timedelta(minutes=priority_date)
    except:
        return None

def get_connection():
    connection_string = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE={SQL_CONFIG['database']};"
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']}"
    )
    return pyodbc.connect(connection_string)

def explore_table_schema(cursor, table_name):
    print(f"\n{'='*60}")
    print(f"מבנה טבלת {table_name}...")
    print('='*60)
    
    try:
        cursor.execute(f"""
            SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = '{table_name}'
            ORDER BY ORDINAL_POSITION
        """)
        columns = cursor.fetchall()
        for col in columns:
            length = f", {col.CHARACTER_MAXIMUM_LENGTH}" if col.CHARACTER_MAXIMUM_LENGTH else ""
            print(f"  {col.COLUMN_NAME}: {col.DATA_TYPE}{length}")
        return [c.COLUMN_NAME for c in columns]
    except Exception as e:
        print(f"  שגיאה: {e}")
        return []

def explore_sample_data(cursor, table_name, limit=5):
    print(f"\n{limit} דוגמאות מ-{table_name}...")
    print('-'*60)
    
    try:
        cursor.execute(f"SELECT TOP {limit} * FROM {table_name}")
        rows = cursor.fetchall()
        columns = [desc[0] for desc in cursor.description]
        
        for row in rows:
            row_dict = {}
            for i, col in enumerate(columns[:15]):  # First 15 columns only
                val = row[i]
                if val is not None and str(val).strip():
                    row_dict[col] = val
            print(f"  {row_dict}")
    except Exception as e:
        print(f"  שגיאה: {e}")

def count_devices_by_customer(cursor):
    print(f"\n{'='*60}")
    print("ספירת מכשירים לפי לקוח (TOP 10)...")
    print('='*60)
    
    try:
        cursor.execute("""
            SELECT TOP 10 
                sn.CUST, 
                c.CUSTDES,
                COUNT(*) as device_count,
                SUM(CASE WHEN sn.NEXTMAINTDATE > 0 AND sn.NEXTMAINTDATE < ? THEN 1 ELSE 0 END) as expired_count
            FROM SERNUMBERS sn
            LEFT JOIN CUSTOMERS c ON sn.CUST = c.CUST
            WHERE sn.CUST > 0 AND sn.SERNUM IS NOT NULL AND sn.SERNUM != ''
            GROUP BY sn.CUST, c.CUSTDES
            ORDER BY device_count DESC
        """, int((datetime.now() - PRIORITY_EPOCH).total_seconds() / 60))
        
        for row in cursor.fetchall():
            print(f"  לקוח {row.CUST} ({row.CUSTDES}): {row.device_count} מכשירים, {row.expired_count} פגי תוקף")
    except Exception as e:
        print(f"  שגיאה: {e}")

def explore_servcalls_for_device(cursor, sample_sernum):
    print(f"\n{'='*60}")
    print(f"קריאות שירות למכשיר {sample_sernum}...")
    print('='*60)
    
    try:
        cursor.execute("""
            SELECT TOP 5 *
            FROM SERVCALLS
            WHERE SERNUM = ?
        """, sample_sernum)
        rows = cursor.fetchall()
        if rows:
            columns = [desc[0] for desc in cursor.description]
            for row in rows:
                row_dict = {}
                for i, col in enumerate(columns[:15]):
                    val = row[i]
                    if val is not None and str(val).strip():
                        row_dict[col] = val
                print(f"  {row_dict}")
        else:
            print("  אין קריאות שירות למכשיר זה")
    except Exception as e:
        print(f"  שגיאה: {e}")

def count_total_expired_devices(cursor):
    print(f"\n{'='*60}")
    print("סיכום כללי - מכשירים פגי תוקף במערכת...")
    print('='*60)
    
    today_priority = int((datetime.now() - PRIORITY_EPOCH).total_seconds() / 60)
    
    try:
        cursor.execute("""
            SELECT 
                COUNT(*) as total_devices,
                SUM(CASE WHEN NEXTMAINTDATE > 0 THEN 1 ELSE 0 END) as with_next_date,
                SUM(CASE WHEN NEXTMAINTDATE > 0 AND NEXTMAINTDATE < ? THEN 1 ELSE 0 END) as expired,
                SUM(CASE WHEN NEXTMAINTDATE > 0 AND NEXTMAINTDATE >= ? THEN 1 ELSE 0 END) as active
            FROM SERNUMBERS
            WHERE SERNUM IS NOT NULL AND SERNUM != ''
        """, today_priority, today_priority)
        
        row = cursor.fetchone()
        print(f"  סה\"כ מכשירים: {row.total_devices}")
        print(f"  עם תאריך כיול הבא: {row.with_next_date}")
        print(f"  פגי תוקף (תאריך עבר): {row.expired}")
        print(f"  פעילים (תאריך עתידי): {row.active}")
    except Exception as e:
        print(f"  שגיאה: {e}")

def main():
    print("מתחיל חקירת טבלאות מכשירים...")
    
    conn = get_connection()
    cursor = conn.cursor()
    
    # Explore table schemas
    for table in ['SERNUMBERS', 'SERVCALLS', 'PART', 'Mba_document']:
        explore_table_schema(cursor, table)
        explore_sample_data(cursor, table, 3)
    
    # Count devices by customer
    count_devices_by_customer(cursor)
    
    # Total expired devices
    count_total_expired_devices(cursor)
    
    # Get a sample device for SERVCALLS exploration
    try:
        cursor.execute("SELECT TOP 1 SERNUM FROM SERNUMBERS WHERE SERNUM IS NOT NULL AND SERNUM != ''")
        sample = cursor.fetchone()
        if sample:
            explore_servcalls_for_device(cursor, sample.SERNUM)
    except:
        pass
    
    cursor.close()
    conn.close()
    
    print("\n[OK] Done")

if __name__ == "__main__":
    main()
