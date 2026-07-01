import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      setupMediaToolsChannel(messenger: controller.binaryMessenger)
    }
    return result
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func setupMediaToolsChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "modelapp/media_tools",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "compressVideo" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let inputPath = args["inputPath"] as? String,
        let outputPath = args["outputPath"] as? String
      else {
        result(
          FlutterError(
            code: "bad_args",
            message: "inputPath and outputPath are required",
            details: nil
          )
        )
        return
      }
      self?.compressVideo(inputPath: inputPath, outputPath: outputPath, result: result)
    }
  }

  private func compressVideo(
    inputPath: String,
    outputPath: String,
    result: @escaping FlutterResult
  ) {
    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)
    let asset = AVURLAsset(url: inputURL)

    guard
      let exportSession = AVAssetExportSession(
        asset: asset,
        presetName: AVAssetExportPresetMediumQuality
      )
    else {
      result(["path": inputPath, "compressed": false])
      return
    }

    do {
      let outputDirectory = outputURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(
        at: outputDirectory,
        withIntermediateDirectories: true
      )
      if FileManager.default.fileExists(atPath: outputURL.path) {
        try FileManager.default.removeItem(at: outputURL)
      }
    } catch {
      result(
        FlutterError(
          code: "prepare_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
      return
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true

    exportSession.exportAsynchronously {
      DispatchQueue.main.async {
        switch exportSession.status {
        case .completed:
          result(["path": outputURL.path, "compressed": true])
        case .failed, .cancelled:
          result(["path": inputPath, "compressed": false])
        default:
          result(["path": inputPath, "compressed": false])
        }
      }
    }
  }
}
