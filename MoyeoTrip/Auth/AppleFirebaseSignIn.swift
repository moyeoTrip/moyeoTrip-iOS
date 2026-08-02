import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation
import Security
import UIKit

struct AppleFirebaseSignIn {
    func idToken() async throws -> String {
        let rawNonce = try Self.randomNonce()
        let appleCredential = try await AppleAuthorizationCoordinator.shared.credential(
            hashedNonce: Self.sha256(rawNonce)
        )
        guard let tokenData = appleCredential.identityToken,
              let appleIDToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthIdentityError.missingIDToken
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: appleIDToken,
            rawNonce: rawNonce,
            fullName: appleCredential.fullName
        )
        let result = try await Auth.auth().signIn(with: credential)
        return try await result.user.getIDToken()
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonce(length: Int = 32) throws -> String {
        precondition(length > 0)
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            guard status == errSecSuccess else {
                throw AuthIdentityError.unsupportedProvider
            }
            bytes.forEach { byte in
                guard remainingLength > 0, byte < characters.count else { return }
                result.append(characters[Int(byte)])
                remainingLength -= 1
            }
        }
        return result
    }
}

@MainActor
private final class AppleAuthorizationCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleAuthorizationCoordinator()

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    func credential(hashedNonce: String) async throws -> ASAuthorizationAppleIDCredential {
        guard continuation == nil else {
            throw AuthIdentityError.unsupportedProvider
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        if let keyWindow = windowScenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        guard let windowScene = windowScenes.first else {
            preconditionFailure("Apple 로그인 화면을 표시할 WindowScene이 없습니다.")
        }
        return ASPresentationAnchor(windowScene: windowScene)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(AuthIdentityError.missingIDToken))
            return
        }
        finish(.success(credential))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<ASAuthorizationAppleIDCredential, Error>) {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }
}
