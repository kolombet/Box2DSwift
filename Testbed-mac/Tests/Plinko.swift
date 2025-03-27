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
        b2Locally {
            let bd = b2BodyDef()
            let ground = self.world.createBody(bd)
            
            // Create walls
            let shape = b2EdgeShape()
            
            // Left wall
            shape.set(vertex1: b2Vec2(-10.0, 0.0), vertex2: b2Vec2(-10.0, 20.0))
            ground.createFixture(shape: shape, density: 0.0)
            
            // Right wall
            shape.set(vertex1: b2Vec2(10.0, 0.0), vertex2: b2Vec2(10.0, 20.0))
            ground.createFixture(shape: shape, density: 0.0)
            
            // Bottom wall (with angled segments for buckets)
            let segments = 8
            let segmentWidth = 20.0 / Float(segments)
            let segmentHalfWidth = segmentWidth / 2.0
            
            for i in 0 ..< segments {
                let x1 = -10.0 + Float(i) * segmentWidth
                let x2 = x1 + segmentWidth
                let y1: Float = 0.0
                let y2: Float = (i % 2 == 0) ? -0.5 : 0.0
                
                shape.set(vertex1: b2Vec2(x1, y1), vertex2: b2Vec2(x1 + segmentHalfWidth, y2))
                ground.createFixture(shape: shape, density: 0.0)
                
                shape.set(vertex1: b2Vec2(x1 + segmentHalfWidth, y2), vertex2: b2Vec2(x2, y1))
                ground.createFixture(shape: shape, density: 0.0)
            }
        }
        
        // Create pegs (circular obstacles)
        b2Locally {
            let rows = 10
            let pegRadius: b2Float = 0.3
            let horizontalSpacing: b2Float = 2.0
            let verticalSpacing: b2Float = 1.5
            
            for row in 0 ..< rows {
                let pegCount = row + 5
                let rowWidth = horizontalSpacing * b2Float(pegCount - 1)
                let startX = -rowWidth / 2.0
                
                for i in 0 ..< pegCount {
                    let x = startX + horizontalSpacing * b2Float(i)
                    let y = 2.0 + verticalSpacing * b2Float(row)
                    
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
                    fd.restitution = 0.7
                    body.createFixture(fd)
                }
            }
        }
    }
    
    func dropBall() {
        b2Locally {
            let ballRadius: b2Float = 0.25
            
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
            fd.restitution = 0.3
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
} 
