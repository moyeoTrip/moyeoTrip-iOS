import Foundation

/// 29-4 · 29-4a 가 쓰는 오픈소스 고지 항목. 정본은 `docs/oss/oss-licenses.json` 이고,
/// iOS 배포물에는 `Resources/OSS/oss-licenses-ios.json` 으로 복사해 내장한다(서버 호출 없음).
struct OSSLicenseItem: Identifiable, Hashable, Decodable {
    let name: String
    let version: String
    let license: String
    /// 라이선스 전문 파일 키. 자체 배포 SDK 처럼 전문이 없는 항목은 `nil` 이다.
    let licenseTextId: String?
    let url: String
    let note: String?

    var id: String { name }
}

enum OSSLicenseCatalogError: Error {
    case resourceMissing(String)
}

enum OSSLicenseCatalog {
    static let resourceName = "oss-licenses-ios"

    /// 번들에 내장된 iOS 항목 20건. 읽지 못하면 없는 값을 지어내지 않고 빈 목록을 준다.
    static let items: [OSSLicenseItem] = (try? loadItems()) ?? []

    static func loadItems(bundle: Bundle = .main) throws -> [OSSLicenseItem] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw OSSLicenseCatalogError.resourceMissing("\(resourceName).json")
        }
        return try decodeItems(from: Data(contentsOf: url))
    }

    static func decodeItems(from data: Data) throws -> [OSSLicenseItem] {
        try JSONDecoder().decode(OSSLicenseFile.self, from: data).items
    }

    /// 라이선스 전문. 전문 파일이 없는 항목(카카오 지도 SDK 등)은 `nil` — 전문을 지어내지 않는다.
    static func licenseText(for item: OSSLicenseItem, bundle: Bundle = .main) -> String? {
        guard let licenseTextId = item.licenseTextId,
              let url = bundle.url(forResource: licenseTextId, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return nil
        }
        return text
    }

    static func item(named name: String) -> OSSLicenseItem? {
        items.first { $0.name == name }
    }
}

private struct OSSLicenseFile: Decodable {
    let items: [OSSLicenseItem]
}
