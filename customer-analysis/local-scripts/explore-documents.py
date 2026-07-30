#!/usr/bin/env python3
"""
סקריפט לבדיקת מבנה טבלת DOCUMENTS
"""

import pyodbc

try:
    from config import SQL_CONFIG
except ImportError:
    import os
    SQL_CONFIG = {
        'server': os.environ.get('SQL_SERVER', r'maba-priority\pri'),
        'database': os.environ.get('SQL_DATABASE', 'amaba'),
        'username': os.environ.get('SQL_UID', ''),
        'password': os.environ.get('SQL_PWD', '')
    }

def get_connection():
    connection_string = (
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={SQL_CONFIG['server']};"
        f"DATABASE={SQL_CONFIG['database']};"
        f"UID={SQL_CONFIG['username']};"
        f"PWD={SQL_CONFIG['password']}"
    )
    return pyodbc.connect(connection_string)

def explore_table(table_name):
    conn = get_connection()
    cursor = conn.cursor()
    
    print(f"\n=== כל העמודות בטבלת {table_name} ===\n")
    
    # Get all column info
    cursor.execute(f"""
        SELECT COLUMN_NAME, DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = '{table_name}'
        ORDER BY ORDINAL_POSITION
    """)
    
    columns = cursor.fetchall()
    print(f"סה\"כ {len(columns)} עמודות:\n")
    
    for i, col in enumerate(columns):
        print(f"  {i+1:3}. {col.COLUMN_NAME:25} ({col.DATA_TYPE})")
    
    # Find price-related columns
    print(f"\n=== עמודות הקשורות למחיר/סכום ===\n")
    price_keywords = ['PRICE', 'COST', 'VAT', 'TOTAL', 'SUM', 'AMOUNT', 'NET', 'GROSS', 'TOT']
    for col in columns:
        if any(kw in col.COLUMN_NAME.upper() for kw in price_keywords):
            print(f"  {col.COLUMN_NAME} ({col.DATA_TYPE})")
    
    # Find date columns
    print(f"\n=== עמודות תאריך ===\n")
    date_keywords = ['DATE', 'TIME', 'DAY', 'MONTH', 'YEAR']
    for col in columns:
        if any(kw in col.COLUMN_NAME.upper() for kw in date_keywords):
            print(f"  {col.COLUMN_NAME} ({col.DATA_TYPE})")
    
    # Find customer columns
    print(f"\n=== עמודות לקוח ===\n")
    cust_keywords = ['CUST', 'CLIENT', 'CUSTOMER']
    for col in columns:
        if any(kw in col.COLUMN_NAME.upper() for kw in cust_keywords):
            print(f"  {col.COLUMN_NAME} ({col.DATA_TYPE})")
    
    # Get sample with price columns
    print(f"\n=== דוגמת נתונים ===\n")
    try:
        # Try to find price columns
        price_cols = [col.COLUMN_NAME for col in columns if 'PRICE' in col.COLUMN_NAME.upper() or 'VAT' in col.COLUMN_NAME.upper() or 'TOT' in col.COLUMN_NAME.upper()][:5]
        doc_col = next((col.COLUMN_NAME for col in columns if 'DOC' in col.COLUMN_NAME.upper() or 'NUM' in col.COLUMN_NAME.upper()), None)
        cust_col = next((col.COLUMN_NAME for col in columns if 'CUST' in col.COLUMN_NAME.upper()), None)
        
        select_cols = []
        if doc_col: select_cols.append(doc_col)
        if cust_col: select_cols.append(cust_col)
        select_cols.extend(price_cols)
        
        if select_cols:
            query = f"SELECT TOP 5 {', '.join(select_cols)} FROM {table_name}"
            print(f"Query: {query}\n")
            cursor.execute(query)
            
            for row in cursor.fetchall():
                print(f"  {row}")
    except Exception as e:
        print(f"  שגיאה: {e}")
    
    cursor.close()
    conn.close()

if __name__ == "__main__":
    explore_table("DOCUMENTS")
