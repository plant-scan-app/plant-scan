/**
 * Per-device quota, held in Workers KV.
 *
 * One record per device, reset when the UTC day rolls over. KV is eventually
 * consistent, so two scans fired in the same instant can both read the same
 * count and slip through. At this scale that costs you one extra Gemini call
 * occasionally, which is cheaper than the complexity of fixing it. If the free
 * tier ever gets abused in volume, move this to a Durable Object — the
 * interface below stays the same.
 */

export interface Quota {
  /** Base free scans per day. */
  limit: number;
  /** Scans left today, including any earned by watching an ad. */
  remaining: number;
  /** True when the user can still earn extra scans from a rewarded ad today. */
  adCreditAvailable: boolean;
  /** True while a subscription is active — no limit, no ads. */
  entitled: boolean;
  /** Subscription expiry, epoch milliseconds, when entitled. */
  entitledUntil?: number;
}

interface Record {
  day: string;
  scans: number;
  adGrants: number;
  entitledUntil?: number;
  productId?: string;
  purchaseToken?: string;
}

export const FREE_SCANS_PER_DAY = 3;
export const SCANS_PER_AD = 2;
export const AD_GRANTS_PER_DAY = 1;

/** Ninety days, so a lapsed device eventually falls out of KV. */
const TTL_SECONDS = 90 * 24 * 60 * 60;

const today = (): string => new Date().toISOString().slice(0, 10);

const empty = (): Record => ({ day: today(), scans: 0, adGrants: 0 });

export class QuotaStore {
  constructor(private readonly kv: KVNamespace) {}

  private key(deviceId: string): string {
    return `device:${deviceId}`;
  }

  private async read(deviceId: string): Promise<Record> {
    const raw = await this.kv.get<Record>(this.key(deviceId), 'json');
    if (!raw) return empty();

    // Roll the day over on read, keeping the entitlement.
    if (raw.day !== today()) {
      return {
        ...raw,
        day: today(),
        scans: 0,
        adGrants: 0,
      };
    }
    return raw;
  }

  private async write(deviceId: string, record: Record): Promise<void> {
    await this.kv.put(this.key(deviceId), JSON.stringify(record), {
      expirationTtl: TTL_SECONDS,
    });
  }

  private view(record: Record): Quota {
    const entitled = (record.entitledUntil ?? 0) > Date.now();
    const allowance =
      FREE_SCANS_PER_DAY + record.adGrants * SCANS_PER_AD;

    return {
      limit: FREE_SCANS_PER_DAY,
      remaining: entitled ? Number.MAX_SAFE_INTEGER : Math.max(0, allowance - record.scans),
      adCreditAvailable: !entitled && record.adGrants < AD_GRANTS_PER_DAY,
      entitled,
      entitledUntil: entitled ? record.entitledUntil : undefined,
    };
  }

  async get(deviceId: string): Promise<Quota> {
    return this.view(await this.read(deviceId));
  }

  /**
   * Reserves one scan. Returns null when the device has none left, in which
   * case the caller must not spend a Gemini call.
   */
  async spend(deviceId: string): Promise<Quota | null> {
    const record = await this.read(deviceId);
    const quota = this.view(record);

    if (!quota.entitled && quota.remaining <= 0) return null;

    // Subscribers are still counted, purely so you can see usage per device.
    record.scans += 1;
    await this.write(deviceId, record);
    return this.view(record);
  }

  /** Puts a scan back when the upstream call failed. */
  async refund(deviceId: string): Promise<void> {
    const record = await this.read(deviceId);
    record.scans = Math.max(0, record.scans - 1);
    await this.write(deviceId, record);
  }

  /** Grants the rewarded-ad bonus, once per day. */
  async grantAdCredit(deviceId: string): Promise<Quota | null> {
    const record = await this.read(deviceId);
    if (record.adGrants >= AD_GRANTS_PER_DAY) return null;

    record.adGrants += 1;
    await this.write(deviceId, record);
    return this.view(record);
  }

  async setEntitlement(
    deviceId: string,
    entitlement: {
      entitledUntil: number;
      productId: string;
      purchaseToken: string;
    },
  ): Promise<Quota> {
    const record = await this.read(deviceId);
    const updated: Record = { ...record, ...entitlement };
    await this.write(deviceId, updated);
    return this.view(updated);
  }

  async storedPurchase(
    deviceId: string,
  ): Promise<{ productId: string; purchaseToken: string } | null> {
    const record = await this.read(deviceId);
    if (!record.productId || !record.purchaseToken) return null;
    return { productId: record.productId, purchaseToken: record.purchaseToken };
  }
}
