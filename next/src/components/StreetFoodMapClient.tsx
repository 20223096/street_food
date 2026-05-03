"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import L from "leaflet";
import {
  MapContainer,
  Marker,
  Popup,
  TileLayer,
  useMap,
} from "react-leaflet";
import "leaflet/dist/leaflet.css";
import { createBrowserSupabase } from "@/lib/supabase-browser";

const FALLBACK_LAT = 37.5665;
const FALLBACK_LNG = 126.9780;

type TruckRow = {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  source: string;
  category_tags: string[] | null;
  is_active: boolean | null;
};

function isOfficialSource(source: string): boolean {
  return source === "admin_manual" || source === "insta_auto";
}

function blueIcon() {
  return L.divIcon({
    className: "street-food-pin",
    html: `<div style="width:18px;height:18px;border-radius:50%;background:#1565c0;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.35)"></div>`,
    iconSize: [18, 18],
    iconAnchor: [9, 9],
  });
}

function grayIcon() {
  return L.divIcon({
    className: "street-food-pin",
    html: `<div style="width:16px;height:16px;border-radius:50%;background:#757575;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.35)"></div>`,
    iconSize: [16, 16],
    iconAnchor: [8, 8],
  });
}

function MapRefBridge({
  onMap,
}: {
  onMap: (m: L.Map | null) => void;
}) {
  const map = useMap();
  useEffect(() => {
    onMap(map);
    return () => onMap(null);
  }, [map, onMap]);
  return null;
}

function MapCenterTracker({
  onCenter,
}: {
  onCenter: (lat: number, lng: number) => void;
}) {
  const map = useMap();
  useEffect(() => {
    const sync = () => {
      const c = map.getCenter();
      onCenter(c.lat, c.lng);
    };
    map.on("moveend", sync);
    sync();
    return () => {
      map.off("moveend", sync);
    };
  }, [map, onCenter]);
  return null;
}

export default function StreetFoodMapClient() {
  const [map, setMap] = useState<L.Map | null>(null);
  const [centerLat, setCenterLat] = useState(FALLBACK_LAT);
  const [centerLng, setCenterLng] = useState(FALLBACK_LNG);
  const [trucks, setTrucks] = useState<TruckRow[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [reportOpen, setReportOpen] = useState(false);

  const supabaseConfigured = useMemo(
    () => Boolean(createBrowserSupabase()),
    [],
  );

  const fetchTrucks = useCallback(async () => {
    const client = createBrowserSupabase();
    if (!client) {
      setTrucks([]);
      setLoadError(null);
      return;
    }
    setLoadError(null);
    setTrucks(null);
    try {
      const { data, error } = await client
        .from("trucks")
        .select(
          "id,name,latitude,longitude,source,category_tags,is_active",
        )
        .eq("is_active", true)
        .order("created_at", { ascending: true });
      if (error) throw error;
      setTrucks((data ?? []) as TruckRow[]);
    } catch (e) {
      setTrucks([]);
      setLoadError(e instanceof Error ? e.message : String(e));
    }
  }, []);

  useEffect(() => {
    void fetchTrucks();
  }, [fetchTrucks]);

  const goMyLocation = () => {
    if (!map) return;
    if (!navigator.geolocation) {
      window.alert("이 브라우저에서는 위치를 사용할 수 없습니다.");
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        map.setView([pos.coords.latitude, pos.coords.longitude], 16);
      },
      () => {
        window.alert("위치 권한이 없으면 내 위치로 이동할 수 없습니다.");
      },
      { enableHighAccuracy: true, timeout: 12_000 },
    );
  };

  const truckCount = trucks?.length ?? 0;
  const loading = trucks === null;

  return (
    <div className="flex h-dvh flex-col bg-[#f7f2ef]">
      <header className="z-[600] flex h-14 shrink-0 items-center justify-between bg-[#bf360c] px-1 pl-3 shadow-md">
        <h1 className="text-lg font-medium tracking-tight text-white">
          길거리 간식 지도
        </h1>
        <div className="flex items-center">
          <button
            type="button"
            onClick={goMyLocation}
            className="rounded-full p-2.5 text-white hover:bg-white/10"
            title="내 위치"
            aria-label="내 위치"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              height="22"
              viewBox="0 -960 960 960"
              width="22"
              fill="currentColor"
              aria-hidden
            >
              <path d="M440-42v-82q-125-16-214.5-105.5T120-444H38v-72h82q16-125 105.5-214.5T440-838v-82h72v82q125 16 214.5 105.5T832-516h82v72h-82q-16 125-105.5 214.5T512-124v82h-72Zm36-200q100 0 170-70t70-170q0-100-70-170t-170-70q-100 0-170 70t-70 170q0 100 70 170t170 70Zm0-120q-33 0-56.5-23.5T396-440q0-33 23.5-56.5T476-520q33 0 56.5 23.5T556-440q0 33-23.5 56.5T476-362Zm4-316Zm-4 396Z" />
            </svg>
          </button>
          <button
            type="button"
            onClick={() => void fetchTrucks()}
            className="rounded-full p-2.5 text-white hover:bg-white/10"
            title="새로고침"
            aria-label="새로고침"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              height="22"
              viewBox="0 -960 960 960"
              width="22"
              fill="currentColor"
              aria-hidden
            >
              <path d="M480-160q-134 0-227-93t-93-227q0-134 93-227t227-93q69 0 132 28.5T720-690v-110h80v280H520v-80h168q-32-56-87.5-88T480-720q-100 0-170 70t-70 170q0 100 70 170t170 70q77 0 139-44t87-116h84q-28 106-114 173t-196 67Z" />
            </svg>
          </button>
        </div>
      </header>

      <div className="relative min-h-0 flex-1">
        {loadError ? (
          <div className="flex h-full items-center justify-center bg-[#ffdad6] p-6 text-center text-[#410002]">
            <p className="max-w-md whitespace-pre-wrap">
              불러오기 실패:
              <br />
              {loadError}
            </p>
          </div>
        ) : (
          <MapContainer
            center={[FALLBACK_LAT, FALLBACK_LNG]}
            zoom={14}
            className="h-full w-full z-0"
            scrollWheelZoom
          >
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            <MapRefBridge onMap={setMap} />
            <MapCenterTracker
              onCenter={(lat, lng) => {
                setCenterLat(lat);
                setCenterLng(lng);
              }}
            />
            {(trucks ?? []).map((t) => (
              <Marker
                key={t.id}
                position={[t.latitude, t.longitude]}
                icon={
                  isOfficialSource(t.source) ? blueIcon() : grayIcon()
                }
              >
                <Popup>
                  <div className="max-w-[220px] p-1">
                    <strong>{t.name}</strong>
                    <div className="text-xs text-neutral-600">
                      {(t.category_tags ?? []).join(", ")}
                    </div>
                  </div>
                </Popup>
              </Marker>
            ))}
          </MapContainer>
        )}

        {!loadError && (
          <div className="pointer-events-auto absolute bottom-[5.5rem] left-2.5 right-2.5 z-[400] sm:left-3 sm:right-3">
            <div className="rounded-[10px] bg-[#ede0db] p-3 text-[#1c1b1f] shadow-md ring-1 ring-black/5 dark:bg-[#3b2f2c] dark:text-[#e6e1e5] dark:ring-white/10">
              <p className="text-sm font-medium">
                트럭 {loading ? "…" : truckCount}곳 (Supabase)
              </p>
              <p className="mt-1.5 text-xs leading-relaxed text-[#49454f] dark:text-[#cac4d0]">
                제보: 아래 버튼 또는 모바일 앱에서 지도 빈 곳을 두 번 탭
              </p>
              <p className="mt-2 text-xs leading-relaxed text-[#5c4033] dark:text-[#b0a090]">
                웹 지도는 OpenStreetMap입니다. iOS 앱은 카카오맵을 사용합니다.
                {!supabaseConfigured && (
                  <>
                    <br />
                    <span className="font-medium text-[#bf360c]">
                      Vercel 환경 변수에 NEXT_PUBLIC_SUPABASE_URL,
                      NEXT_PUBLIC_SUPABASE_ANON_KEY 를 넣으면 트럭이 표시됩니다.
                    </span>
                  </>
                )}
              </p>
            </div>
          </div>
        )}

        {!loadError && (
          <button
            type="button"
            onClick={() => setReportOpen(true)}
            className="pointer-events-auto absolute bottom-6 right-4 z-[500] flex items-center gap-2 rounded-2xl bg-[#bf360c] px-4 py-3 text-sm font-medium text-white shadow-lg hover:bg-[#a62f0a]"
          >
            <span className="relative inline-flex h-5 w-5 shrink-0" aria-hidden>
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                className="h-5 w-5"
                fill="currentColor"
              >
                <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5S10.62 6.5 12 6.5s2.5 1.12 2.5 2.5S13.38 11.5 12 11.5z" />
              </svg>
              <span className="absolute -right-0.5 -top-0.5 flex h-3.5 w-3.5 items-center justify-center rounded-full bg-white text-[10px] font-bold leading-none text-[#bf360c]">
                +
              </span>
            </span>
            이 위치 제보
          </button>
        )}
      </div>

      {reportOpen && (
        <div
          className="fixed inset-0 z-[700] flex items-end justify-center bg-black/40 sm:items-center"
          role="dialog"
          aria-modal="true"
          aria-labelledby="report-title"
        >
          <div className="max-h-[85vh] w-full max-w-lg overflow-y-auto rounded-t-2xl bg-[#f4f3f0] p-5 shadow-2xl sm:rounded-2xl">
            <h2
              id="report-title"
              className="text-lg font-semibold text-[#1c1b1f]"
            >
              이 위치 제보
            </h2>
            <p className="mt-3 text-sm leading-relaxed text-[#49454f]">
              현재 지도 중심:{" "}
              <span className="font-mono text-[#1c1b1f]">
                {centerLat.toFixed(5)}, {centerLng.toFixed(5)}
              </span>
            </p>
            <p className="mt-3 text-sm leading-relaxed text-[#49454f]">
              사진·카테고리와 함께 제보하려면 Xcode에서 실행하는 iOS/Android
              앱을 사용해 주세요. 웹에서는 지도와 목록만 확인할 수 있습니다.
            </p>
            <button
              type="button"
              onClick={() => setReportOpen(false)}
              className="mt-6 w-full rounded-xl bg-[#bf360c] py-3 text-sm font-medium text-white hover:bg-[#a62f0a]"
            >
              닫기
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
