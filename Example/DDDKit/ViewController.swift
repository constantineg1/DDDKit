//
//  ViewController.swift
//  DDDKit
//
//  Created by Guillaume Sabran on 10/02/2016.
//  Copyright (c) 2016 Guillaume Sabran. All rights reserved.
//

import UIKit
import DDDKit
import GLKit
import AVFoundation
import GLMatrix

class ViewController: UIViewController {
	private let kTracksKey = "tracks"
	private let kPlayableKey = "playable"
	private let kRateKey = "rate"
	private let kCurrentItemKey = "currentItem"
	private let kStatusKey = "status"

	private var video: URL!
	var player: AVPlayer!
	private var playerItem: AVPlayerItem?

	private var isPlaying: Bool {
		return self.player?.rate != 0.0
	}

	override func viewDidLoad() {
		let path = Bundle.main.path(forResource: "big_buck_bunny", ofType: "mp4")!
		video = URL(fileURLWithPath: path)
		self.setUpVideoPlayback()
		self.configureGLKView()
	}

	private func setUpVideoPlayback() {
		player = AVPlayer()

		do {
			try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
		} catch {
			print("Could not use AVAudioSessionCategoryPlayback")
		}

		let asset = AVURLAsset(url: video)
		let requestedKeys = [kTracksKey, kPlayableKey]
		asset.loadValuesAsynchronously(forKeys: requestedKeys, completionHandler: {
			DispatchQueue.main.async {
				let status = asset.statusOfValue(forKey: self.kTracksKey, error: nil)
				if status == AVKeyValueStatus.loaded {
					self.playerItem = AVPlayerItem(asset: asset)
					self.player.replaceCurrentItem(with: self.playerItem!)
					self.play()
				} else {
					print("Failed to load the tracks.")
				}
			}
		})
	}

	fileprivate var videoNode: DDDNode!
	private func configureGLKView() {
		let dddView = DDDView(frame: self.view.bounds)
		dddView.delegate = self
		self.view.insertSubview(dddView, at: 0)

		dddView.scene = DDDScene()
		let videoNode = DDDNode()
		videoNode.geometry = DDDSphere(radius: 1.0, rings: 40, sectors: 40, orientation: .inward)
		let videoTexture = DDDVideoTexture(player: player)

		do {
			let fShader = try DDDFragmentShader(fromResource: "Shader", withExtention: "fsh")
			let program = try DDDShaderProgram(fragment: fShader, shaderModifiers: [DDDShaderEntryPoint.fragment: "gl_FragColor = vec4(gl_FragColor.xyz * 0.5, 1.0);"])
			videoNode.material.shaderProgram = program



			let path = Bundle.main.path(forResource: "kauai", ofType: "jpg")!
			let image = UIImage(contentsOfFile: path)!.cgImage!
			let texture = DDDImageTexture(image: image)
			videoNode.material.set(property: texture, for: "image")


			videoNode.material.set(property: videoTexture, for: "SamplerY", and: "SamplerUV")

		} catch {
			print("could not set shaders: \(error)")
		}

		dddView.scene?.add(node: videoNode)
		self.videoNode = videoNode
	}

	private func play() {
		if isPlaying { return }
		self.player!.seek(to: kCMTimeZero)
		self.player!.play()
	}
}

extension ViewController: DDDSceneDelegate {
	func willRender() {
		let d = Date()
		let dt1 = Float((d.timeIntervalSince1970 / 3.0).truncatingRemainder(dividingBy: 2.0 * Double.pi))
		let dt2 = Float((d.timeIntervalSince1970 / 7.0).truncatingRemainder(dividingBy: 2.0 * Double.pi))
		let dt3 = Float((d.timeIntervalSince1970 / 10.0).truncatingRemainder(dividingBy: 2.0 * Double.pi))

		videoNode.rotation = Quat.init(x: 0, y: 0, z: 0, w: 1)
		videoNode.rotateX(by: dt1)
		videoNode.rotateY(by: dt2)
		videoNode.rotateZ(by: dt3)
		videoNode.position = Vec3(v: (0, 0, -3))

		let material = videoNode.material

		guard let currentProgram = material.shaderProgram else { return }

		let vertexCode = currentProgram.originalVertexShader
		let fragmentCode = currentProgram.originalFragmentShader

		let vShader = DDDVertexShader(from: vertexCode)
		let fShader = DDDFragmentShader(from: fragmentCode)
		DispatchQueue.main.async {
			do {
				/*let program = try DDDShaderProgram(
				vertex: vShader,
				fragment: fShader,
				shaderModifiers: [
				DDDShaderEntryPoint.fragment: "gl_FragColor = vec4(gl_FragColor.b, gl_FragColor.r, gl_FragColor.g, 1.0);",
				]
				)*/

				let image = UIImage(contentsOfFile: Bundle.main.path(forResource: "kauai", ofType: "jpg")!)!
				material.set(property: DDDImageTexture(image: image.cgImage!), for: "u_image")
			} catch {
				print("error!\(error)")
			}
		}
	}
}
