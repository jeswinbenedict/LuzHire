// Company career boards imported daily. Each is the company's own public
// job board on an applicant-tracking system (Greenhouse, Lever, Ashby), whose
// public APIs exist so the jobs can be shown elsewhere. Only roles located in
// India are imported. Boards were picked for having India roles (checked
// 2026-10-23); huge boards with only a handful of India roles are left out to
// keep the daily run fast.

export interface Board {
  /** The board token in the ATS URL, e.g. boards.greenhouse.io/<token>. */
  token: string;
  /** Company name shown on cards (the APIs don't all return one). */
  name: string;
}

export const GREENHOUSE_BOARDS: Board[] = [
  { token: 'databricks', name: 'Databricks' },
  { token: 'mongodb', name: 'MongoDB' },
  { token: 'okta', name: 'Okta' },
  { token: 'zscaler', name: 'Zscaler' },
  { token: 'purestorage', name: 'Pure Storage' },
  { token: 'highradius', name: 'HighRadius' },
  { token: 'stripe', name: 'Stripe' },
  { token: 'inmobi', name: 'InMobi' },
  { token: 'sigmoid', name: 'Sigmoid' },
  { token: 'rubrik', name: 'Rubrik' },
  { token: 'celonis', name: 'Celonis' },
  { token: 'gitlab', name: 'GitLab' },
  { token: 'razorpaysoftwareprivatelimited', name: 'Razorpay' },
  { token: 'netskope', name: 'Netskope' },
  { token: 'toast', name: 'Toast' },
  { token: 'hackerrank', name: 'HackerRank' },
  { token: 'elastic', name: 'Elastic' },
  { token: 'druva', name: 'Druva' },
  { token: 'agoda', name: 'Agoda' },
  { token: 'groww', name: 'Groww' },
  { token: 'twilio', name: 'Twilio' },
  { token: 'commvault', name: 'Commvault' },
  { token: 'datadog', name: 'Datadog' },
  { token: 'newrelic', name: 'New Relic' },
  { token: 'sumologic', name: 'Sumo Logic' },
];

export const LEVER_BOARDS: Board[] = [
  { token: 'paytm', name: 'Paytm' },
  { token: 'meesho', name: 'Meesho' },
  { token: 'zeta', name: 'Zeta' },
  { token: 'fampay', name: 'FamPay' },
  { token: 'acceldata', name: 'Acceldata' },
  { token: 'nium', name: 'Nium' },
  { token: 'cred', name: 'CRED' },
  { token: 'outreach', name: 'Outreach' },
];

export const ASHBY_BOARDS: Board[] = [
  { token: 'sarvam', name: 'Sarvam AI' },
  { token: 'plane', name: 'Plane' },
  { token: 'supabase', name: 'Supabase' },
  { token: 'atlan', name: 'Atlan' },
  { token: 'composio', name: 'Composio' },
  { token: 'smallest', name: 'Smallest.ai' },
];

const INDIA =
  /\bindia\b|bengaluru|bangalore|mumbai|pune|hyderabad|chennai|gurgaon|gurugram|noida|new delhi|\bdelhi\b|kolkata|ahmedabad|jaipur|kochi|coimbatore|thiruvananthapuram|chandigarh|indore|vadodara|visakhapatnam|vijayawada|mysuru|mysore|nagpur|lucknow|bhubaneswar/i;

/** True when a free-text location is in India. */
export function inIndia(location: string): boolean {
  return INDIA.test(location);
}
