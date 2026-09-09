"""
Regenerates server/priority-queries.ts from the two sync scripts, so the live dashboard
and the sync scripts run byte-identical SQL. Run after editing either Python query:

    python scripts/gen-priority-queries.py
"""
import re, io, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def extract(filename):
    src = io.open(os.path.join(ROOT, filename), encoding='utf-8').read()
    q = re.search(r'^QUERY = """(.*?)"""', src, re.S | re.M).group(1)
    q = re.sub(r'\bORDER\s+BY\b.*$', '', q, flags=re.I | re.S)   # illegal inside a subquery
    q = q.replace('SELECT TOP __TOP__', 'SELECT')                # the caller applies the cap

    # Only the two date placeholders become named params. A bare '?' replace would also hit
    # the Hebrew column alias [מקט סט?] in the financial query.
    q, n1 = re.subn(r">=\s*\?", ">= @dateFrom", q)
    q, n2 = re.subn(r"<=\s*\?", "<= @dateTo",  q)
    if (n1, n2) != (1, 1):
        sys.exit(f"{filename}: expected exactly one >= ? and one <= ?, found {n1} and {n2}")
    if '`' in q or '${' in q:
        sys.exit(f"{filename}: SQL contains a backtick or ${{, which breaks String.raw")
    return q.strip()

op, fin = extract('sync-operational-query.py'), extract('sync-financial-query.py')

out = f'''// GENERATED FILE — do not edit by hand.
// Extracted verbatim from sync-operational-query.py / sync-financial-query.py so the live
// dashboard and the sync scripts cannot drift apart. ORDER BY is stripped (these are wrapped
// as subqueries) and the TOP cap is applied by the caller.
// Regenerate: python scripts/gen-priority-queries.py

/** תעודות משלוח (type D) המקושרות לקריאות שירות (type Q) */
export const OPERATIONAL_SQL = String.raw`
{op}
`;

/** חשבוניות ופירוט שורות */
export const FINANCIAL_SQL = String.raw`
{fin}
`;
'''
path = os.path.join(ROOT, 'server', 'priority-queries.ts')
io.open(path, 'w', encoding='utf-8', newline='\n').write(out)
print(f"wrote {path}")
print(f"  operational: {len(op):,} chars   financial: {len(fin):,} chars")
