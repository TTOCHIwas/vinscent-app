import Image from "next/image";
import Link from "next/link";
import type { ReactNode } from "react";
import { policyRelease } from "../policy-release";

type SiteShellProps = {
  children: ReactNode;
};

export function SiteShell({ children }: SiteShellProps) {
  return (
    <>
      <a className="skip-link" href="#main-content">
        본문으로 이동
      </a>
      <header className="site-header">
        <div className="site-header__inner">
          <Link className="site-brand" href="/" aria-label="단짠 정책 홈">
            <span className="site-brand__mark" aria-hidden="true">
              <Image src="/favicon.svg" alt="" width={30} height={27} priority />
            </span>
            <span>단짠</span>
          </Link>
          <nav className="site-nav" aria-label="정책 문서">
            <Link href="/privacy">개인정보</Link>
            <Link href="/terms">이용약관</Link>
            <Link href="/account-deletion">계정 삭제</Link>
            <Link href="/support">고객지원</Link>
          </nav>
        </div>
      </header>
      <main id="main-content">{children}</main>
      <footer className="site-footer">
        <div className="site-footer__inner">
          <strong>단짠</strong>
          <span>대표자 {policyRelease.operatorName}</span>
          <span>정책 및 지원</span>
        </div>
      </footer>
    </>
  );
}
