import assert from "node:assert/strict";
import test from "node:test";
import { ShortLivedRequestCache, makeImageRequestKey } from "./shortLivedRequestCache.js";

test("short-lived cache coalesces concurrent requests and reuses the successful result", async () => {
  const cache = new ShortLivedRequestCache<string>(60_000);
  let calls = 0;
  let release: (() => void) | undefined;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });

  const operation = async () => {
    calls += 1;
    await gate;
    return "recognized";
  };

  const first = cache.run("same-image", operation);
  const second = cache.run("same-image", operation);
  release?.();

  assert.deepEqual(await first, { value: "recognized", cacheHit: false });
  assert.deepEqual(await second, { value: "recognized", cacheHit: true });
  assert.equal(calls, 1);

  assert.deepEqual(await cache.run("same-image", operation), {
    value: "recognized",
    cacheHit: true
  });
  assert.equal(calls, 1);
});

test("short-lived cache does not retain failed operations", async () => {
  const cache = new ShortLivedRequestCache<string>(60_000);
  let calls = 0;

  await assert.rejects(
    cache.run("retryable", async () => {
      calls += 1;
      throw new Error("temporary failure");
    }),
    /temporary failure/
  );

  const retry = await cache.run("retryable", async () => {
    calls += 1;
    return "ok";
  });
  assert.deepEqual(retry, { value: "ok", cacheHit: false });
  assert.equal(calls, 2);
});

test("image request keys separate users and image content without storing the image", () => {
  const first = makeImageRequestKey(["user-a", "bp_recognition"], "image/jpeg", "abc");
  const same = makeImageRequestKey(["user-a", "bp_recognition"], "image/jpeg", "abc");
  const otherUser = makeImageRequestKey(["user-b", "bp_recognition"], "image/jpeg", "abc");
  const otherImage = makeImageRequestKey(["user-a", "bp_recognition"], "image/jpeg", "abd");

  assert.equal(first, same);
  assert.notEqual(first, otherUser);
  assert.notEqual(first, otherImage);
  assert.match(first, /^[a-f0-9]{64}$/);
});
