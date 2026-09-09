import { db } from '../server/db';
import { syncedCustomers } from '../shared/schema';
import { eq } from 'drizzle-orm';

function isEnglishChar(c: string): boolean {
  return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
}

function fixReversedEnglish(text: string): string {
  if (!text) return text;
  
  let result: string[] = [];
  let englishSegment: string[] = [];
  
  for (const char of text) {
    if (isEnglishChar(char) || (englishSegment.length > 0 && char === ' ')) {
      englishSegment.push(char);
    } else {
      if (englishSegment.length > 0) {
        // Reverse the entire English segment (reverses both characters and word order)
        const segment = englishSegment.join('');
        result.push(segment.split('').reverse().join(''));
        englishSegment = [];
      }
      result.push(char);
    }
  }
  
  if (englishSegment.length > 0) {
    const segment = englishSegment.join('');
    result.push(segment.split('').reverse().join(''));
  }
  
  return result.join('');
}

async function fixAllNames() {
  console.log('Fetching customers...');
  const customers = await db.select().from(syncedCustomers);
  console.log(`Found ${customers.length} customers`);
  let fixed = 0;
  
  for (const customer of customers) {
    const oldName = customer.companyName;
    const newName = fixReversedEnglish(oldName);
    
    if (oldName !== newName) {
      const data = customer.data as any;
      data.companyName = newName;
      
      await db.update(syncedCustomers)
        .set({ companyName: newName, data })
        .where(eq(syncedCustomers.id, customer.id));
      
      fixed++;
      if (fixed <= 15) console.log(`Fixed: "${oldName}" -> "${newName}"`);
    }
  }
  
  console.log(`\nTotal fixed: ${fixed} customer names`);
  process.exit(0);
}

fixAllNames().catch(console.error);
