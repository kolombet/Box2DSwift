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


class ShapeEditing: TestCase {
  override class var title: String { "Shape Editing" }
  var body: b2Body!
  var fixture1: b2Fixture!
  var fixture2: b2Fixture? = nil
  var sensor = false

  override func prepare() {
    b2Locally {
      let bd = b2BodyDef()
      let ground = self.world.createBody(bd)
      
      let shape = b2EdgeShape()
      shape.set(vertex1: b2Vec2(-40.0, 0.0), vertex2: b2Vec2(40.0, 0.0))
      ground.createFixture(shape: shape, density: 0.0)
    }
    
    let bd = b2BodyDef()
    bd.type = b2BodyType.dynamicBody
    bd.position.set(0.0, 10.0)
    body = world.createBody(bd)
    
    let shape = b2PolygonShape()
    shape.setAsBox(halfWidth: 4.0, halfHeight: 4.0, center: b2Vec2(0.0, 0.0), angle: 0.0)
    fixture1 = body.createFixture(shape: shape, density: 10.0)
    
    fixture2 = nil
    
    sensor = false
  }
  
  var _customView: NSView?
  override var customView: NSView? {
    if _customView == nil {
      let createButton = NSButton(title: "Create", target: self, action: #selector(onCreate))
      let destroyButton = NSButton(title: "Destroy", target: self, action: #selector(onDestroy))
      let sensorButton = NSButton(title: "Sensor", target: self, action: #selector(onSensor))
      let stackView = NSStackView(views: [createButton, destroyButton, sensorButton])
      stackView.orientation = .vertical
      stackView.alignment = .leading
      _customView = stackView
    }
    return _customView
  }
  
  @objc func onCreate(_ sender: Any) {
    if fixture2 == nil {
      let shape = b2CircleShape()
      shape.radius = 3.0
      shape.p.set(0.5, -4.0)
      fixture2 = body.createFixture(shape: shape, density: 10.0)
      body.setAwake(true)
    }
  }

  @objc func onDestroy(_ sender: Any) {
    if fixture2 != nil {
      body.destroyFixture(fixture2!)
      fixture2 = nil
      body.setAwake(true)
    }
  }

  @objc func onSensor(_ sender: Any) {
    if fixture2 != nil {
      sensor = !sensor
      fixture2!.setSensor(sensor)
    }
  }
}
