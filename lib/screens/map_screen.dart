import 'dart:async';

import 'package:flutter/foundation.dart'
    show Factory, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:street_food/models/truck.dart';
import 'package:street_food/providers/trucks_provider.dart';
import 'package:street_food/widgets/report_truck_sheet.dart';

/// 공식·자동 소스: 파란 핀 URL.
/// 유저 제보: 회색 톤 핀 (미검증).
///
/// kakao_map_plugin 0.4.x에는 지도 `onMapLongPress` 콜백이 없어,
/// 동일한 제보 UX를 [KakaoMap.onMapDoubleTap]으로 연결합니다.
const String _officialPinUrl =
    'https://maps.google.com/mapfiles/ms/icons/blue-dot.png';
const String _userReportPinUrl =
    'https://maps.google.com/mapfiles/ms/icons/gray-dot.png';

const double _fallbackLat = 37.5665;
const double _fallbackLng = 126.9780;

/// WebView(카카오맵)이 데스크톱 Flutter에서 `opaque is not implemented on macOS` 등으로 깨짐.
bool get _isKakaoMapEmbeddedViewBroken {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  KakaoMapController? _mapController;

  /// 최초 HTML 로드 시 중심 (서울 시청 근처). 이후 이동은 [KakaoMapController]로 처리.
  final LatLng _fallbackCenter = LatLng(_fallbackLat, _fallbackLng);

  Future<void> _goToMyLocation() async {
    final controller = _mapController;
    if (controller == null) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('시뮬레이터/기기에서 위치 서비스를 켜 주세요.'),
        ),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('위치 권한이 없으면 내 위치로 이동할 수 없습니다.'),
        ),
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    controller.setCenter(LatLng(pos.latitude, pos.longitude));
    controller.setLevel(4);
  }

  void _scheduleMapRelayout(KakaoMapController controller) {
    Future<void> run() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      controller.relayout();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      controller.relayout();
    }

    unawaited(run());
  }

  Future<void> _onFabReport() async {
    final controller = _mapController;
    if (controller == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('지도를 불러오는 중입니다. 잠시 후 다시 눌러 주세요.'),
        ),
      );
      return;
    }
    final center = await controller.getCenter();
    if (!mounted) return;
    _openReportSheet(center);
  }

  void _openReportSheet(LatLng latLng) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ReportTruckSheet(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
      ),
    );
  }

  void _openReportSheetCoords(double lat, double lng) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ReportTruckSheet(
        latitude: lat,
        longitude: lng,
      ),
    );
  }

  List<Marker> _markersFromTrucks(List<Truck> trucks) {
    return trucks.map((t) {
      final official = t.isOfficialSource;
      return Marker(
        markerId: t.id,
        latLng: LatLng(t.latitude, t.longitude),
        markerImageSrc: official ? _officialPinUrl : _userReportPinUrl,
        width: official ? 36 : 32,
        height: official ? 48 : 42,
        infoWindowContent: _infoWindowHtml(t),
        infoWindowRemovable: true,
        zIndex: official ? 2 : 1,
      );
    }).toList();
  }

  String _infoWindowHtml(Truck t) {
    final name = _htmlEscape(t.name);
    final tags = _htmlEscape(t.categoryTags.join(', '));
    return '<div style="padding:6px;max-width:220px">'
        '<b>$name</b><br/>'
        '<span style="color:#666;font-size:11px">$tags</span>'
        '</div>';
  }

  String _htmlEscape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  @override
  Widget build(BuildContext context) {
    final trucksAsync = ref.watch(trucksProvider);
    final desktop = _isKakaoMapEmbeddedViewBroken;

    return Scaffold(
      appBar: AppBar(
        title: const Text('길거리 간식 지도'),
        actions: [
          if (!desktop)
            IconButton(
              tooltip: '내 위치',
              onPressed: () => unawaited(_goToMyLocation()),
              icon: const Icon(Icons.my_location),
            ),
          IconButton(
            tooltip: '새로고침',
            onPressed: () => ref.invalidate(trucksProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: (!desktop)
          ? FloatingActionButton.extended(
              onPressed: () => unawaited(_onFabReport()),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('이 위치 제보'),
            )
          : null,
      body: trucksAsync.when(
        loading: () => const _LoadingBody(),
        error: (e, _) => _ErrorBody(message: '$e'),
        data: (trucks) {
          if (desktop) {
            return _DesktopTruckFallback(
              trucks: trucks,
              onReportDefaultLocation: () =>
                  _openReportSheetCoords(_fallbackLat, _fallbackLng),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: KakaoMap(
                  center: _fallbackCenter,
                  currentLevel: 4,
                  mapTypeControl: false,
                  zoomControl: false,
                  markers: _markersFromTrucks(trucks),
                  gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                    Factory<OneSequenceGestureRecognizer>(
                      EagerGestureRecognizer.new,
                    ),
                  },
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _scheduleMapRelayout(controller);
                    unawaited(_goToMyLocation());
                  },
                  onMapDoubleTap: _openReportSheet,
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 96,
                child: SafeArea(
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '트럭 ${trucks.length}곳 (Supabase)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '제보: 아래 버튼 또는 지도 빈 곳을 두 번 탭',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '지도가 하얗면: (1) 카카오 developers → 내 애플리케이션 → '
                            '플랫폼 → 웹에 아래와 **동일한** 사이트 URL을 등록 '
                            '(예: http://localhost 또는 .env의 KAKAO_MAP_BASE_URL) '
                            '(2) JavaScript 키 사용 (3) iOS 번들 com.example.streetFood 등록. '
                            'Safari 개발자 도구로 시뮬레이터 WebView 콘솔에서 KOE 오류 확인.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('트럭 데이터 불러오는 중…'),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '불러오기 실패:\n$message',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopTruckFallback extends StatelessWidget {
  const _DesktopTruckFallback({
    required this.trucks,
    required this.onReportDefaultLocation,
  });

  final List<Truck> trucks;
  final VoidCallback onReportDefaultLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'macOS·Windows·Linux 데스크톱에서는 카카오맵 WebView가 아직 지원되지 않아 '
              '지도 대신 목록을 표시합니다. 지도는 iOS·Android에서 실행하세요.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            onPressed: onReportDefaultLocation,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('제보 (기본 좌표: 서울 시청 근처)'),
          ),
        ),
        Expanded(
          child: trucks.isEmpty
              ? const Center(child: Text('등록된 트럭이 없습니다.'))
              : ListView.separated(
                  itemCount: trucks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final t = trucks[i];
                    final official = t.isOfficialSource;
                    return ListTile(
                      leading: Icon(
                        Icons.place,
                        color: official
                            ? Colors.blue.shade700
                            : Colors.grey.shade600,
                      ),
                      title: Text(t.name),
                      subtitle: Text(
                        '${t.latitude.toStringAsFixed(5)}, '
                        '${t.longitude.toStringAsFixed(5)} · '
                        '${t.source} · ${t.categoryTags.join(", ")}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
