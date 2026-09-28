export const API = {
  identity: process.env.NEXT_PUBLIC_IDENTITY_URL ?? 'http://localhost:8081',
  customer: process.env.NEXT_PUBLIC_CUSTOMER_URL ?? 'http://localhost:8082',
  campus: process.env.NEXT_PUBLIC_CAMPUS_URL ?? 'http://localhost:8083',
  catalog: process.env.NEXT_PUBLIC_CATALOG_URL ?? 'http://localhost:8084',
  order: process.env.NEXT_PUBLIC_ORDER_URL ?? 'http://localhost:8085',
  payment: process.env.NEXT_PUBLIC_PAYMENT_URL ?? 'http://localhost:8086',
  delivery: process.env.NEXT_PUBLIC_DELIVERY_URL ?? 'http://localhost:8087',
  operations: process.env.NEXT_PUBLIC_OPERATIONS_URL ?? 'http://localhost:8089',
  financial: process.env.NEXT_PUBLIC_FINANCIAL_URL ?? 'http://localhost:8090',
};
