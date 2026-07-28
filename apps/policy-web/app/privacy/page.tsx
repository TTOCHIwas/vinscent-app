import type { Metadata } from "next";
import { DocumentShell } from "../_components/document-shell";

export const metadata: Metadata = {
  title: "개인정보처리방침",
};

export default function PrivacyPage() {
  return (
    <DocumentShell
      title="개인정보처리방침"
      description="단짠의 실제 데이터 처리 흐름과 운영 정보를 확인하고 있습니다."
    >
      <section className="publication-notice" aria-labelledby="privacy-status">
        <h2 id="privacy-status">공개 전 검토 중입니다</h2>
        <p>
          수집 항목, 이용 목적, 보관 기간, 국외 이전과 이용자 권리를 실제
          서비스 동작과 대조한 뒤 최종 문서를 게시합니다.
        </p>
      </section>
    </DocumentShell>
  );
}
