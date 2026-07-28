import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const projectRoot = new URL("../", import.meta.url);

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the Danjjan policy entry point", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<html[^>]*lang="ko"/i);
  assert.match(html, /<title>단짠 정책 및 지원<\/title>/i);
  assert.match(html, /정책 및 지원/);
  assert.match(html, /계정 관리 안내/);
  assert.doesNotMatch(html, /codex-preview|Codex/i);
});

test("removes starter-only capabilities", async () => {
  const [page, layout, packageJson] = await Promise.all([
    readFile(new URL("app/page.tsx", projectRoot), "utf8"),
    readFile(new URL("app/layout.tsx", projectRoot), "utf8"),
    readFile(new URL("package.json", projectRoot), "utf8"),
  ]);

  assert.match(page, /단짠/);
  assert.match(layout, /lang="ko"/);
  assert.doesNotMatch(packageJson, /drizzle|react-loading-skeleton/);
  assert.doesNotMatch(page, /SkeletonPreview|codex-preview/);

  await Promise.all([
    assert.rejects(
      access(new URL("app/_sites-preview/SkeletonPreview.tsx", projectRoot)),
    ),
    assert.rejects(access(new URL("app/chatgpt-auth.ts", projectRoot))),
    assert.rejects(access(new URL("db/index.ts", projectRoot))),
    assert.rejects(
      access(new URL("examples/d1/app/api/notes/route.ts", projectRoot)),
    ),
  ]);
});
