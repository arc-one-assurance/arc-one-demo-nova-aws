import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Standalone output minimiza la imagen Docker para Cloud Run
  output: "standalone",
  reactStrictMode: true,
  poweredByHeader: false,
  typedRoutes: true,
};

export default nextConfig;
