// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZSSDK_zusdk_google",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ZUSDK_Google",
            targets: ["ZUSDKGoogleWrapper"]
        ),
    ],
    dependencies: [
        // 使用官方 GoogleSignIn-iOS SPM 包（SPM 方式）
        // 参考本地配置：基本登录功能仅需核心依赖：
        //   - AppAuth / AppAuthCore
        //   - GTMAppAuth  
        //   - GTMSessionFetcherCore
        // 注意：需要使用 9.0.0+ 版本以支持 signInWithPresentingViewController:hint:additionalScopes:nonce:completion: API
        // 本地配置使用的是 9.0.0 版本，确保 API 兼容性
        // 官方 SPM 包可能包含 AppCheck 和 GoogleUtilities（用于 App Attest 功能）
        // 使用精确版本 9.0.0 以确保与 firebase-ios-sdk 11.0.0+ 的兼容性
        // GoogleSignIn-iOS 9.0.0 需要 app-check 11.0.0+ 和 gtm-session-fetcher 3.3.0+
        // firebase-ios-sdk 11.0.0+ 也使用相同的依赖版本，因此兼容
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", .upToNextMajor(from: "9.0.0")),
    ],
    targets: [
        .binaryTarget(
            name: "GGoogle",
            url: "https://github.com/HiZeusai/SDKPackage/releases/download/2.1.8/GGoogle_2.1.8.zip",
            checksum: "001564991ae52920f285fbc661c9bd79e7a7f9025b098b5f550d731cbfc03415"
        ),
        .target(
            name: "ZUSDKGoogleWrapper",
            dependencies: [
                "GGoogle",
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ],
            path: "Sources"
        ),
    ]
)
