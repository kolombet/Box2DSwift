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

import Foundation

let testCases: [TestCase.Type] = [
  Plinko.self,
// Add other test cases as needed
]

// This section demonstrates how to run a headless simulation
// Uncomment to run the headless example when needed
/*
func runHeadlessExample() {
  print("Running headless Plinko simulation...")
  HeadlessPlinkoExample.main()
  print("Headless simulation complete.")
}
*/

// AddPair.self,
//   ApplyForce.self,
//   BodyTypes.self,
//   Bridge.self,
//   Bullet.self,
//   Cantilever.self,
//   Car.self,
//   CharacterCollision.self,
//   CollisionFiltering.self,
//   CollisionProcessing.self,
//   CompoundShapes.self,
//   Confined.self,
//   ContinuousTest.self,
//   ConveyorBelt.self,
//   DistanceTest.self,
//   Dominos.self,
//   DumpShell.self,
//   EdgeShapes.self,
//   EdgeTest.self,
//   Gear.self,
//   MotorJoint.self,
//   OneSidedPlatform.self,
//   Pinball.self,
//   PolyCollision.self,
//   PolyShapes.self,
//   Pulleys.self,
//   Pyramid.self,
//   RayCast.self,
//   Revolute.self,
//   RopeJoint.self,
//   SensorTest.self,
//   ShapeEditing.self,
//   SliderCrank.self,
//   SphereStack.self,
//   Tiles.self,
//   Tumbler.self,
//   VaryingFriction.self,
//   VerticalStack.self,
//   Web.self,
