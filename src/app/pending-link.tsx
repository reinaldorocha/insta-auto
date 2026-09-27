"use client";

import Link from "next/link";
import type { ComponentProps, ReactNode } from "react";
import { useState } from "react";
import { Loader2 } from "lucide-react";

type Props = Omit<ComponentProps<typeof Link>, "children"> & {
  children: ReactNode;
  pendingLabel?: string;
  disabled?: boolean;
};

export function PendingLink({ children, pendingLabel = "Aguarde...", disabled = false, className, onClick, ...props }: Props) {
  const [pending, setPending] = useState(false);

  return (
    <Link
      prefetch={props.prefetch ?? false}
      className={className}
      aria-disabled={disabled || pending}
      onClick={(event) => {
        onClick?.(event);
        if (event.defaultPrevented) return;
        if (disabled || pending) {
          event.preventDefault();
          return;
        }
        setPending(true);
      }}
      {...props}
    >
      {pending ? <Loader2 className="size-4 animate-spin" /> : null}
      {pending ? pendingLabel : children}
    </Link>
  );
}
