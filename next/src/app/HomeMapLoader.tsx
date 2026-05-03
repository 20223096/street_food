"use client";

import dynamic from "next/dynamic";

const StreetFoodMapClient = dynamic(
  () => import("@/components/StreetFoodMapClient"),
  { ssr: false, loading: () => <StreetFoodMapSkeleton /> },
);

function StreetFoodMapSkeleton() {
  return (
    <div className="flex h-dvh flex-col bg-[#f7f2ef]">
      <header className="flex h-14 shrink-0 items-center bg-[#bf360c] px-4 text-lg font-medium text-white shadow-md">
        길거리 간식 지도
      </header>
      <div className="flex flex-1 flex-col items-center justify-center gap-4 bg-[#ece7e4] text-[#3e2723]">
        <div
          className="h-9 w-9 animate-spin rounded-full border-2 border-[#bf360c] border-t-transparent"
          aria-hidden
        />
        <p>트럭 데이터 불러오는 중…</p>
      </div>
    </div>
  );
}

export default function HomeMapLoader() {
  return <StreetFoodMapClient />;
}
