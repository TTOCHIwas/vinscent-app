import Link from "next/link";
import { SiteShell } from "./_components/site-shell";
import { policyDocuments } from "./policy-documents";

export default function Home() {
  return (
    <SiteShell>
      <section className="policy-home">
        <header className="policy-home__header">
          <p className="policy-home__eyebrow">단짠</p>
          <h1>정책 및 지원</h1>
          <p>
            단짠 서비스의 정책 문서와 계정 관리 안내를 한곳에서 확인할 수
            있습니다.
          </p>
        </header>

        <div className="release-status" role="status">
          <strong>공개 문서를 검토하고 있습니다</strong>
          <span>운영 정보가 확정된 뒤 최종 문서가 게시됩니다.</span>
        </div>

        <nav className="document-list" aria-label="정책 및 지원 문서">
          {policyDocuments.map((document) => (
            <Link
              className="document-list__item"
              href={document.href}
              key={document.href}
            >
              <span>
                <strong>{document.title}</strong>
                <small>{document.description}</small>
              </span>
              <span className="document-list__action" aria-hidden="true">
                보기
              </span>
            </Link>
          ))}
        </nav>
      </section>
    </SiteShell>
  );
}
