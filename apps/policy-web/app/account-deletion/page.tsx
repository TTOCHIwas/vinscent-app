import type { Metadata } from "next";
import { DocumentShell } from "../_components/document-shell";

export const metadata: Metadata = {
  title: "계정 삭제 안내",
};

export default function AccountDeletionPage() {
  return (
    <DocumentShell
      title="계정 삭제 안내"
      description="앱 안과 웹에서 계정 삭제를 요청하는 절차를 확인하고 있습니다."
    >
      <section className="publication-notice" aria-labelledby="deletion-status">
        <h2 id="deletion-status">공개 전 검토 중입니다</h2>
        <p>
          본인 확인 방법, 삭제되는 데이터, 예외적으로 보관되는 정보와 처리
          기간을 확정한 뒤 삭제 요청 경로를 게시합니다.
        </p>
      </section>
    </DocumentShell>
  );
}
