#!/usr/bin/env python3
"""
סקריפט לגילוי סכימת בסיס הנתונים - שולח את המידע לשרת Replit

גרסה: 2.0

שימוש:
    python discover-schema.py
"""

import pyodbc
import requests
import json
from datetime import datetime

# ========== טעינת הגדרות ==========
try:
    from config import SQL_CONFIG, REPLIT_API_URL
    SCHEMA_API_URL = REPLIT_API_URL.replace('/api/sync/customer-data', '/api/schema/upload')
    print(f"[CONFIG] נטען מ-config.py: {SQL_CONFIG['server']}/{SQL_CONFIG['database']}")
except ImportError:
    import os
    SQL_CONFIG = {
        'server': os.environ.get('SQL_SERVER', r'maba-priority\pri'),
        'database': os.environ.get('SQL_DATABASE', 'amaba'),
        'username': os.environ.get('SQL_UID', ''),
        'password': os.environ.get('SQL_PWD', '')
    }
    SCHEMA_API_URL = os.environ.get('REPLIT_API_URL', 'https://232ca506-7be9-4e7f-a436-7bb478f77860-00-1bf7ltq07a1po.riker.replit.dev') + '/api/schema/upload'
    if not SQL_CONFIG['username']:
        print("[ERROR] חסר קובץ config.py או environment variables")
        print("       העתק config.example.py ל-config.py ומלא את הפרטים")
        exit(1)

def get_connection():
    connection_string = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE={SQL_CONFIG['database']};"
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']}"
    )
    return pyodbc.connect(connection_string)

def discover_schema():
    print("=== מיפוי סכימת בסיס הנתונים ===\n")
    
    conn = get_connection()
    cursor = conn.cursor()
    
    # שליפת כל הטבלאות
    cursor.execute("""
        SELECT TABLE_SCHEMA, TABLE_NAME 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_TYPE = 'BASE TABLE'
        ORDER BY TABLE_SCHEMA, TABLE_NAME
    """)
    
    tables_list = cursor.fetchall()
    print(f"נמצאו {len(tables_list)} טבלאות\n")
    
    schema_data = {
        'server': SQL_CONFIG['server'],
        'database': SQL_CONFIG['database'],
        'timestamp': datetime.now().isoformat(),
        'tables': []
    }
    
    for schema, table in tables_list:
        print(f"סורק טבלה: [{schema}].[{table}]...")
        
        # שליפת עמודות לכל טבלה
        cursor.execute("""
            SELECT 
                COLUMN_NAME,
                DATA_TYPE,
                CHARACTER_MAXIMUM_LENGTH,
                IS_NULLABLE
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
            ORDER BY ORDINAL_POSITION
        """, schema, table)
        
        columns = []
        for col in cursor.fetchall():
            columns.append({
                'name': col[0],
                'type': col[1],
                'maxLength': col[2] if col[2] and col[2] > 0 else None,
                'nullable': col[3] == 'YES'
            })
        
        # שליפת מספר שורות (אם אפשר)
        try:
            cursor.execute(f"SELECT COUNT(*) FROM [{schema}].[{table}]")
            row_count = cursor.fetchone()[0]
        except:
            row_count = None
        
        # שליפת דוגמת נתונים (5 שורות ראשונות)
        sample_data = []
        try:
            cursor.execute(f"SELECT TOP 3 * FROM [{schema}].[{table}]")
            sample_rows = cursor.fetchall()
            col_names = [col[0] for col in cursor.description]
            for row in sample_rows:
                row_dict = {}
                for i, val in enumerate(row):
                    if val is not None:
                        # Convert to string for JSON serialization
                        row_dict[col_names[i]] = str(val)[:100]  # Limit value length
                sample_data.append(row_dict)
        except Exception as e:
            sample_data = [{'error': str(e)[:50]}]
        
        schema_data['tables'].append({
            'schema': schema,
            'name': table,
            'columns': columns,
            'rowCount': row_count,
            'sampleData': sample_data
        })
    
    cursor.close()
    conn.close()
    
    return schema_data

def send_to_replit(schema_data):
    """שליחת הסכימה לשרת Replit"""
    print(f"\nשולח נתונים ל-Replit...")
    print(f"URL: {SCHEMA_API_URL}")
    
    try:
        response = requests.post(
            SCHEMA_API_URL,
            json=schema_data,
            headers={'Content-Type': 'application/json'},
            timeout=60
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"\n✓ הסכימה נשלחה בהצלחה!")
            print(f"  טבלאות שנשלחו: {result.get('tablesCount', 'N/A')}")
            return True
        else:
            print(f"\n✗ שגיאה בשליחה: {response.status_code}")
            print(f"  {response.text[:200]}")
            return False
            
    except Exception as e:
        print(f"\n✗ שגיאה בחיבור לשרת: {str(e)}")
        return False

def main():
    print("=" * 60)
    print("  גילוי סכימת בסיס נתונים - גרסה 2.0")
    print("=" * 60)
    print(f"שרת: {SQL_CONFIG['server']}")
    print(f"בסיס נתונים: {SQL_CONFIG['database']}")
    print("=" * 60 + "\n")
    
    try:
        schema_data = discover_schema()
        
        print(f"\n{'=' * 60}")
        print(f"סיכום: {len(schema_data['tables'])} טבלאות נמצאו")
        print(f"{'=' * 60}")
        
        for table in schema_data['tables']:
            rows = f"{table['rowCount']:,}" if table['rowCount'] is not None else "?"
            print(f"  [{table['schema']}].[{table['name']}] - {len(table['columns'])} עמודות, {rows} שורות")
        
        # שליחה לשרת
        send_to_replit(schema_data)
        
        # שמירה מקומית גם
        with open('schema_output.json', 'w', encoding='utf-8') as f:
            json.dump(schema_data, f, ensure_ascii=False, indent=2)
        print(f"\nהסכימה נשמרה גם ב-schema_output.json")
        
    except Exception as e:
        print(f"\n✗ שגיאה: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
