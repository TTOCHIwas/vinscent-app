import Link from "next/link";
import type { ReactNode } from "react";
import { SiteShell } from "./site-shell";

type DocumentShellProps = {
  title: string;
  description: string;
  children: ReactNode;
};

export function DocumentShell({
  title,
  description,
  children,
}: DocumentShellProps) {
  return (
    <SiteShell>
      <article className="document">
        <Link className="document__back" href="/">
          정책 및 지원
        </Link>
        <header className="document__header">
          <p className="document__eyebrow">단짠</p>
          <h1>{title}</h1>
          <p>{description}</p>
        </header>
        <div className="document__body">{children}</div>
      </article>
    </SiteShell>
  );
}
