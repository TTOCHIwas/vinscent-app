import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const projectRoot = new URL("../", import.meta.url);

async function render(pathname = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(new URL(pathname, "http://localhost"), {
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
  assert.match(html, /개인정보처리방침/);
  assert.match(html, /서비스 이용약관/);
  assert.match(html, /안전 이용 약속/);
  assert.match(html, /계정 삭제 안내/);
  assert.match(html, /고객지원/);
  assert.match(html, /name="robots" content="noindex, nofollow"/i);
  assert.doesNotMatch(html, /codex-preview|Codex/i);
});

test("server-renders every policy route with shared navigation", async () => {
  const routes = [
    ["/privacy", "개인정보처리방침"],
    ["/terms", "서비스 이용약관"],
    ["/account-deletion", "계정 삭제 안내"],
    ["/support", "고객지원"],
  ];

  for (const [pathname, title] of routes) {
    const response = await render(pathname);
    assert.equal(response.status, 200);

    const html = await response.text();
    assert.match(html, new RegExp(`<title>${title} \\| 단짠</title>`, "i"));
    assert.match(html, new RegExp(`<h1>${title}</h1>`));
    assert.match(html, /공개 전 검토 중입니다/);
    assert.match(html, /aria-label="정책 문서"/);
  }
});

test("publishes the verified privacy processing draft without invented contacts", async () => {
  const response = await render("/privacy");
  assert.equal(response.status, 200);

  const html = await response.text();
  assert.match(html, /현재 처리하는 정보/);
  assert.match(html, /AI와 위치 정보 처리/);
  assert.match(html, /외부 서비스로 전달되는 정보/);
  assert.match(html, /보관과 삭제/);
  assert.match(html, /이용자의 선택과 권리/);
  assert.match(html, /Google Gemini/);
  assert.match(html, /Open-Meteo/);
  assert.doesNotMatch(html, /support@example\.com|example\.com/);
});

test("publishes the verified service terms draft", async () => {
  const response = await render("/terms");
  assert.equal(response.status, 200);

  const html = await response.text();
  assert.match(html, /계정과 커플 연결/);
  assert.match(html, /공유 콘텐츠/);
  assert.match(html, /AI 기능/);
  assert.match(html, /신고와 차단/);
  assert.match(html, /서비스 변경과 종료/);
  assert.doesNotMatch(html, /support@example\.com|example\.com/);
});

test("documents the implemented in-app account deletion boundary", async () => {
  const response = await render("/account-deletion");
  assert.equal(response.status, 200);

  const html = await response.text();
  assert.match(html, /설정.*계정.*계정 삭제/s);
  assert.match(html, /삭제되는 정보/);
  assert.match(html, /카드, 녹음, 답변, 캐릭터, 일정과 AI 데이터/);
  assert.match(html, /앱을 사용할 수 없는 경우/);
  assert.match(html, /아직 삭제 접수 창구로 사용할 수 없습니다/);
  assert.doesNotMatch(html, /mailto:|support@example\.com|example\.com/);
});

test("publishes a support draft without inventing a contact address", async () => {
  const response = await render("/support");
  assert.equal(response.status, 200);

  const html = await response.text();
  assert.match(html, /앱에서 바로 확인할 수 있어요/);
  assert.match(html, /문의가 필요한 문제/);
  assert.match(html, /계정과 데이터 삭제/);
  assert.match(html, /href="\/account-deletion"/);
  assert.match(html, /현재 이 페이지에서는 문의를 접수하지 않습니다/);
  assert.doesNotMatch(html, /mailto:|support@example\.com|example\.com/);
});

test("publishes the current UGC safety promise", async () => {
  const response = await render("/safety");
  assert.equal(response.status, 200);

  const html = await response.text();
  assert.match(html, /<title>안전 이용 약속 \| 단짠<\/title>/i);
  assert.match(html, /<h1>안전 이용 약속<\/h1>/);
  assert.match(html, /ugc-safety-v1/);
  assert.match(html, /이런 내용은 나눌 수 없어요/);
  assert.match(html, /불편한 내용은 신고하거나 차단할 수 있어요/);
  assert.match(html, /동의한 뒤 기록을 공유할 수 있어요/);
  assert.doesNotMatch(html, /공개 전 검토 중입니다/);
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
