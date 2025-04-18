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

import Cocoa


func randomFloat() -> b2Float {
  var rand = b2Float(arc4random_uniform(1000)) / b2Float(1000)
  rand = b2Float(2.0) * rand - b2Float(1.0)
  return rand
}

func randomFloat(_ low: b2Float, _ high: b2Float) -> b2Float {
  let rand = (b2Float(arc4random_uniform(1000)) / b2Float(1000)) * (high - low) + low
  return rand
}

func convertScreenToWorld(_ tp: CGPoint, size: CGSize, viewCenter: b2Vec2) -> b2Vec2 {
  let u = b2Float(tp.x / size.width)
  let v = b2Float(tp.y / size.height)
  let extents = b2Vec2(25.0, 25.0)
  let lower = viewCenter - extents
  let upper = viewCenter + extents
  var p = b2Vec2()
  p.x = (1.0 - u) * lower.x + b2Float(u) * upper.x
  p.y = (1.0 - v) * lower.y + b2Float(v) * upper.y
  return p
}

func calcViewBounds(viewSize: CGSize, viewCenter: b2Vec2, extents: b2Vec2) -> (lower: b2Vec2, upper: b2Vec2) {
  var lower = viewCenter - extents
  var upper = viewCenter + extents
  
  if viewSize.width > viewSize.height {
    let r = viewSize.width / viewSize.height
    lower.x *= Float(r)
    upper.x *= Float(r)
  } else {
    let r = viewSize.height / viewSize.width
    lower.y *= Float(r)
    upper.y *= Float(r)
  }
  return (lower, upper)
}

class Settings : CustomStringConvertible {
  var zoomScale: Float = 10
  static var baseExtents = b2Vec2(25.0, 25.0)
  
  static var extents: b2Vec2 {
    let scale = Settings.sharedSettings?.zoomScale ?? 1.0
    return b2Vec2(baseExtents.x * scale, baseExtents.y * scale)
  }
  
  static var sharedSettings: Settings?
  
  // Plinko settings
  var pinSpacingX: b2Float = 15.0
  var pinSpacingY: b2Float = 15.0
  var boardRows: Int = 13
  var topPegCount: Int = 4
  var pegRadius: b2Float = 3.0
  var ballRadius: b2Float = 6.0
  var physicsGravity: b2Float = -200.0
  
  init() {
    Settings.sharedSettings = self
    assert(Settings.baseExtents.x == Settings.baseExtents.y)
    viewCenter = b2Vec2(0.0, 20.0)
    hz = b2Float(60.0)
    velocityIterations = 8
    positionIterations = 3
    let isDrawEnabled = true;
    drawShapes = isDrawEnabled
    drawJoints = isDrawEnabled
    drawAABBs = false
    drawContactPoints = false
    drawContactNormals = false
    drawContactImpulse = false
    drawFrictionImpulse = false
    drawCOMs = false
    drawStats = false
    drawProfile = false
    enableWarmStarting = true
    enableContinuous = true
    enableSubStepping = false
    enableSleep = true
    pause = false
    singleStep = false
    
    // Load saved settings if available
    loadFromUserDefaults()
  }
  
  // Keys for UserDefaults
  private struct Keys {
    static let velocityIterations = "velocityIterations"
    static let positionIterations = "positionIterations"
    static let hz = "hz"
    static let drawShapes = "drawShapes"
    static let drawJoints = "drawJoints"
    static let drawAABBs = "drawAABBs"
    static let drawContactPoints = "drawContactPoints"
    static let drawContactNormals = "drawContactNormals"
    static let drawContactImpulse = "drawContactImpulse"
    static let drawFrictionImpulse = "drawFrictionImpulse"
    static let drawCOMs = "drawCOMs"
    static let drawStats = "drawStats"
    static let drawProfile = "drawProfile"
    static let enableWarmStarting = "enableWarmStarting"
    static let enableContinuous = "enableContinuous"
    static let enableSubStepping = "enableSubStepping"
    static let enableSleep = "enableSleep"
    static let zoomScale = "zoomScale"
    
    // Plinko specific keys
    static let pinSpacingX = "pinSpacingX"
    static let pinSpacingY = "pinSpacingY"
    static let boardRows = "boardRows"
    static let topPegCount = "topPegCount"
    static let pegRadius = "pegRadius"
    static let ballRadius = "ballRadius"
    static let physicsGravity = "physicsGravity"
  }
  
  // Save settings to UserDefaults
  func saveToUserDefaults() {
    let defaults = UserDefaults.standard
    
    // Basic settings
    defaults.set(velocityIterations, forKey: Keys.velocityIterations)
    defaults.set(positionIterations, forKey: Keys.positionIterations)
    defaults.set(Double(hz), forKey: Keys.hz)
    defaults.set(drawShapes, forKey: Keys.drawShapes)
    defaults.set(drawJoints, forKey: Keys.drawJoints)
    defaults.set(drawAABBs, forKey: Keys.drawAABBs)
    defaults.set(drawContactPoints, forKey: Keys.drawContactPoints)
    defaults.set(drawContactNormals, forKey: Keys.drawContactNormals)
    defaults.set(drawContactImpulse, forKey: Keys.drawContactImpulse)
    defaults.set(drawFrictionImpulse, forKey: Keys.drawFrictionImpulse)
    defaults.set(drawCOMs, forKey: Keys.drawCOMs)
    defaults.set(drawStats, forKey: Keys.drawStats)
    defaults.set(drawProfile, forKey: Keys.drawProfile)
    defaults.set(enableWarmStarting, forKey: Keys.enableWarmStarting)
    defaults.set(enableContinuous, forKey: Keys.enableContinuous)
    defaults.set(enableSubStepping, forKey: Keys.enableSubStepping)
    defaults.set(enableSleep, forKey: Keys.enableSleep)
    defaults.set(Double(zoomScale), forKey: Keys.zoomScale)
    
    // Plinko settings
    defaults.set(Double(pinSpacingX), forKey: Keys.pinSpacingX)
    defaults.set(Double(pinSpacingY), forKey: Keys.pinSpacingY)
    defaults.set(boardRows, forKey: Keys.boardRows)
    defaults.set(topPegCount, forKey: Keys.topPegCount)
    defaults.set(Double(pegRadius), forKey: Keys.pegRadius)
    defaults.set(Double(ballRadius), forKey: Keys.ballRadius)
    defaults.set(Double(physicsGravity), forKey: Keys.physicsGravity)
    
    // Synchronize to make sure settings are saved
    defaults.synchronize()
  }
  
  // Load settings from UserDefaults
  func loadFromUserDefaults() {
    let defaults = UserDefaults.standard
    
    // Basic settings
    if defaults.object(forKey: Keys.velocityIterations) != nil {
      velocityIterations = defaults.integer(forKey: Keys.velocityIterations)
      positionIterations = defaults.integer(forKey: Keys.positionIterations)
      hz = b2Float(defaults.double(forKey: Keys.hz))
      drawShapes = defaults.bool(forKey: Keys.drawShapes)
      drawJoints = defaults.bool(forKey: Keys.drawJoints)
      drawAABBs = defaults.bool(forKey: Keys.drawAABBs)
      drawContactPoints = defaults.bool(forKey: Keys.drawContactPoints)
      drawContactNormals = defaults.bool(forKey: Keys.drawContactNormals)
      drawContactImpulse = defaults.bool(forKey: Keys.drawContactImpulse)
      drawFrictionImpulse = defaults.bool(forKey: Keys.drawFrictionImpulse)
      drawCOMs = defaults.bool(forKey: Keys.drawCOMs)
      drawStats = defaults.bool(forKey: Keys.drawStats)
      drawProfile = defaults.bool(forKey: Keys.drawProfile)
      enableWarmStarting = defaults.bool(forKey: Keys.enableWarmStarting)
      enableContinuous = defaults.bool(forKey: Keys.enableContinuous)
      enableSubStepping = defaults.bool(forKey: Keys.enableSubStepping)
      enableSleep = defaults.bool(forKey: Keys.enableSleep)
      zoomScale = Float(defaults.double(forKey: Keys.zoomScale))
      
      // Plinko settings
      pinSpacingX = b2Float(defaults.double(forKey: Keys.pinSpacingX))
      pinSpacingY = b2Float(defaults.double(forKey: Keys.pinSpacingY))
      boardRows = defaults.integer(forKey: Keys.boardRows)
      topPegCount = defaults.integer(forKey: Keys.topPegCount)
      pegRadius = b2Float(defaults.double(forKey: Keys.pegRadius))
      ballRadius = b2Float(defaults.double(forKey: Keys.ballRadius))
      physicsGravity = b2Float(defaults.double(forKey: Keys.physicsGravity))
    }
  }
  
  var viewCenter = b2Vec2(0.0, 20.0)
  var hz: b2Float = 60.0
  var velocityIterations = 8
  var positionIterations = 3
  var drawShapes = true
  var drawJoints = true
  var drawAABBs = false
  var drawContactPoints = false
  var drawContactNormals = false
  var drawContactImpulse = false
  var drawFrictionImpulse = false
  var drawCOMs = false
  var drawStats = false
  var drawProfile = false
  var enableWarmStarting = true
  var enableContinuous = true
  var enableSubStepping = false
  var enableSleep = true
  var pause = false
  var singleStep = false
  
  func calcViewBounds() -> (lower: b2Vec2, upper: b2Vec2) {
    let lower = viewCenter - Settings.extents
    let upper = viewCenter + Settings.extents
    return (lower, upper)
  }
  
  func calcTimeStep() -> b2Float {
    var timeStep: b2Float = hz > 0.0 ? b2Float(1.0) / hz : b2Float(0.0)
    if pause {
      if singleStep {
        singleStep = false
      }
      else {
        timeStep = b2Float(0.0)
      }
    }
    return timeStep
  }
  
  var debugDrawFlag : UInt32 {
    var flags: UInt32 = 0
    if drawShapes {
      flags |= b2DrawFlags.shapeBit
    }
    if drawJoints {
      flags |= b2DrawFlags.jointBit
    }
    if drawAABBs {
      flags |= b2DrawFlags.aabbBit
    }
    if drawCOMs {
      flags |= b2DrawFlags.centerOfMassBit
    }
    return flags
  }
  
  func apply(_ world: b2World) {
    world.setAllowSleeping(enableSleep)
    world.setWarmStarting(enableWarmStarting)
    world.setContinuousPhysics(enableContinuous)
    world.setSubStepping(enableSubStepping)
  }
  
  var description: String {
    return "Settings[viewCenter=\(viewCenter),hz=\(hz),velocityIterations=\(velocityIterations),positionIterations=\(positionIterations),drawShapes=\(drawShapes),drawJoints=\(drawJoints),drawAABBs=\(drawAABBs),drawContactPoints=\(drawContactPoints),drawContactNormals=\(drawContactNormals),drawFrictionImpulse=\(drawFrictionImpulse),drawCOMs=\(drawCOMs),drawStats=\(drawStats),drawProfile=\(drawProfile),enableWarmStarting=\(enableWarmStarting),enableContinuous=\(enableContinuous),enableSubStepping=\(enableSubStepping),enableSleep=\(enableSleep),pause=\(pause),singleStep=\(singleStep),zoomScale=\(zoomScale),pinSpacingX=\(pinSpacingX),pinSpacingY=\(pinSpacingY),boardRows=\(boardRows),topPegCount=\(topPegCount),pegRadius=\(pegRadius),ballRadius=\(ballRadius),physicsGravity=\(physicsGravity)]"
  }
}

struct ContactPoint {
  weak var fixtureA: b2Fixture? = nil
  weak var fixtureB: b2Fixture? = nil
  var normal = b2Vec2()
  var position = b2Vec2()
  var state = b2PointState.nullState
  var normalImpulse: b2Float = 0.0
  var tangentImpulse: b2Float = 0.0
  var separation: b2Float = 0.0
}

class QueryCallback : b2QueryCallback {
  init(point: b2Vec2) {
    self.point = point
    fixture = nil
  }
  
  func reportFixture(_ fixture: b2Fixture) -> Bool {
    let body = fixture.body
    if body.type == b2BodyType.dynamicBody {
      let inside = fixture.testPoint(self.point)
      if inside {
        self.fixture = fixture
        // We are done, terminate the query.
        return false
      }
    }
    // Continue the query.
    return true
  }
  
  var point: b2Vec2
  var fixture: b2Fixture? = nil
}

class DestructionListener : b2DestructionListener {
  func sayGoodbye(_ fixture: b2Fixture) {}
  func sayGoodbye(_ joint: b2Joint) {}
}

class ContactListener : b2ContactListener {
  var m_points = [ContactPoint]()
  
  func clearPoints() {
    m_points.removeAll(keepingCapacity: true)
  }
  
  func drawContactPoints(_ settings: Settings, renderView: RenderView) {
    if settings.drawContactPoints {
      let k_impulseScale: b2Float = 0.1
      let k_axisScale: b2Float = 0.3
      
      for point in m_points {
        if point.state == b2PointState.addState {
          // Add
          renderView.drawPoint(point.position, 10.0, b2Color(0.3, 0.95, 0.3))
        }
        else if point.state == b2PointState.persistState {
          // Persist
          renderView.drawPoint(point.position, 5.0, b2Color(0.3, 0.3, 0.95))
        }
        
        if settings.drawContactNormals {
          let p1 = point.position
          let p2 = p1 + k_axisScale * point.normal
          renderView.drawSegment(p1, p2, b2Color(0.9, 0.9, 0.9))
        }
        else if settings.drawContactImpulse {
          let p1 = point.position
          let p2 = p1 + k_impulseScale * point.normalImpulse * point.normal
          renderView.drawSegment(p1, p2, b2Color(0.9, 0.9, 0.3))
        }
        
        if settings.drawFrictionImpulse {
          let tangent = b2Cross(point.normal, 1.0)
          let p1 = point.position
          let p2 = p1 + k_impulseScale * point.tangentImpulse * tangent
          renderView.drawSegment(p1, p2, b2Color(0.9, 0.9, 0.3))
        }
      }
    }
  }
  
  func beginContact(_ contact : b2Contact) {}
  func endContact(_ contact: b2Contact) {}
  
  func preSolve(_ contact: b2Contact, oldManifold: b2Manifold) {
    let manifold = contact.manifold
    if manifold.pointCount == 0 {
      return
    }
    
    let fixtureA = contact.fixtureA
    let fixtureB = contact.fixtureB
    let (_/*state1*/, state2) = b2GetPointStates(manifold1: oldManifold, manifold2: manifold)
    let worldManifold = contact.worldManifold
    
    for i in 0 ..< manifold.pointCount {
      var cp = ContactPoint()
      cp.fixtureA = fixtureA
      cp.fixtureB = fixtureB
      cp.position = worldManifold.points[i]
      cp.normal = worldManifold.normal
      cp.state = state2[i]
      cp.normalImpulse = manifold.points[i].normalImpulse
      cp.tangentImpulse = manifold.points[i].tangentImpulse
      cp.separation = worldManifold.separations[i]
      m_points.append(cp)
    }
  }
  
  func postSolve(_ contact: b2Contact, impulse: b2ContactImpulse) {}
}


private let fieldFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)

func createLabelField(labelWithString: String) -> NSTextField {
  let textField = NSTextField(labelWithString: labelWithString)
  textField.font = fieldFont
  textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
  return textField
}

func createValueField(labelWithString: String) -> NSTextField {
  let textField = NSTextField(labelWithString: labelWithString)
  textField.font = fieldFont
  textField.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true
  return textField
}
