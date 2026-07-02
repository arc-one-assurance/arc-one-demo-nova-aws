export default function HomePage() {
  return (
    <main className="min-h-dvh flex items-center justify-center px-6">
      <div className="max-w-2xl w-full">
        <p className="text-xs uppercase tracking-widest text-blue-400 mb-3">
          Arc One · Demo Agent
        </p>
        <h1 className="text-4xl md:text-5xl font-semibold tracking-tight mb-4">
          Nova
        </h1>
        <p className="text-lg text-zinc-300 mb-6">
          Corporate Virtual Assistant. Q&amp;A interno sobre políticas, FAQs y procedimientos corporativos.
        </p>
        <div className="rounded-lg border border-zinc-800 bg-zinc-900/40 p-4 font-mono text-sm text-zinc-400">
          <span className="text-zinc-500">$</span> POST /api/v1/chat
        </div>
        <p className="text-xs text-zinc-500 mt-6">
          Versión: <span className="font-mono">v1.0.0</span>
          {" · "}
          Stack: Next.js 15 + React 19 + Anthropic SDK
        </p>
      </div>
    </main>
  );
}
