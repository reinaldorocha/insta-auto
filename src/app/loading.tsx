import { Loader2 } from "lucide-react";
import { BrandMark } from "@/components/brand-mark";

export default function Loading() {
  return (
    <main className="grid min-h-svh place-items-center bg-[var(--ms-background)] px-6 text-[var(--ms-foreground)]">
      <section className="grid w-full max-w-md gap-6 text-center" aria-live="polite" aria-busy="true">
        <div className="mx-auto flex size-14 items-center justify-center overflow-hidden rounded-lg bg-[var(--ms-surface)] shadow-sm ring-1 ring-[var(--ms-border)]">
          <BrandMark className="size-14 object-cover" priority size={56} />
        </div>
        <div>
          <p className="text-sm font-bold uppercase tracking-[0.2em] text-muted-foreground">UaiFlow</p>
          <h1 className="mt-2 text-xl font-semibold tracking-normal">Carregando...</h1>
        </div>
        <div className="mx-auto inline-flex items-center gap-2 rounded-lg border border-border bg-card px-4 py-2 text-sm font-medium shadow-sm">
          <Loader2 className="size-4 animate-spin text-primary" />
          Aguarde um instante
        </div>
      </section>
    </main>
  );
}
