import { createHash } from "node:crypto";

interface CacheEntry<Value> {
  expiresAt: number;
  promise: Promise<Value>;
}

export interface CachedResult<Value> {
  value: Value;
  cacheHit: boolean;
}

export class ShortLivedRequestCache<Value> {
  private readonly entries = new Map<string, CacheEntry<Value>>();

  constructor(
    private readonly ttlMilliseconds: number,
    private readonly maximumEntries = 500
  ) {}

  async run(key: string, operation: () => Promise<Value>): Promise<CachedResult<Value>> {
    const now = Date.now();
    this.removeExpired(now);

    const existing = this.entries.get(key);
    if (existing && existing.expiresAt > now) {
      return { value: await existing.promise, cacheHit: true };
    }

    const promise = operation();
    const entry = { expiresAt: now + this.ttlMilliseconds, promise };
    this.entries.set(key, entry);
    this.trimToMaximumSize();

    try {
      return { value: await promise, cacheHit: false };
    } catch (error) {
      if (this.entries.get(key) === entry) {
        this.entries.delete(key);
      }
      throw error;
    }
  }

  private removeExpired(now: number): void {
    for (const [key, entry] of this.entries) {
      if (entry.expiresAt <= now) this.entries.delete(key);
    }
  }

  private trimToMaximumSize(): void {
    while (this.entries.size > this.maximumEntries) {
      const oldestKey = this.entries.keys().next().value as string | undefined;
      if (!oldestKey) return;
      this.entries.delete(oldestKey);
    }
  }
}

export function makeImageRequestKey(parts: string[], mimeType: string, base64: string): string {
  const hash = createHash("sha256");
  for (const part of parts) {
    hash.update(part);
    hash.update("\0");
  }
  hash.update(mimeType);
  hash.update("\0");
  hash.update(base64);
  return hash.digest("hex");
}
