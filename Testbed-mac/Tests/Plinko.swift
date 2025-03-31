/**
Copyright (c) 2006-2014 Erin Catto http://www.box2d.org
Copyright (c) 2015 - Yohei Yoshihara

This software is provided 'as-is', without any express or implied
warranty.  In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
claim that you wrote the original software. If you use this software
in a product, an acknowledgment in the product documentation would be
appreciated but is not required.

2. Altered source versions must be plainly marked as such, and must not be
misrepresented as being the original software.

3. This notice may not be removed or altered from any source distribution.

This version of box2d was developed by Yohei Yoshihara. It is based upon
the original C++ code written by Erin Catto.
*/

import AppKit
import Foundation

struct BallPosition: Codable {
    let x: Float
    let y: Float
}

struct BallPath: Codable {
    let positions: [BallPosition]
    let ballName: String
}

class Plinko: TestCase, b2ContactListener {
    override class var title: String { "Plinko" }
    
    // Board Configuration - These values will be replaced by settings
    private var BOARD_ROWS: Int = 13
    private var TOP_PEG_COUNT: Int = 4
    private var PEG_RADIUS: b2Float = 3
    private var PIN_SPACING_X: b2Float = 15.0
    private var PIN_SPACING_Y: b2Float = 15.0
    private var BASE_Y: b2Float = 200.0
    private var BALL_RADIUS: b2Float = 6
    private var BALL_SPAWN_Y: b2Float = 220.0
    private var BALL_SPAWN_MAX_X: Float = 15.0
    private var BALL_SPAWN_IMPULSE_MIN: Float = -0.2
    private var BALL_SPAWN_IMPULSE_MAX: Float = 0.2
    private var BALL_LAUNCH_INTERVAL: TimeInterval = 0.02
    private var BALLS_PER_LAUNCH_BATCH = 5
    
    var dropButton: NSButton?
    var launchManyButton: NSButton?
    var cancelButton: NSButton?
    var progressLabel: NSTextField?
    var bodiesToDestroy = [b2Body]()
    var ballLaunchTimer: Timer?
    var remainingBallsToLaunch = 0
    var totalBallsToLaunch = 0
    
    // Ball tracking
    var ballCounter = 0
    var activeBalls = [String: b2Body]()
    var ballPositions = [String: [BallPosition]]()
    
    // Rendering control
    var renderingDisabled = false
    var massLaunchActive = false
    
    // Define collision categories
    let CATEGORY_BOUNDARY: UInt16 = 0x0001
    let CATEGORY_PEG: UInt16 = 0x0002
    let CATEGORY_BALL: UInt16 = 0x0004
    
    override func prepare() {
        // Update local variables from settings
        BOARD_ROWS = settings.boardRows
        TOP_PEG_COUNT = settings.topPegCount
        PEG_RADIUS = settings.pegRadius
        PIN_SPACING_X = settings.pinSpacingX
        PIN_SPACING_Y = settings.pinSpacingY
        BALL_RADIUS = settings.ballRadius
        
        // Set gravity from settings
        world.gravity = b2Vec2(0.0, settings.physicsGravity)
        
        world.setContactListener(self)
        
        let effectivePinSpacingX = PIN_SPACING_X + 2 * PEG_RADIUS
        let effectivePinSpacingY = PIN_SPACING_Y + 2 * PEG_RADIUS
        
        let bottomRowPegCount = BOARD_ROWS + TOP_PEG_COUNT - 1
        let topRowWidth = effectivePinSpacingX * b2Float(TOP_PEG_COUNT - 1)
        let bottomRowWidth = effectivePinSpacingX * b2Float(bottomRowPegCount - 1)
        let topLeftX = -topRowWidth / 2.0
        let topRightX = topRowWidth / 2.0
        let bottomLeftX = -bottomRowWidth / 2.0
        let bottomRightX = bottomRowWidth / 2.0
        let topY = BASE_Y
        let bottomY: b2Float = BASE_Y - effectivePinSpacingY * b2Float(BOARD_ROWS - 1)
        
        // Create boundary
        do {
            let bd = b2BodyDef()
            let ground = self.world.createBody(bd)
            
            // Create walls
            let shape = b2EdgeShape()
            
            // Left angled wall - connects top left peg to bottom left peg
            shape.set(vertex1: b2Vec2(bottomLeftX, bottomY), vertex2: b2Vec2(topLeftX, topY))
            let fixDef = b2FixtureDef()
            fixDef.shape = shape
            fixDef.density = 0.0
            fixDef.friction = 0.1
            fixDef.restitution = 0.3
            fixDef.filter.categoryBits = CATEGORY_BOUNDARY
            ground.createFixture(fixDef)
            
            // Right angled wall - connects top right peg to bottom right peg
            shape.set(vertex1: b2Vec2(topRightX, topY), vertex2: b2Vec2(bottomRightX, bottomY))
            ground.createFixture(fixDef)
        }
        
        // Create pegs (circular obstacles)
        do {
            for row in 0 ..< BOARD_ROWS {
                let pegCount = row + TOP_PEG_COUNT
                let rowWidth = effectivePinSpacingX * b2Float(pegCount - 1)
                let startX = -rowWidth / 2.0
                
                for i in 0 ..< pegCount {
                    let x = startX + effectivePinSpacingX * b2Float(i)
                    let y = BASE_Y - effectivePinSpacingY * b2Float(row)
                    
                    let bd = b2BodyDef()
                    bd.type = b2BodyType.staticBody
                    bd.position = b2Vec2(x, y)
                    let body = self.world.createBody(bd)
                    
                    let circle = b2CircleShape()
                    circle.radius = PEG_RADIUS
                    
                    let fd = b2FixtureDef()
                    fd.shape = circle
                    fd.density = 0.0
                    fd.friction = 0.1
                    fd.restitution = 0.3
                    fd.filter.categoryBits = CATEGORY_PEG
                    body.createFixture(fd)
                    
                    if row == BOARD_ROWS - 1 {
                        let wallBd = b2BodyDef()
                        wallBd.type = b2BodyType.staticBody
                        wallBd.position = b2Vec2(x, y - 1.0)
                        let wallBody = self.world.createBody(wallBd)
                        
                        let wallShape = b2EdgeShape()
                        wallShape.set(vertex1: b2Vec2(0.0, 0.0), vertex2: b2Vec2(0.0, -2.0))
                        
                        let wallFd = b2FixtureDef()
                        wallFd.shape = wallShape
                        wallFd.density = 0.0
                        wallFd.friction = 0.1
                        wallFd.restitution = 0.3
                        wallFd.filter.categoryBits = CATEGORY_BOUNDARY
                        wallBody.createFixture(wallFd)
                        
                        if i < pegCount - 1 {
                            let triggerBd = b2BodyDef()
                            triggerBd.type = b2BodyType.staticBody
                            triggerBd.position = b2Vec2(x + effectivePinSpacingX / 2.0, y - 2.0)
                            let triggerBody = self.world.createBody(triggerBd)
                            
                            let triggerShape = b2PolygonShape()
                            triggerShape.setAsBox(halfWidth: effectivePinSpacingX / 2.0, halfHeight: 0.5)
                            
                            let triggerFd = b2FixtureDef()
                            triggerFd.shape = triggerShape
                            triggerFd.density = 0.0
                            triggerFd.isSensor = true
                            triggerFd.userData = "trigger" as NSString
                            triggerFd.filter.categoryBits = CATEGORY_BOUNDARY
                            triggerBody.createFixture(triggerFd)
                        }
                    }
                }
            }
        }
    }
    
    func dropBall() {
        do {
            let xPos = randomFloat(-BALL_SPAWN_MAX_X, BALL_SPAWN_MAX_X)
            
            let bd = b2BodyDef()
            bd.type = b2BodyType.dynamicBody
            bd.position = b2Vec2(xPos, BALL_SPAWN_Y)
            bd.bullet = true
            
            let ball = self.world.createBody(bd)
            
            let circle = b2CircleShape()
            circle.radius = BALL_RADIUS
            
            let fd = b2FixtureDef()
            fd.shape = circle
            fd.density = 1.0
            fd.friction = 0.0
            fd.restitution = 0.1
            
            fd.filter.categoryBits = CATEGORY_BALL
            fd.filter.maskBits = CATEGORY_BOUNDARY | CATEGORY_PEG
            
            ball.createFixture(fd)
            
            let impulse = b2Vec2(randomFloat(BALL_SPAWN_IMPULSE_MIN, BALL_SPAWN_IMPULSE_MAX), 0.0)
            ball.applyLinearImpulse(impulse, point: ball.position, wake: true)
            
            // Generate a unique name for the ball
            ballCounter += 1
            let ballName = "ball_\(ballCounter)"
            
            // Add ball to tracking collections
            activeBalls[ballName] = ball
            ballPositions[ballName] = []
            
            // Disable launch many button when a ball is added
            launchManyButton?.isEnabled = false
            
            // Record initial position
            let position = BallPosition(x: ball.position.x, y: ball.position.y)
            ballPositions[ballName]?.append(position)
        }
    }
    
    var _customView: NSView?
    override var customView: NSView? {
        if _customView == nil {
            let dropButton = NSButton(title: "Drop Ball", target: self, action: #selector(onDropButtonClicked))
            self.dropButton = dropButton
            
            let launchManyButton = NSButton(title: "Launch 100 Balls", target: self, action: #selector(onLaunchManyButtonClicked))
            self.launchManyButton = launchManyButton
            
            let cancelButton = NSButton(title: "Cancel Launch", target: self, action: #selector(onCancelButtonClicked))
            self.cancelButton = cancelButton
            cancelButton.isEnabled = false
            
            let progressLabel = NSTextField(labelWithString: "")
            progressLabel.alignment = .center
            progressLabel.font = NSFont.systemFont(ofSize: 11)
            progressLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            self.progressLabel = progressLabel
            
            let stackView = NSStackView(views: [dropButton, launchManyButton, cancelButton, progressLabel])
            stackView.orientation = .horizontal
            stackView.spacing = 10
            _customView = stackView
        }
        return _customView
    }
    
    @objc func onDropButtonClicked(_ sender: Any) {
        dropBall()
    }
    
    @objc func onLaunchManyButtonClicked(_ sender: Any) {
        disableRendering()
        massLaunchActive = true
        launchMultipleBalls(count: 100)
        launchManyButton?.isEnabled = false
        cancelButton?.isEnabled = true
    }
    
    @objc func onCancelButtonClicked(_ sender: Any) {
        stopLaunching()
        enableRendering()
        massLaunchActive = false
    }
    
    func stopLaunching() {
        if ballLaunchTimer != nil {
            ballLaunchTimer?.invalidate()
            ballLaunchTimer = nil
        }
        remainingBallsToLaunch = 0
        updateProgressLabel()
        launchManyButton?.isEnabled = true
        cancelButton?.isEnabled = false
    }
    
    func updateProgressLabel() {
        if remainingBallsToLaunch > 0 {
            let progress = totalBallsToLaunch - remainingBallsToLaunch
            progressLabel?.stringValue = "\(progress)/\(totalBallsToLaunch) balls"
        } else {
            progressLabel?.stringValue = ""
        }
    }
    
    func disableRendering() {
        renderingDisabled = true
    }
    
    func enableRendering() {
        renderingDisabled = false
    }
    
    func launchMultipleBalls(count: Int) {
        remainingBallsToLaunch = count
        totalBallsToLaunch = count
        updateProgressLabel()
        
        if ballLaunchTimer != nil {
            ballLaunchTimer?.invalidate()
            ballLaunchTimer = nil
        }
        
        ballLaunchTimer = Timer.scheduledTimer(timeInterval: BALL_LAUNCH_INTERVAL, target: self, selector: #selector(launchTimerFired), userInfo: nil, repeats: true)
    }
    
    @objc func launchTimerFired() {
        for _ in 0..<BALLS_PER_LAUNCH_BATCH {
            if remainingBallsToLaunch > 0 {
                dropBall()
                remainingBallsToLaunch -= 1
                updateProgressLabel()
            } else {
                stopLaunching()
                break
            }
        }
    }
    
    func finishSimulation() {
        // Re-enable rendering and UI
        enableRendering()
        launchManyButton?.isEnabled = activeBalls.isEmpty
        cancelButton?.isEnabled = false
        massLaunchActive = false
        remainingBallsToLaunch = 0
        updateProgressLabel()
    }
    
    func beginContact(_ contact: b2Contact) {
        let fixtureA = contact.fixtureA
        let fixtureB = contact.fixtureB
        
        if fixtureA.userData as? String == "trigger" || fixtureB.userData as? String == "trigger" {
            let ballFixture = fixtureA.userData as? String == "trigger" ? fixtureB : fixtureA
            if ballFixture.body.type == b2BodyType.dynamicBody {
                // Queue the body for destruction instead of destroying it immediately
                bodiesToDestroy.append(ballFixture.body)
            }
        }
    }
    
    func endContact(_ contact: b2Contact) {
        // Not needed for our implementation
    }
    
    func preSolve(_ contact: b2Contact, oldManifold: b2Manifold) {
        // Not needed for our implementation
    }
    
    func postSolve(_ contact: b2Contact, impulse: b2ContactImpulse) {
        // Not needed for our implementation
    }
    
    func saveBallPath(_ ballName: String, positions: [BallPosition]) {
        let ballPath = BallPath(positions: positions, ballName: ballName)
        
        // Create encoder
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try encoder.encode(ballPath)
            
            // Create filename with Unix timestamp
            let timestamp = Int(Date().timeIntervalSince1970)
            
            // Use the user's Documents directory instead of executable directory
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let documentsDirectory = paths[0]
            let fileURL = documentsDirectory.appendingPathComponent("\(ballName)_\(timestamp).json")
            
            // Write to file
            try jsonData.write(to: fileURL)
            print("Saved ball path to \(fileURL.path)")
        } catch {
            print("Error saving ball path: \(error)")
        }
    }
    
    override func step() {
        // If rendering is disabled, still need to process physics
        // but don't need to update UI
        
        // Check for settings changes that require rebuilding
        if checkSettingsChanged() {
            rebuildWorld()
            return
        }
        
        // Record positions for all active balls
        for (ballName, ball) in activeBalls {
            let position = BallPosition(x: ball.position.x, y: ball.position.y)
            ballPositions[ballName, default: []].append(position)
        }
        
        // Update button state based on whether there are active balls
        launchManyButton?.isEnabled = activeBalls.isEmpty && !massLaunchActive
        
        // Process any bodies queued for destruction
        if (bodiesToDestroy.count > 0) {
            for body in bodiesToDestroy {
                // Find the ball name for this body
                for (ballName, ballBody) in activeBalls {
                    if ballBody === body {
                        // Save the ball's path
                        if let positions = ballPositions[ballName], !positions.isEmpty {
                            saveBallPath(ballName, positions: positions)
                        }
                        // Remove tracking data
                        activeBalls.removeValue(forKey: ballName)
                        ballPositions.removeValue(forKey: ballName)
                        break
                    }
                }
                
                // Destroy the body
                world.destroyBody(body)
            }
            bodiesToDestroy.removeAll()
        }
        
        // Check if mass launch is active but balls are done moving
        if massLaunchActive && remainingBallsToLaunch == 0 && activeBalls.isEmpty {
            finishSimulation()
        }
    }
    
    // Helper method to check if settings have changed that require rebuilding
    func checkSettingsChanged() -> Bool {
        return BOARD_ROWS != settings.boardRows ||
               TOP_PEG_COUNT != settings.topPegCount ||
               PEG_RADIUS != settings.pegRadius ||
               PIN_SPACING_X != settings.pinSpacingX ||
               PIN_SPACING_Y != settings.pinSpacingY ||
               BALL_RADIUS != settings.ballRadius ||
               world.gravity.y != settings.physicsGravity
    }
    
    // Helper method to rebuild the world with new settings
    func rebuildWorld() {
        // Clear existing world
        for (_, ball) in activeBalls {
            world.destroyBody(ball)
        }
        activeBalls.removeAll()
        ballPositions.removeAll()
        bodiesToDestroy.removeAll()
        
        // Must recreate all static bodies as well
        var bodyToDestroy: b2Body? = world.getBodyList()
        while let body = bodyToDestroy {
            let nextBody = body.getNext() // Get next before destroying current
            if body.type == b2BodyType.staticBody {
                world.destroyBody(body)
            }
            bodyToDestroy = nextBody
        }
        
        // Update gravity if changed
        if world.gravity.y != settings.physicsGravity {
            world.gravity = b2Vec2(0.0, settings.physicsGravity)
        }
        
        // Prepare the world again with new settings
        prepare()
    }
} 
