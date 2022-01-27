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

class ViewController: NSViewController, NSWindowDelegate {

    @IBOutlet weak var imageView: NSImageView!

    private var oep: BNBOffscreenEffectPlayer?
    private let renderWidth: UInt = 1280
    private let renderHeight: UInt = 720
    private var effectLoaded = false
    private let token = <#place your token here#>

    override func viewDidLoad() {
        super.viewDidLoad()
        effectPlayerInit()
        loadEffect(effectPath: "test_BG")
    }
    
    override func viewDidAppear() {
        self.view.window?.delegate = self
    }

    func windowWillClose(_ notification: Notification){
        unloadEffect()
        oep = nil
        NSApp.terminate(self);
    }
    
    override var representedObject: Any? {
        didSet {
        }
    }

    private func effectPlayerInit() {
        let dirs = [Bundle.main.bundlePath + "/Contents/Frameworks/BanubaEffectPlayer.framework/Resources/bnb-resources",
                    Bundle.main.bundlePath + "/Contents/Resources/effects"]

        oep = BNBOffscreenEffectPlayer.init(width: renderWidth,
                                            height: renderHeight,
                                            manualAudio: false,
                                            token: token as String,
                                            resourcePaths: dirs,
                                            completion: {(resPixelBuffer) in self.renderPixelBuffer(resPixelBuffer)})
    }

    private func loadEffect(effectPath: String) {
        oep?.loadEffect(effectPath)
        effectLoaded = true
    }

    private func unloadEffect() {
        oep?.unloadEffect()
        effectLoaded = false
    }

    func renderPixelBuffer(_ pixelBuffer: CVPixelBuffer?) {
        if let resultPixelBuffer = pixelBuffer {
            autoreleasepool {
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
    }
}
