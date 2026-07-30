#!/usr/bin/env python3
"""
סקריפט לבדיקת נתונים בטבלת CustomerMain
הרץ מהמחשב המקומי עם גישה לSQL Server
"""

import pyodbc

SQL_CONFIG = {
    'server': r'51.17.121.203\QCC,1433',
    'database': 'QCCData',
    'username': 'eliran',
    'password': 'En1013#$'
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

def check_customer_main():
    print("=" * 60)
    print("בדיקת טבלת CustomerMain")
    print("=" * 60)
    
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT TOP 5 * 
        FROM [dbo].[CustomerMain] 
        WHERE [Customer Name] LIKE N'%אלביט%'
    """)
    
    columns = [column[0] for column in cursor.description]
    print("\nעמודות בטבלה:")
    for i, col in enumerate(columns):
        print(f"  {i+1}. {col}")
    
    print("\n" + "-" * 60)
    print("נתונים לדוגמה (לקוחות אלביט):")
    print("-" * 60)
    
    rows = cursor.fetchall()
    if not rows:
        print("לא נמצאו לקוחות עם שם 'אלביט'")
    else:
        for row in rows:
            print("\n--- לקוח ---")
            for i, col in enumerate(columns):
                value = row[i]
                if value:
                    print(f"  {col}: {value}")
    
    cursor.close()
    conn.close()

def check_contact_main():
    print("\n" + "=" * 60)
    print("בדיקת טבלת ContactMain")
    print("=" * 60)
    
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT TOP 5 
            [Name], [Phone], [Mobile], [Email], [קשור ללקוח], [שם לקוח], [Main_Contact]
        FROM [dbo].[ContactMain] 
        WHERE [שם לקוח] LIKE N'%אלביט%'
    """)
    
    rows = cursor.fetchall()
    if not rows:
        print("לא נמצאו אנשי קשר עבור אלביט")
    else:
        for row in rows:
            print(f"\n  שם: {row[0]}")
            print(f"  טלפון: {row[1]}")
            print(f"  נייד: {row[2]}")
            print(f"  מייל: {row[3]}")
            print(f"  מספר לקוח: {row[4]}")
            print(f"  שם לקוח: {row[5]}")
            print(f"  איש קשר ראשי: {row[6]}")
    
    cursor.close()
    conn.close()

def check_orders():
    print("\n" + "=" * 60)
    print("בדיקת טבלת OrdersFULL")
    print("=" * 60)
    
    conn = get_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT TOP 5 
            [Order Number], [Customer Number], [Customer Name], 
            [Price after discount], [Discount Percentage], [CurrentDate]
        FROM [dbo].[OrdersFULL] 
        WHERE [Customer Name] LIKE N'%אלביט%'
        ORDER BY [CurrentDate] DESC
    """)
    
    rows = cursor.fetchall()
    if not rows:
        print("לא נמצאו הזמנות עבור אלביט")
    else:
        for row in rows:
            print(f"\n  מס' הזמנה: {row[0]}")
            print(f"  מס' לקוח: {row[1]}")
            print(f"  שם לקוח: {row[2]}")
            print(f"  מחיר: {row[3]}")
            print(f"  הנחה %: {row[4]}")
            print(f"  תאריך: {row[5]}")
    
    cursor.close()
    conn.close()

if __name__ == "__main__":
    try:
        check_customer_main()
        check_contact_main()
        check_orders()
        print("\n" + "=" * 60)
        print("הבדיקה הסתיימה!")
        print("=" * 60)
    except Exception as e:
        print(f"שגיאה: {e}")
