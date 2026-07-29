export type PolicyDocument = {
  href: string;
  title: string;
  description: string;
};

export const policyDocuments: readonly PolicyDocument[] = [
  {
    href: "/privacy",
    title: "개인정보처리방침",
    description: "단짠이 처리하는 개인정보와 이용자의 권리를 안내합니다.",
  },
  {
    href: "/terms",
    title: "서비스 이용약관",
    description: "단짠 서비스 이용에 적용되는 기본 조건을 안내합니다.",
  },
  {
    href: "/safety",
    title: "안전 이용 약속",
    description: "공유 콘텐츠와 신고·차단에 적용되는 기준을 안내합니다.",
  },
  {
    href: "/account-deletion",
    title: "계정 삭제 안내",
    description: "단짠 계정과 관련 데이터의 삭제 절차를 안내합니다.",
  },
  {
    href: "/support",
    title: "고객지원",
    description: "단짠 이용 방법과 문의가 필요한 문제를 안내합니다.",
  },
] as const;
