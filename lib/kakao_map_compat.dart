import 'package:kakao_map_plugin/kakao_map_plugin.dart';

/// `kakao_map_plugin` 패키지는 공식적으로 [AuthRepository.initialize]를 노출합니다.
/// 호출부에서는 요청하신 이름 그대로 사용할 수 있도록 래핑했습니다.
abstract final class KakaoMapPlugin {
  /// [baseUrl]은 WebView `loadHtmlString`의 base URL로 쓰입니다. 생략 시 null.
  static void initialize({required String appKey, String? baseUrl}) {
    AuthRepository.initialize(appKey: appKey, baseUrl: baseUrl);
  }
}
