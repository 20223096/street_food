import { createClient, type SupabaseClient } from "@supabase/supabase-js";

function normalizeUrl(raw: string): string {
  let u = raw.trim();
  while (u.endsWith("/")) {
    u = u.slice(0, -1);
  }
  const suffix = "/rest/v1";
  if (u.toLowerCase().endsWith(suffix)) {
    u = u.slice(0, -suffix.length);
  }
  return u;
}

export function createBrowserSupabase(): SupabaseClient | null {
  const raw = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY?.trim();
  if (!raw || !key) return null;
  return createClient(normalizeUrl(raw), key);
}
