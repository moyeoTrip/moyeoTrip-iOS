# 앱에 내장한 오픈소스 고지 데이터

정본은 워크스페이스의 `docs/oss/` 다. 이 폴더는 그 정본을 **iOS 배포물에만 필요한 만큼** 복사해 둔 것이고,
서버 호출 없이 오프라인에서도 29-4 · 29-4a 화면이 열리게 하기 위한 번들 리소스다.

| 파일 | 출처 |
|---|---|
| `oss-licenses-ios.json` | `docs/oss/oss-licenses.json` 의 `platforms.ios` 20건만 추린 것 |
| `Apache-2.0.txt` · `MIT.txt` · `BSD-3-Clause.txt` · `Zlib.txt` | `docs/oss/license-texts/` 원문 그대로 |

`KakaoMapsSDK` 는 오픈소스가 아니라 카카오 자체 배포 약관을 따르므로 전문 파일이 없다. 화면은 이 항목에서
라이선스 이름과 원문 URL, `note` 만 보여주고 전문을 지어내지 않는다.

의존성을 추가·제거·업그레이드하면 `docs/oss/README.md` 의 갱신 절차대로 정본을 먼저 고치고,
이 폴더를 다시 복사한다. 여기 있는 파일을 손으로 고치지 않는다.
