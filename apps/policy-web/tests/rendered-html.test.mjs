import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const projectRoot = new URL("../", import.meta.url);
const outputDirectory = fileURLToPath(new URL("../out/", import.meta.url));

async function render(pathname = "/") {
  const route = pathname.replace(/^\/+|\/+$/g, "");
  const candidates =
    route.length === 0
      ? ["index.html"]
      : [`${route}.html`, path.join(route, "index.html")];

  for (const candidate of candidates) {
    try {
      return await readFile(path.join(outputDirectory, candidate), "utf8");
    } catch (error) {
      if (error.code !== "ENOENT") {
        throw error;
      }
    }
  }

  throw new Error(`Missing static HTML output for ${pathname}`);
}

function renderedText(html) {
  return html
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, " ")
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
}

test("statically renders the Danjjan policy entry point", async () => {
  const html = await render();
  const pageText = renderedText(html);
  assert.match(html, /<html[^>]*lang="ko"/i);
  assert.match(html, /<title>단짠 정책 및 지원<\/title>/i);
  assert.match(html, /정책 및 지원/);
  assert.match(html, /개인정보처리방침/);
  assert.match(html, /서비스 이용약관/);
  assert.match(html, /안전 이용 약속/);
  assert.match(html, /계정 삭제 안내/);
  assert.match(html, /고객지원/);
  assert.match(pageText, /대표자 조준희/);
  assert.match(pageText, /시행일 2026년 8월 3일/);
  assert.match(html, /name="robots" content="index, follow"/i);
  assert.doesNotMatch(html, /\/_next\/image/);
  assert.doesNotMatch(html, /codex-preview|Codex/i);
});

test("statically renders every policy route with shared navigation", async () => {
  const routes = [
    ["/privacy", "개인정보처리방침"],
    ["/terms", "서비스 이용약관"],
    ["/account-deletion", "계정 삭제 안내"],
    ["/support", "고객지원"],
  ];

  for (const [pathname, title] of routes) {
    const html = await render(pathname);
    const pageText = renderedText(html);
    assert.match(html, new RegExp(`<title>${title} \\| 단짠</title>`, "i"));
    assert.match(html, new RegExp(`<h1>${title}</h1>`));
    assert.match(pageText, /시행일 2026년 8월 3일/);
    assert.doesNotMatch(html, /공개 전 검토 중입니다|배포용 최종본이 아닙니다/);
    assert.match(html, /aria-label="정책 문서"/);
  }
});

test("publishes the verified privacy processing policy", async () => {
  const html = await render("/privacy");
  const pageText = renderedText(html);
  assert.match(html, /현재 처리하는 정보/);
  assert.match(html, /AI와 위치 정보 처리/);
  assert.match(html, /외부 서비스로 전달되는 정보/);
  assert.match(html, /보관과 삭제/);
  assert.match(html, /이용자의 선택과 권리/);
  assert.match(html, /Cloudflare Workers AI/);
  assert.match(html, /Firebase 설치 식별자/);
  assert.match(html, /Firebase Installations·Cloud Messaging/);
  assert.match(html, /MET Norway/);
  assert.match(html, /Data from MET Norway/);
  assert.match(html, /href="https:\/\/api\.met\.no\/"/);
  assert.doesNotMatch(html, /Open-Meteo/);
  assert.match(html, /만 14세 이상/);
  assert.match(pageText, /대표자 조준희/);
  assert.match(pageText, /90일/);
  assert.match(pageText, /1년/);
  assert.match(pageText, /일회용 확인 코드/);
  assert.match(pageText, /10일 이내/);
  assert.match(html, /mailto:vinscent0929@gmail\.com/);
  assert.doesNotMatch(html, /support@example\.com|example\.com/);
});

test("publishes the verified service terms", async () => {
  const html = await render("/terms");
  const pageText = renderedText(html);
  assert.match(html, /계정과 커플 연결/);
  assert.match(html, /공유 콘텐츠/);
  assert.match(html, /AI 기능/);
  assert.match(html, /신고와 차단/);
  assert.match(html, /서비스 변경과 종료/);
  assert.match(html, /만 14세 이상/);
  assert.match(pageText, /대표자 조준희/);
  assert.match(html, /mailto:vinscent0929@gmail\.com/);
  assert.doesNotMatch(html, /support@example\.com|example\.com/);
});

test("documents the implemented in-app account deletion boundary", async () => {
  const html = await render("/account-deletion");
  const pageText = renderedText(html);
  assert.match(html, /설정.*계정.*계정 삭제/s);
  assert.match(html, /삭제되는 정보/);
  assert.match(html, /카드, 녹음, 답변, 캐릭터, 일정과 AI 데이터/);
  assert.match(html, /앱을 사용할 수 없는 경우/);
  assert.match(html, /mailto:vinscent0929@gmail\.com/);
  assert.match(html, /계정 삭제 요청/);
  assert.match(pageText, /로그인 방식, 닉네임과 계정에 등록된 이메일/);
  assert.match(pageText, /일회용 확인 코드/);
  assert.match(pageText, /10일 이내/);
  assert.doesNotMatch(html, /아직 삭제 접수 창구로 사용할 수 없습니다/);
  assert.doesNotMatch(html, /support@example\.com|example\.com/);
});

test("publishes the verified public support contact", async () => {
  const html = await render("/support");
  const pageText = renderedText(html);
  assert.match(html, /앱에서 바로 확인할 수 있어요/);
  assert.match(html, /문의가 필요한 문제/);
  assert.match(html, /계정과 데이터 삭제/);
  assert.match(html, /안전 신고는 우선 확인해요/);
  assert.match(pageText, /7일 이내 최초 검토/);
  assert.match(html, /href="\/account-deletion"/);
  assert.match(html, /mailto:vinscent0929@gmail\.com/);
  assert.doesNotMatch(html, /현재 이 페이지에서는 문의를 접수하지 않습니다/);
  assert.doesNotMatch(html, /support@example\.com|example\.com/);
});

test("publishes the current UGC safety promise", async () => {
  const html = await render("/safety");
  const pageText = renderedText(html);
  assert.match(html, /<title>안전 이용 약속 \| 단짠<\/title>/i);
  assert.match(html, /<h1>안전 이용 약속<\/h1>/);
  assert.match(html, /ugc-safety-v1/);
  assert.match(html, /이런 내용은 나눌 수 없어요/);
  assert.match(html, /불편한 내용은 신고하거나 차단할 수 있어요/);
  assert.match(html, /동의한 뒤 기록을 공유할 수 있어요/);
  assert.match(pageText, /대표자 조준희/);
  assert.match(pageText, /7일 이내에 최초/);
  assert.match(pageText, /1년/);
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
    assert.rejects(access(new URL("worker/index.ts", projectRoot))),
    assert.rejects(access(new URL("vite.config.ts", projectRoot))),
    assert.rejects(access(new URL(".openai/hosting.json", projectRoot))),
  ]);
});

test("exports Cloudflare Pages assets without a server runtime", async () => {
  const headers = await readFile(new URL("../out/_headers", import.meta.url), "utf8");

  assert.match(headers, /X-Content-Type-Options: nosniff/);
  assert.match(headers, /X-Frame-Options: DENY/);

  await Promise.all([
    access(new URL("../out/index.html", import.meta.url)),
    access(new URL("../out/404.html", import.meta.url)),
    access(new URL("../out/favicon.svg", import.meta.url)),
  ]);
});
