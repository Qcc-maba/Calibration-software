import { Customer } from "./mockData";

// This function now calls the real backend API
export async function fetchCustomerData(customerId: string): Promise<Customer> {
  console.log(`Fetching data for customer: ${customerId}`);

  try {
    const response = await fetch(`/api/customers/${customerId}`);
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error fetching customer data:', error);
    throw error;
  }
}

// You can add more data loaders here
export async function fetchCustomerList() {
    // ...
}
