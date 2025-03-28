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


class Plinko: TestCase {
    override class var title: String { "Plinko" }
    
    var dropButton: NSButton?
    
    override func prepare() {
        // Create boundary
        do {
            let bd = b2BodyDef()
            let ground = self.world.createBody(bd)
            
            // Create walls
            let shape = b2EdgeShape()
            
            // Left wall
            let wallX = 12.0;
            shape.set(vertex1: b2Vec2(-wallX, 0.0), vertex2: b2Vec2(-wallX, 20.0))
            ground.createFixture(shape: shape, density: 0.0)
            
            // Right wall
            shape.set(vertex1: b2Vec2(wallX, 0.0), vertex2: b2Vec2(wallX, 20.0))
            ground.createFixture(shape: shape, density: 0.0)
        }
        
        // Create pegs (circular obstacles)
        do {
            let rows = 10
            let pegRadius: b2Float = 0.3
            let horizontalSpacing: b2Float = 2.0
            let verticalSpacing: b2Float = 1.5
            
            for row in 0 ..< rows {
                let pegCount = row + 3
                let rowWidth = horizontalSpacing * b2Float(pegCount - 1)
                let startX = -rowWidth / 2.0
                
                for i in 0 ..< pegCount {
                    let x = startX + horizontalSpacing * b2Float(i)
                    let y = 20.0 - verticalSpacing * b2Float(row)
                    
                    let bd = b2BodyDef()
                    bd.type = b2BodyType.staticBody
                    bd.position = b2Vec2(x, y)
                    let body = self.world.createBody(bd)
                    
                    let circle = b2CircleShape()
                    circle.radius = pegRadius
                    
                    let fd = b2FixtureDef()
                    fd.shape = circle
                    fd.density = 0.0
                    fd.friction = 0.1
                    fd.restitution = 0.3
                    body.createFixture(fd)
                    
                    if row == rows - 1 {
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
                        wallBody.createFixture(wallFd)
                        
                        if i < pegCount - 1 {
                            let triggerBd = b2BodyDef()
                            triggerBd.type = b2BodyType.staticBody
                            triggerBd.position = b2Vec2(x + horizontalSpacing / 2.0, y - 2.0)
                            let triggerBody = self.world.createBody(triggerBd)
                            
                            let triggerShape = b2PolygonShape()
                            triggerShape.setAsBox(width: horizontalSpacing / 2.0, height: 0.5)
                            
                            let triggerFd = b2FixtureDef()
                            triggerFd.shape = triggerShape
                            triggerFd.density = 0.0
                            triggerFd.isSensor = true
                            triggerFd.userData = "trigger"
                            triggerBody.createFixture(triggerFd)
                        }
                    }
                }
            }
        }
    }
    
    func dropBall() {
        do {
            let ballRadius: b2Float = 0.5
            
            // Random x position at the top
            let xPos = randomFloat(-7.0, 7.0)
            
            let bd = b2BodyDef()
            bd.type = b2BodyType.dynamicBody
            bd.position = b2Vec2(xPos, 20.0)
            bd.bullet = true
            
            let ball = self.world.createBody(bd)
            
            let circle = b2CircleShape()
            circle.radius = ballRadius
            
            let fd = b2FixtureDef()
            fd.shape = circle
            fd.density = 1.0
            fd.friction = 0.0
            fd.restitution = 0.1
            ball.createFixture(fd)
            
            // Apply a small random impulse
            let impulse = b2Vec2(randomFloat(-0.2, 0.2), 0.0)
            ball.applyLinearImpulse(impulse, point: ball.position, wake: true)
        }
    }
    
    var _customView: NSView?
    override var customView: NSView? {
        if _customView == nil {
            let dropButton = NSButton(title: "Drop Ball", target: self, action: #selector(onDropButtonClicked))
            self.dropButton = dropButton
            
            let stackView = NSStackView(views: [dropButton])
            stackView.orientation = .horizontal
            _customView = stackView
        }
        return _customView
    }
    
    @objc func onDropButtonClicked(_ sender: Any) {
        dropBall()
    }
    
    override func beginContact(_ contact: b2Contact) {
        let fixtureA = contact.fixtureA
        let fixtureB = contact.fixtureB
        
        if fixtureA.userData as? String == "trigger" || fixtureB.userData as? String == "trigger" {
            let ballFixture = fixtureA.userData as? String == "trigger" ? fixtureB : fixtureA
            if ballFixture.body.type == b2BodyType.dynamicBody {
                self.world.destroyBody(ballFixture.body)
            }
        }
    }
} 
