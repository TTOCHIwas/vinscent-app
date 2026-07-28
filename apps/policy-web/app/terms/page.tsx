import type { Metadata } from "next";
import { DocumentShell } from "../_components/document-shell";

export const metadata: Metadata = {
  title: "서비스 이용약관",
};

export default function TermsPage() {
  return (
    <DocumentShell
      title="서비스 이용약관"
      description="단짠의 서비스 조건과 이용자 보호 기준을 확인하고 있습니다."
    >
      <section className="publication-notice" aria-labelledby="terms-status">
        <h2 id="terms-status">공개 전 검토 중입니다</h2>
        <p>
          계정, 커플 공유 데이터, 생성형 AI, 신고와 차단을 포함한 서비스
          운영 기준을 최종 검토한 뒤 게시합니다.
        </p>
      </section>
    </DocumentShell>
  );
}
