// Company career boards imported daily. Each is the company's own public
// job board on an applicant-tracking system (Greenhouse, Lever, Ashby), whose
// public APIs exist so the jobs can be shown elsewhere. Only roles located in
// India are imported. Boards were picked for having India roles (checked
// 2026-10-23); huge boards with only a handful of India roles are left out to
// keep the daily run fast.

import { faviconOf } from './logos.js';

export interface Board {
  /** The board token in the ATS URL, e.g. boards.greenhouse.io/<token>. */
  token: string;
  /** Company name shown on cards (the APIs don't all return one). */
  name: string;
  /** The company's website, for its logo (the APIs return none). */
  domain: string;
}

/**
 * The company's logo: its site icon at up to 128 px from Google's favicon
 * service, shown through /api/img (t1.gstatic.com is on its allowlist).
 */
export function logoOf(board: Board): string {
  return faviconOf(board.domain);
}

export const GREENHOUSE_BOARDS: Board[] = [
  { token: 'databricks', name: 'Databricks', domain: 'databricks.com' },
  { token: 'mongodb', name: 'MongoDB', domain: 'mongodb.com' },
  { token: 'okta', name: 'Okta', domain: 'okta.com' },
  { token: 'zscaler', name: 'Zscaler', domain: 'zscaler.com' },
  { token: 'purestorage', name: 'Pure Storage', domain: 'purestorage.com' },
  { token: 'highradius', name: 'HighRadius', domain: 'highradius.com' },
  { token: 'stripe', name: 'Stripe', domain: 'stripe.com' },
  { token: 'inmobi', name: 'InMobi', domain: 'inmobi.com' },
  { token: 'sigmoid', name: 'Sigmoid', domain: 'sigmoid.com' },
  { token: 'rubrik', name: 'Rubrik', domain: 'rubrik.com' },
  { token: 'celonis', name: 'Celonis', domain: 'celonis.com' },
  { token: 'gitlab', name: 'GitLab', domain: 'gitlab.com' },
  { token: 'razorpaysoftwareprivatelimited', name: 'Razorpay', domain: 'razorpay.com' },
  { token: 'netskope', name: 'Netskope', domain: 'netskope.com' },
  { token: 'toast', name: 'Toast', domain: 'toasttab.com' },
  { token: 'hackerrank', name: 'HackerRank', domain: 'hackerrank.com' },
  { token: 'elastic', name: 'Elastic', domain: 'elastic.co' },
  { token: 'druva', name: 'Druva', domain: 'druva.com' },
  { token: 'agoda', name: 'Agoda', domain: 'agoda.com' },
  { token: 'groww', name: 'Groww', domain: 'groww.in' },
  { token: 'twilio', name: 'Twilio', domain: 'twilio.com' },
  { token: 'commvault', name: 'Commvault', domain: 'commvault.com' },
  { token: 'datadog', name: 'Datadog', domain: 'datadoghq.com' },
  { token: 'newrelic', name: 'New Relic', domain: 'newrelic.com' },
  { token: 'sumologic', name: 'Sumo Logic', domain: 'sumologic.com' },
];

export const LEVER_BOARDS: Board[] = [
  { token: 'paytm', name: 'Paytm', domain: 'paytm.com' },
  { token: 'meesho', name: 'Meesho', domain: 'meesho.com' },
  { token: 'zeta', name: 'Zeta', domain: 'zeta.tech' },
  { token: 'fampay', name: 'FamPay', domain: 'fampay.in' },
  { token: 'acceldata', name: 'Acceldata', domain: 'acceldata.io' },
  { token: 'nium', name: 'Nium', domain: 'nium.com' },
  { token: 'cred', name: 'CRED', domain: 'cred.club' },
  { token: 'outreach', name: 'Outreach', domain: 'outreach.io' },
];

export const ASHBY_BOARDS: Board[] = [
  { token: 'sarvam', name: 'Sarvam AI', domain: 'sarvam.ai' },
  { token: 'plane', name: 'Plane', domain: 'plane.so' },
  { token: 'supabase', name: 'Supabase', domain: 'supabase.com' },
  { token: 'atlan', name: 'Atlan', domain: 'atlan.com' },
  { token: 'composio', name: 'Composio', domain: 'composio.dev' },
  { token: 'smallest', name: 'Smallest.ai', domain: 'smallest.ai' },
];

const INDIA =
  /\bindia\b|bengaluru|bangalore|mumbai|pune|hyderabad|chennai|gurgaon|gurugram|noida|new delhi|\bdelhi\b|kolkata|ahmedabad|jaipur|kochi|coimbatore|thiruvananthapuram|chandigarh|indore|vadodara|visakhapatnam|vijayawada|mysuru|mysore|nagpur|lucknow|bhubaneswar/i;

/** True when a free-text location is in India. */
export function inIndia(location: string): boolean {
  return INDIA.test(location);
}
