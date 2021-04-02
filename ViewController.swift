//
//  ViewController.swift
//  OEP_macos
//
//  Created by Banuba on 3/10/21.
//  Copyright © 2021 Banuba. All rights reserved.
//

import AppKit
import AVFoundation
import Cocoa
import VideoToolbox

class ViewController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var imageView: NSImageView!

    private var oep: BNBOffscreenEffectPlayer?
    private var session = AVCaptureSession()
    private var input: AVCaptureDeviceInput?
    private let output = AVCaptureVideoDataOutput()
    private var error: NSError?
    private let outputVideoOrientation: AVCaptureVideoOrientation = .landscapeRight
    private let cameraPosition: AVCaptureDevice.Position = .front
    private let cameraPreset: AVCaptureSession.Preset = .hd1280x720
    private let renderWidth: UInt = 1280
    private let renderHeight: UInt = 720
    private var effectLoaded = false
    private let token = <<#place your token here#>>

    override func viewDidLoad() {
        super.viewDidLoad()
        effectPlayerInit()
        loadEffect(effectPath: "effects/test_BG")
        setUpCamera()
    }

    override var representedObject: Any? {
        didSet {
        }
    }

    private func effectPlayerInit() {
        oep = BNBOffscreenEffectPlayer.init(width: renderWidth, height: renderHeight, manualAudio: false, token: token as String)
    }

    private func loadEffect(effectPath: String) {
        oep?.loadEffect(effectPath)
        effectLoaded = true
    }

    private func unloadEffect(effectPath: String) {
        oep?.unloadEffect()
        effectLoaded = false
    }

    private func setUpCamera() {
        session.beginConfiguration()
        session.sessionPreset = cameraPreset

        guard let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: AVMediaType.video,
                position: cameraPosition) else { return }
        do {
            input = try AVCaptureDeviceInput(device: camera)
        } catch let error1 as NSError {
            error = error1
            input = nil
            print(error!.localizedDescription)
        }

        guard let input = self.input else { return }

        if error == nil && session.canAddInput(input) {
            session.addInput(input)
        }

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] as [String : Any]
        output.setSampleBufferDelegate(self, queue: DispatchQueue.global())
        session.addOutput(output)

        if let captureConnection = output.connection(with: .video) {
            captureConnection.videoOrientation = outputVideoOrientation
        }

        session.commitConfiguration()
        session.startRunning()
    }

    func renderPixelBuffer(_ pixelBuffer: CVPixelBuffer?) {
        if let resultPixelBuffer = pixelBuffer {
            var cgImage: CGImage?

            VTCreateCGImageFromCVPixelBuffer(resultPixelBuffer, nil, &cgImage)

            guard let cgImageSafe = cgImage else { return }

            let width = CVPixelBufferGetWidth(resultPixelBuffer)
            let height = CVPixelBufferGetHeight(resultPixelBuffer)

            let image = NSImage(cgImage: cgImageSafe, size: NSSize(width: width, height: height))

            DispatchQueue.main.async {
                self.imageView.image = image
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        if (self.effectLoaded) {
            CVPixelBufferLockBaseAddress(imageBuffer, [])

            oep?.processImage(imageBuffer, completion: {(resPixelBuffer) in
                CVPixelBufferUnlockBaseAddress(imageBuffer, [])
                self.renderPixelBuffer(resPixelBuffer)
            })
        }
        else {
            renderPixelBuffer(imageBuffer)
        }
    }
}
