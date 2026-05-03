import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:street_food/kakao_map_compat.dart';
import 'package:street_food/screens/map_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final kakaoKey = dotenv.env['KAKAO_NATIVE_APP_KEY'];
  if (kakaoKey == null || kakaoKey.isEmpty) {
    throw StateError(
      'Missing KAKAO_NATIVE_APP_KEY in .env (use Kakao Developers JavaScript 키)',
    );
  }
  final kakaoBase = _kakaoMapBaseUrl();
  KakaoMapPlugin.initialize(
    appKey: kakaoKey,
    baseUrl: kakaoBase,
  );

  final rawUrl = dotenv.env['SUPABASE_URL'];
  final anon = dotenv.env['SUPABASE_ANON_KEY'];
  if (rawUrl == null ||
      anon == null ||
      rawUrl.isEmpty ||
      anon.isEmpty) {
    throw StateError(
      'Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env',
    );
  }

  final url = _normalizeSupabaseUrl(rawUrl);

  await Supabase.initialize(
    url: url,
    anonKey: anon,
  );

  runApp(
    const ProviderScope(
      child: StreetFoodApp(),
    ),
  );
}

/// WebView `loadHtmlString`의 base URL. 카카오 콘솔 **웹 플랫폼**에 동일한 사이트 URL을 등록해야 지도가 뜹니다.
/// 미지정 시 플러그인 예제와 같이 `http://localhost` (콘솔 웹에 `http://localhost` 추가).
String _kakaoMapBaseUrl() {
  var u = dotenv.env['KAKAO_MAP_BASE_URL']?.trim() ?? '';
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  if (u.isEmpty) {
    return 'http://localhost';
  }
  return u;
}

/// Supabase는 호스트만 넣어야 합니다. 끝에 `/`·`/rest/v1`이 붙으면 요청 URL이 깨집니다.
String _normalizeSupabaseUrl(String value) {
  var u = value.trim();
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  const suffix = '/rest/v1';
  if (u.toLowerCase().endsWith(suffix)) {
    u = u.substring(0, u.length - suffix.length);
  }
  return u;
}

class StreetFoodApp extends StatelessWidget {
  const StreetFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Street Food',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
