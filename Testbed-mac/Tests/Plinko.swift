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

struct BallPath: Codable {
    let positions: [Int64]
    let ballName: String
}

struct PinData: Codable {
    let x: Float
    let y: Float
    let radius: Float
    let type: String // "peg", "boundary_wall", "basket_wall", or "trigger"
}

struct PinConfiguration: Codable {
    let pins: [PinData]
    let boardRows: Int
    let topPegCount: Int
    let pegRadius: Float
    let pinSpacingX: Float
    let pinSpacingY: Float
    let baseY: Float
    let timestamp: Int
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
    
    // New basket configuration
    private var BASKET_HEIGHT: b2Float = 20.0
    private var BASKET_WALL_THICKNESS: b2Float = 1.0
    private var BASKET_BOTTOM_HEIGHT: b2Float = 3.0
    
    // Recording configuration
    private var RECORD_EVERY_N_FRAMES = 3  // Record position every N frames (1 = every frame, 2 = every other frame, etc.)
    
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
    var ballPositions = [String: [Int64]]()
    
    // Helper functions for packing/unpacking coordinates
    func packCoordinates(x: Int, y: Int) -> Int64 {
        return (Int64(x) << 32) | Int64(y & 0xFFFFFFFF)
    }
    
    func unpackX(from packed: Int64) -> Int {
        return Int((packed >> 32) & 0xFFFFFFFF)
    }
    
    func unpackY(from packed: Int64) -> Int {
        return Int(packed & 0xFFFFFFFF)
    }
    
    // Rendering control
    var renderingDisabled = false
    var massLaunchActive = false
    
    // Define collision categories
    let CATEGORY_BOUNDARY: UInt16 = 0x0001
    let CATEGORY_PEG: UInt16 = 0x0002
    let CATEGORY_BALL: UInt16 = 0x0004
    let CATEGORY_BASKET: UInt16 = 0x0008
    
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
        
        // Array to collect pin positions
        var pinPositions: [PinData] = []
        
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
        
        // Calculate basket row position - one spacing below the last peg row
        let basketRowY = bottomY - effectivePinSpacingY
        
        // Create boundary
        do {
            let bd = b2BodyDef()
            let ground = self.world.createBody(bd)
            
            // Create walls
            let shape = b2EdgeShape()
            
            // Left angled wall - connects top left peg to bottom left peg, then continues to basket level
            shape.set(vertex1: b2Vec2(bottomLeftX - effectivePinSpacingX/2, basketRowY), vertex2: b2Vec2(topLeftX, topY))
            let fixDef = b2FixtureDef()
            fixDef.shape = shape
            fixDef.density = 0.0
            fixDef.friction = 0.1
            fixDef.restitution = 0.3
            fixDef.filter.categoryBits = CATEGORY_BOUNDARY
            ground.createFixture(fixDef)
            
            // Collect left wall data
            let leftWallData = PinData(x: Float((bottomLeftX - effectivePinSpacingX/2 + topLeftX) / 2.0), y: Float((basketRowY + topY) / 2.0), radius: 0.0, type: "boundary_wall")
            pinPositions.append(leftWallData)
            
            // Right angled wall - connects top right peg to bottom right peg, then continues to basket level
            shape.set(vertex1: b2Vec2(topRightX, topY), vertex2: b2Vec2(bottomRightX + effectivePinSpacingX/2, basketRowY))
            ground.createFixture(fixDef)
            
            // Collect right wall data
            let rightWallData = PinData(x: Float((topRightX + bottomRightX + effectivePinSpacingX/2) / 2.0), y: Float((topY + basketRowY) / 2.0), radius: 0.0, type: "boundary_wall")
            pinPositions.append(rightWallData)
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
                    
                    // Collect pin position data
                    let pinData = PinData(x: Float(x), y: Float(y), radius: Float(PEG_RADIUS), type: "peg")
                    pinPositions.append(pinData)
                    
                    // Add small separator walls below the last row of pegs
                    if row == BOARD_ROWS - 1 {
                        let wallBd = b2BodyDef()
                        wallBd.type = b2BodyType.staticBody
                        wallBd.position = b2Vec2(x, y - effectivePinSpacingY/2)
                        let wallBody = self.world.createBody(wallBd)
                        
                        let wallShape = b2EdgeShape()
                        wallShape.set(vertex1: b2Vec2(0.0, 0.0), vertex2: b2Vec2(0.0, -effectivePinSpacingY/2))
                        
                        let wallFd = b2FixtureDef()
                        wallFd.shape = wallShape
                        wallFd.density = 0.0
                        wallFd.friction = 0.1
                        wallFd.restitution = 0.3
                        wallFd.filter.categoryBits = CATEGORY_BOUNDARY
                        wallBody.createFixture(wallFd)
                    }
                }
            }
        }
        
        // Create baskets below the last row
        do {
            let basketCount = bottomRowPegCount + 1 // One more basket than the bottom peg row
            let basketRowWidth = effectivePinSpacingX * b2Float(basketCount - 1)
            let basketStartX = -basketRowWidth / 2.0
            
            for i in 0 ..< basketCount {
                let basketCenterX = basketStartX + effectivePinSpacingX * b2Float(i)
                
                // Create basket walls (left and right sides)
                let basketBd = b2BodyDef()
                basketBd.type = b2BodyType.staticBody
                let basketBody = self.world.createBody(basketBd)
                
                // Left wall of basket
                let leftWallShape = b2PolygonShape()
                let leftWallX = basketCenterX - effectivePinSpacingX/2 + BASKET_WALL_THICKNESS/2
                leftWallShape.setAsBox(halfWidth: BASKET_WALL_THICKNESS/2, halfHeight: BASKET_HEIGHT/2)
                
                let leftWallFd = b2FixtureDef()
                leftWallFd.shape = leftWallShape
                leftWallFd.density = 0.0
                leftWallFd.friction = 0.1
                leftWallFd.restitution = 0.3
                leftWallFd.filter.categoryBits = CATEGORY_BASKET
                
                basketBd.position = b2Vec2(leftWallX, basketRowY - BASKET_HEIGHT/2)
                let leftWallBody = self.world.createBody(basketBd)
                leftWallBody.createFixture(leftWallFd)
                
                // Right wall of basket
                let rightWallShape = b2PolygonShape()
                let rightWallX = basketCenterX + effectivePinSpacingX/2 - BASKET_WALL_THICKNESS/2
                rightWallShape.setAsBox(halfWidth: BASKET_WALL_THICKNESS/2, halfHeight: BASKET_HEIGHT/2)
                
                let rightWallFd = b2FixtureDef()
                rightWallFd.shape = rightWallShape
                rightWallFd.density = 0.0
                rightWallFd.friction = 0.1
                rightWallFd.restitution = 0.3
                rightWallFd.filter.categoryBits = CATEGORY_BASKET
                
                basketBd.position = b2Vec2(rightWallX, basketRowY - BASKET_HEIGHT/2)
                let rightWallBody = self.world.createBody(basketBd)
                rightWallBody.createFixture(rightWallFd)
                
                // Bottom of basket - make it a sensor so balls can pass through to trigger
                let bottomShape = b2PolygonShape()
                let bottomWidth = effectivePinSpacingX - BASKET_WALL_THICKNESS
                bottomShape.setAsBox(halfWidth: bottomWidth/2, halfHeight: BASKET_BOTTOM_HEIGHT/2)
                
                let bottomFd = b2FixtureDef()
                bottomFd.shape = bottomShape
                bottomFd.density = 0.0
                bottomFd.friction = 0.1
                bottomFd.restitution = 0.1
                bottomFd.isSensor = true  // Make it a sensor so balls pass through
                bottomFd.filter.categoryBits = CATEGORY_BASKET
                
                basketBd.position = b2Vec2(basketCenterX, basketRowY - BASKET_HEIGHT + BASKET_BOTTOM_HEIGHT/2)
                let bottomBody = self.world.createBody(basketBd)
                bottomBody.createFixture(bottomFd)
                
                // Collect basket wall data
                let leftWallData = PinData(x: Float(leftWallX), y: Float(basketRowY - BASKET_HEIGHT/2), radius: 0.0, type: "basket_wall")
                pinPositions.append(leftWallData)
                
                let rightWallData = PinData(x: Float(rightWallX), y: Float(basketRowY - BASKET_HEIGHT/2), radius: 0.0, type: "basket_wall")
                pinPositions.append(rightWallData)
                
                // Create trigger zone at the bottom of each basket - positioned just below the basket bottom
                let triggerBd = b2BodyDef()
                triggerBd.type = b2BodyType.staticBody
                triggerBd.position = b2Vec2(basketCenterX, basketRowY - BASKET_HEIGHT - BASKET_BOTTOM_HEIGHT/2 - 1.0)
                let triggerBody = self.world.createBody(triggerBd)
                
                let triggerShape = b2PolygonShape()
                triggerShape.setAsBox(halfWidth: bottomWidth/2, halfHeight: 1.0)
                
                let triggerFd = b2FixtureDef()
                triggerFd.shape = triggerShape
                triggerFd.density = 0.0
                triggerFd.isSensor = true
                triggerFd.userData = "basket_trigger_\(i)" as NSString
                triggerFd.filter.categoryBits = CATEGORY_BOUNDARY
                triggerBody.createFixture(triggerFd)
                
                // Collect trigger data
                let triggerData = PinData(x: Float(basketCenterX), y: Float(basketRowY - BASKET_HEIGHT - BASKET_BOTTOM_HEIGHT/2 - 1.0), radius: 0.0, type: "trigger")
                pinPositions.append(triggerData)
            }
        }
        
        // Save pin positions as JSON
        savePinPositions(pinPositions)
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
            fd.filter.maskBits = CATEGORY_BOUNDARY | CATEGORY_PEG | CATEGORY_BASKET
            
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
            let packedPosition = packCoordinates(x: Int(ball.position.x), y: Int(ball.position.y))
            ballPositions[ballName] = [packedPosition]
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
        
        // Check for basket trigger contact
        let userDataA = fixtureA.userData as? String
        let userDataB = fixtureB.userData as? String
        
        if let userData = userDataA, userData.hasPrefix("basket_trigger_") {
            if fixtureB.body.type == b2BodyType.dynamicBody {
                // Queue the ball for destruction
                bodiesToDestroy.append(fixtureB.body)
                
                // Extract basket number for scoring/logging
                let basketNumber = String(userData.dropFirst("basket_trigger_".count))
                print("Ball entered basket \(basketNumber)")
            }
        } else if let userData = userDataB, userData.hasPrefix("basket_trigger_") {
            if fixtureA.body.type == b2BodyType.dynamicBody {
                // Queue the ball for destruction
                bodiesToDestroy.append(fixtureA.body)
                
                // Extract basket number for scoring/logging
                let basketNumber = String(userData.dropFirst("basket_trigger_".count))
                print("Ball entered basket \(basketNumber)")
            }
        }
        
        // Keep the old trigger logic for backward compatibility
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
    
    func savePinPositions(_ pins: [PinData]) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let pinConfiguration = PinConfiguration(
            pins: pins,
            boardRows: BOARD_ROWS,
            topPegCount: TOP_PEG_COUNT,
            pegRadius: Float(PEG_RADIUS),
            pinSpacingX: Float(PIN_SPACING_X),
            pinSpacingY: Float(PIN_SPACING_Y),
            baseY: Float(BASE_Y),
            timestamp: timestamp
        )
        
        // Create encoder
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try encoder.encode(pinConfiguration)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "Failed to create JSON string"
            
            // Print JSON to console
            print("Pin Configuration JSON:")
            print(jsonString)
            
            // Use the user's Documents directory
            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            let documentsDirectory = paths[0]
            let fileURL = documentsDirectory.appendingPathComponent("pin_configuration_\(timestamp).json")
            
            // Write to file
            try jsonData.write(to: fileURL)
            print("Saved pin configuration to \(fileURL.path)")
            
        } catch {
            print("Error saving pin configuration: \(error)")
        }
    }
    
    func saveBallPath(_ ballName: String, positions: [Int64]) {
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
            
            // Save compressed binary version
            if let compressedData = try? (jsonData as NSData).compressed(using: .zlib) as Data {
                // Convert to Base64 string
                let base64String = compressedData.base64EncodedString()
                let base64FileURL = documentsDirectory.appendingPathComponent("\(ballName)_\(timestamp).txt")
                try base64String.write(to: base64FileURL, atomically: true, encoding: .utf8)
                print("Saved base64 encoded ball path to \(base64FileURL.path)")
            }
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
        
        // Record positions for all active balls (only every N frames)
        if stepCount % RECORD_EVERY_N_FRAMES == 0 {
            for (ballName, ball) in activeBalls {
                let packedPosition = packCoordinates(x: Int(ball.position.x), y: Int(ball.position.y))
                ballPositions[ballName, default: []].append(packedPosition)
            }
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
