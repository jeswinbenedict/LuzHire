import { describe, expect, it } from 'vitest';
import { HttpError } from '../../api/_lib/http.js';
import { parseServiceAccount } from '../../api/_lib/services.js';

const account = { type: 'service_account', client_email: 'x@p.iam.gserviceaccount.com', private_key: 'k' };

describe('parseServiceAccount', () => {
  it('accepts raw JSON and base64 JSON', () => {
    const raw = JSON.stringify(account);
    expect(parseServiceAccount(`  ${raw}\n`)).toEqual(account);
    expect(parseServiceAccount(Buffer.from(raw).toString('base64'))).toEqual(account);
  });

  it('rejects anything else as a configuration error', () => {
    for (const bad of ['not json', Buffer.from('{"a":1}').toString('base64'), '{oops']) {
      expect(() => parseServiceAccount(bad)).toThrow(HttpError);
    }
  });
});
