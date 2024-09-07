//
//  Confetti.swift
//  superghost
//
//  Created by Hannes Nagel on 9/7/24.
//

import Foundation
import SpriteKit
import SwiftUI

private class ParticleScene: SKScene {

    // Emission rate per second
    private let spawnRate = 100.0
    // Maximum angle for particle spread from the vertical axis (270 degrees)
    private let maxSpreadAngle = Double.pi / 4

    // Define the particle colors
    private let particleColors = [SKColor(.red), SKColor(.yellow), SKColor(.purple), SKColor(.blue), SKColor(.green)]

    // Timer to manage particle emission
    private var spawnTimer: Timer?

    // Random particle size generator
    private func generateSize() -> CGSize {
        let width = [16.0, 20.0, 24.0].randomElement()!
        let ratio = [0.6, 0.4, 0.5].randomElement()!
        return CGSize(width: width, height: width * ratio)
    }

    // Generate random direction for particles
    private func generateDirection() -> Double {
        Double.random(in: (Double.pi * 1.5 - maxSpreadAngle)...(Double.pi * 1.5 + maxSpreadAngle))
    }

    // Randomize particle rotation speed
    private func generateRotationSpeed() -> Double {
        Double.random(in: 0.2...3.5) * [-1, 1].randomElement()!
    }

    // Random particle scaling speed
    private func generateScaleSpeed() -> Double {
        Double.random(in: 0.9...1.2)
    }

    // Random particle color generator
    private func generateColor() -> SKColor {
        particleColors.randomElement()!
    }

    // Randomize the initial particle position
    private func generateInitialPosition(in viewSize: CGSize) -> CGPoint {
        let spreadX = viewSize.height * sin(maxSpreadAngle)
        let xPos = Double.random(in: -spreadX...(viewSize.width + spreadX))
        let yPos = Double.random(in: (viewSize.height + 15)...viewSize.height * 1.25)
        return CGPoint(x: xPos, y: yPos)
    }

    override func update(_ currentTime: TimeInterval) {
        // Remove particles that are out of bounds
        for node in children {
            if node.position.y < -60 {
                node.removeAllActions()
                node.removeFromParent()
            }
        }
    }

    override func didMove(to view: SKView) {
        // Ensure the background remains transparent
        backgroundColor = .clear
        view.allowsTransparency = true
        #if !os(macOS)
        view.backgroundColor = .clear
        #endif
        beginParticles()
        Task {
            try? await Task.sleep(for: .seconds(3))
            spawnTimer?.invalidate()
        }
    }

    private func beginParticles() {
        guard let view else { return }
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / spawnRate, repeats: true) { timer in
            // Generate particle and add it to the scene
            let particle = self.createParticleNode(
                color: self.generateColor(),
                size: self.generateSize(),
                direction: self.generateDirection(),
                rotationX: self.generateRotationSpeed(),
                rotationY: self.generateRotationSpeed(),
                rotationZ: self.generateRotationSpeed(),
                scaleSpeed: self.generateScaleSpeed())
            particle.position = self.generateInitialPosition(in: view.frame.size)
            self.addChild(particle)
        }
    }

    // Create a particle node with transformations
    private func createParticleNode(color: SKColor, size: CGSize, direction: Double,
                                    rotationX: Double, rotationY: Double, rotationZ: Double, scaleSpeed: Double) -> SKNode {

        let shape = SKShapeNode(path: .init(rect: CGRect(origin: .zero, size: size), transform: nil), centered: true)
        shape.fillColor = color
        shape.strokeColor = .clear

        // Create a node to handle 3D transformations
        let containerNode = SKTransformNode()
        containerNode.addChild(shape)

        // X-axis rotation
        let rotateX = SKAction.customAction(withDuration: abs(rotationX)) { (node, time) in
            (node as! SKTransformNode).xRotation = (time / rotationX) * 2 * CGFloat(Double.pi)
        }

        // Y-axis rotation
        let rotateY = SKAction.customAction(withDuration: abs(rotationY)) { (node, time) in
            (node as! SKTransformNode).yRotation = (time / rotationY) * 2 * CGFloat(Double.pi)
        }

        // Z-axis rotation
        let rotateZ = SKAction.customAction(withDuration: abs(rotationZ)) { (node, time) in
            (node as! SKTransformNode).zRotation = (time / rotationZ) * 2 * CGFloat(Double.pi)
        }

        // Movement action based on direction
        let moveVelocity = pow(size.width, 1.15) * 7
        let moveAction = SKAction.move(by: CGVector(dx: cos(direction) * moveVelocity, dy: sin(direction) * moveVelocity), duration: 1.0)

        // Scaling action
        let scaleAction = SKAction.scale(by: scaleSpeed, duration: 1.0)

        // Attach actions to the node
        containerNode.run(SKAction.repeatForever(rotateX))
        containerNode.run(SKAction.repeatForever(rotateY))
        containerNode.run(SKAction.repeatForever(rotateZ))
        containerNode.run(SKAction.repeatForever(moveAction))
        containerNode.run(SKAction.repeatForever(scaleAction))

        return containerNode
    }
}

private struct ParticleView: View {
    var body: some View {
        GeometryReader {
            SpriteView(scene: ParticleScene(size: $0.size), options: [.allowsTransparency])
                .background(.clear)
                .ignoresSafeArea()
                .allowsHitTesting(true)
        }
    }
}

func showConfetti(on viewController: ViewController) {
    #if !os(macOS)
    let hostingController = UIHostingController(rootView: ParticleView())
    hostingController.view.backgroundColor = .clear
    hostingController.modalPresentationStyle = .overFullScreen
    viewController
        .present(hostingController, animated: false)
    Task{
        try? await Task.sleep(for: .seconds(10))
        _ = await hostingController.dismiss(animated: false)
    }
    #endif
}
