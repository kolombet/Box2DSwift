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

protocol SettingViewControllerDelegate: AnyObject {
  func didSettingsChanged(_ settings: Settings)
}

class SettingsViewController: NSTabViewController {
  static let lastPreferencesPaneIdentifier = "SettingsViewController.lastPreferencesPaneIdentifier"
  static let inset: CGFloat = 16
  var lastFrameSize: NSSize = .zero
  
  // Save button for applying and persisting settings
  private var saveButton: NSButton?

  weak var settings: Settings? = nil {
    didSet {
      basicSettingsViewController.settings = settings
      drawSettingsViewController.settings = settings
      plinkoSettingsViewController.settings = settings
    }
  }
  weak var delegate: SettingViewControllerDelegate? = nil {
    didSet {
      basicSettingsViewController.delegate = delegate
      drawSettingsViewController.delegate = delegate
      plinkoSettingsViewController.delegate = delegate
    }
  }

  lazy var basicSettingsViewController = BasicSettingsViewController()
  lazy var drawSettingsViewController = DrawSettingsViewController()
  lazy var plinkoSettingsViewController = PlinkoSettingsViewController()

  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.tabStyle = .toolbar
    
    let basicItem = NSTabViewItem(viewController: basicSettingsViewController)
    basicItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)!
    basicItem.label = "Basic"
    addTabViewItem(basicItem)
    
    let drawItem = NSTabViewItem(viewController: drawSettingsViewController)
    drawItem.image = NSImage(systemSymbolName: "pencil", accessibilityDescription: nil)!
    drawItem.label = "Draw"
    addTabViewItem(drawItem)
    
    let plinkoItem = NSTabViewItem(viewController: plinkoSettingsViewController)
    plinkoItem.image = NSImage(systemSymbolName: "circle.grid.2x2", accessibilityDescription: nil)!
    plinkoItem.label = "Plinko"
    addTabViewItem(plinkoItem)
    
    if let identifier = UserDefaults.standard.object(forKey: SettingsViewController.lastPreferencesPaneIdentifier) as? String {
      for i in 0 ..< tabViewItems.count {
        let item = tabViewItems[i]
        if item.identifier as? String == identifier {
          selectedTabViewItemIndex = i
        }
      }
    }
    
    // Setup Save & Apply button
    setupSaveButton()
  }

  override var selectedTabViewItemIndex: Int {
    didSet {
      if self.isViewLoaded {
        UserDefaults.standard.set(self.tabViewItems[selectedTabViewItemIndex].identifier as? String, forKey: SettingsViewController.lastPreferencesPaneIdentifier)
      }
    }
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    
    self.view.window!.title = self.tabViewItems[self.selectedTabViewItemIndex].label
  }

  override func viewDidAppear() {
    super.viewDidAppear()
    if let window = view.window {
      window.styleMask.remove(.resizable)
    }
  }
  
  override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
    super.tabView(tabView, willSelect: tabViewItem)
    
    if let size = tabViewItem?.view?.frame.size {
      lastFrameSize = size
    }
  }
  
  override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
    super.tabView(tabView, willSelect: tabViewItem)
    
    guard let tabViewItem = tabViewItem else { return assertionFailure() }
    
    self.switchPane(to: tabViewItem)
  }
  
  private func switchPane(to tabViewItem: NSTabViewItem) {
    guard let gridView = tabViewItem.view?.subviews.first as? NSGridView else {
      return assertionFailure()
    }
    let inset = SettingsViewController.inset
    let gridViewSize = gridView.fittingSize
    let contentSize = NSSize(width: gridViewSize.width + inset*2,
                             height: gridViewSize.height + inset*2);
    
    guard let window = self.view.window else {
      self.view.frame.size = contentSize
      return
    }
    
    NSAnimationContext.runAnimationGroup({ _ in
      self.view.isHidden = true
      
      let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
      let frame = NSRect(origin: window.frame.origin, size: frameSize)
        .offsetBy(dx: 0, dy: window.frame.height - frameSize.height)
      window.animator().setFrame(frame, display: false)
      
    }, completionHandler: { [weak self] in
      self?.view.isHidden = false
      window.title = tabViewItem.label
    })
  }
  
  private func setupSaveButton() {
    // Button is now created in PlinkoSettingsViewController directly in the grid
    // This method is kept for backward compatibility but does nothing
  }
  
  @objc func saveAndApplySettings() {
    guard let settings = settings else { return }
    
    // Save settings to UserDefaults
    settings.saveToUserDefaults()
    
    // Reload settings from UserDefaults to ensure all values are updated
    settings.loadFromUserDefaults()
    
    // Apply settings immediately
    delegate?.didSettingsChanged(settings)
    
    // Provide visual feedback on the button if available
    if let button = view.window?.contentView?.subviews.first(where: { $0 is NSButton && ($0 as? NSButton)?.title == "Save & Apply" }) as? NSButton {
      let originalTitle = button.title
      button.title = "Saved!"
      
      // Reset button title after a short delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        button.title = originalTitle
      }
    }
  }
}

class BasicSettingsViewController : NSViewController {
  weak var settings: Settings? = nil {
    didSet {
      guard let settings else { return }
      velocityIterationsField.integerValue = settings.velocityIterations
      positionIterationsField.integerValue = settings.positionIterations
      hertzPopupButton.selectItem(at: settings.hz == 30.0 ? 1 : 0)
      sleepSwitch.state = settings.enableSleep ? .on : .off
      warmStartingSwitch.state = settings.enableWarmStarting ? .on : .off
      timeOfImpactSwitch.state = settings.enableContinuous ? .on : .off
      subSteppingSwitch.state = settings.enableSubStepping ? .on : .off
    }
  }
  weak var delegate: SettingViewControllerDelegate? = nil

  // MARK: row 1: Velocity Iterations
  let velocityIterationsField = NSTextField(string: "8")
  let velocityIterationsStepper = NSStepper(frame: .zero)

  @objc func onVelocityIterationsStepperAction(sender: NSStepper) {
    guard let settings else { return }
    
    view.window?.makeFirstResponder(velocityIterationsField)
    velocityIterationsField.integerValue = velocityIterationsStepper.integerValue
    
    settings.velocityIterations = positionIterationsField.integerValue
    delegate?.didSettingsChanged(settings)
  }

  @objc func onVelocityIterationsFieldChanged(sender: NSTextField) {
    guard let settings else { return }
    settings.velocityIterations = velocityIterationsField.integerValue
    delegate?.didSettingsChanged(settings)
  }
  
  // MARK: row 2: Position Iterations
  let positionIterationsField = NSTextField(string: "3")
  let positionIterationsStepper = NSStepper(frame: .zero)

  @objc func onPositionIterationsStepperAction(sender: NSStepper) {
    guard let settings else { return }
    
    view.window?.makeFirstResponder(positionIterationsField)
    positionIterationsField.integerValue = positionIterationsStepper.integerValue
    
    settings.positionIterations = positionIterationsField.integerValue
    delegate?.didSettingsChanged(settings)
  }

  @objc func onPositionIterationsFieldChanged(sender: NSTextField) {
    guard let settings else { return }
    settings.positionIterations = positionIterationsField.integerValue
    delegate?.didSettingsChanged(settings)
  }

  // MARK: row 3: Hertz
  let hertzPopupButton = NSPopUpButton(frame: .zero, pullsDown: false)

  @objc func onHertzPopupButtonAction(sender: NSPopUpButton) {
    guard let settings else { return }
    settings.hz = hertzPopupButton.indexOfSelectedItem == 1 ? 30 : 60
    delegate?.didSettingsChanged(settings)
  }

  // MARK: row 4: Sleep
  let sleepLabel = NSTextField(labelWithString: "Sleep:")
  
  lazy var sleepSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(BasicSettingsViewController.onSleepChanged)
    return ctl
  }()

  @objc func onSleepChanged(sender: Any) {
    guard let settings else { return }
    settings.enableSleep = sleepSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }
  
  // MARK: row 5: Warm Start
  let warmStartingLabel = NSTextField(labelWithString: "Warm Starting:")
  
  lazy var warmStartingSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(BasicSettingsViewController.onWarmStartChanged)
    return ctl
  }()

  @objc func onWarmStartChanged(sender: Any) {
    guard let settings else { return }
    settings.enableWarmStarting = warmStartingSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }
  
  // MARK: row 6: Time of Impact
  let timeOfImpactLabel = NSTextField(labelWithString: "Time of Impact:")
  
  lazy var timeOfImpactSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(BasicSettingsViewController.onTimeOfImpactChanged)
    return ctl
  }()
  
  @objc func onTimeOfImpactChanged(sender: Any) {
    guard let settings else { return }
    settings.enableContinuous = timeOfImpactSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }
  
  // MARK: row 7: Sub-Stepping
  let subSteppingLabel = NSTextField(labelWithString: "Sub-Stepping:")
  
  lazy var subSteppingSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(BasicSettingsViewController.onSubSteppingChanged)
    return ctl
  }()
  
  @objc func onSubSteppingChanged(sender: Any) {
    guard let settings else { return }
    settings.enableSubStepping = subSteppingSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }

  // MARK: loadView
  override func loadView() {
    view = NSView(frame: .zero)
  }

  // MARK: viewDidLoad
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = "Basic"
    
    // MARK: row 1: Velocity Iterations
    let velocityIterationsLabel = NSTextField(labelWithString: "Velocity Iterations:")
    
    velocityIterationsField.formatter = NumberFormatter()
    velocityIterationsField.placeholderString = "8"
    velocityIterationsField.target = self
    velocityIterationsField.action = #selector(onVelocityIterationsFieldChanged)
    velocityIterationsField.widthAnchor.constraint(equalToConstant: 80).isActive = true
    
    velocityIterationsStepper.minValue = 0
    velocityIterationsStepper.maxValue = 100
    velocityIterationsStepper.increment = 1
    velocityIterationsStepper.integerValue = 8
    velocityIterationsStepper.valueWraps = false
    velocityIterationsStepper.target = self
    velocityIterationsStepper.action = #selector(onVelocityIterationsStepperAction)

    let velocityIterationsStack = NSStackView(views: [velocityIterationsField, velocityIterationsStepper])
    velocityIterationsStack.orientation = .horizontal
    velocityIterationsStack.spacing = 8
    velocityIterationsStack.setHuggingPriority(.defaultHigh, for: .horizontal)
    
    // MARK: row 2: Position Iterations
    let positionIterationsLabel = NSTextField(labelWithString: "Position Iterations:")
    
    positionIterationsField.formatter = NumberFormatter()
    positionIterationsField.placeholderString = "3"
    positionIterationsField.target = self
    positionIterationsField.action = #selector(onPositionIterationsFieldChanged)
    positionIterationsField.widthAnchor.constraint(equalToConstant: 80).isActive = true
    
    positionIterationsStepper.minValue = 0
    positionIterationsStepper.maxValue = 100
    positionIterationsStepper.increment = 1
    positionIterationsStepper.integerValue = 3
    positionIterationsStepper.valueWraps = false
    positionIterationsStepper.target = self
    positionIterationsStepper.action = #selector(onPositionIterationsStepperAction)

    let positionIterationsStack = NSStackView(views: [positionIterationsField, positionIterationsStepper])
    positionIterationsStack.orientation = .horizontal
    positionIterationsStack.spacing = 8
    positionIterationsStack.setHuggingPriority(.defaultHigh, for: .horizontal)

    // MARK: row 3: Hertz
    let hertzLabel = NSTextField(labelWithString: "Hertz:")

    hertzPopupButton.addItems(withTitles: ["60 Hz", "30 Hz"])
    hertzPopupButton.target = self
    hertzPopupButton.action = #selector(onHertzPopupButtonAction)
    
    // Set switch control size
    sleepSwitch.controlSize = .regular
    warmStartingSwitch.controlSize = .regular
    timeOfImpactSwitch.controlSize = .regular
    subSteppingSwitch.controlSize = .regular
    
    // Create Save & Apply button
    let saveApplyButton = NSButton(title: "Save & Apply", target: nil, action: nil)
    saveApplyButton.bezelStyle = .rounded
    saveApplyButton.target = self.parent
    saveApplyButton.action = #selector(SettingsViewController.saveAndApplySettings)
    
    let gridView = NSGridView(views: [
      [velocityIterationsLabel, velocityIterationsStack],
      [positionIterationsLabel, positionIterationsStack],
      [hertzLabel, hertzPopupButton],
      [sleepLabel, sleepSwitch],
      [warmStartingLabel, warmStartingSwitch],
      [timeOfImpactLabel, timeOfImpactSwitch],
      [subSteppingLabel, subSteppingSwitch],
      [NSView(), saveApplyButton], // Add button directly to the grid
    ])
    
    // Center the button in the cell
    gridView.cell(atColumnIndex: 1, rowIndex: 7).xPlacement = .center
    
    // Set a height for the spacer row
    gridView.row(at: 7).height = 60
    
    // Make column 1 (with the controls) expand to fill available space
    gridView.column(at: 1).xPlacement = .fill
    
    // Center the switches horizontally
    for row in 3..<7 {
      gridView.cell(atColumnIndex: 1, rowIndex: row).xPlacement = .center
    }
    
    gridView.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(600),
                                                     for: .horizontal)
    gridView.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(600),
                                                     for: .vertical)
    gridView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    gridView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(gridView)
    let inset = SettingsViewController.inset
    NSLayoutConstraint.activate([
      gridView.topAnchor.constraint(equalTo: view.topAnchor, constant: inset),
      gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: inset),
      view.bottomAnchor.constraint(greaterThanOrEqualTo: gridView.bottomAnchor, constant: inset),
      view.trailingAnchor.constraint(greaterThanOrEqualTo: gridView.trailingAnchor, constant: inset),
      gridView.widthAnchor.constraint(greaterThanOrEqualToConstant: 350),
    ])
    
    gridView.column(at: 0).xPlacement = .trailing
    gridView.rowSpacing = 12
    gridView.columnSpacing = 16
  }
}

class DrawSettingsViewController : NSViewController {
  weak var settings: Settings? = nil {
    didSet {
      guard let settings else { return }
      shapesSwitch.state = settings.drawShapes ? .on : .off
      jointsSwitch.state = settings.drawJoints ? .on : .off
      aabbsSwitch.state = settings.drawAABBs ? .on : .off
      contactPointsSwitch.state = settings.drawContactPoints ? .on : .off
      contactNormalsSwitch.state = settings.drawContactNormals ? .on : .off
      contactImpulsesSwitch.state = settings.drawContactImpulse ? .on : .off
      frictionImpulsesSwitch.state = settings.drawFrictionImpulse ? .on : .off
      centerOfMassesSwitch.state = settings.drawCOMs ? .on : .off
      statisticsSwitch.state = settings.drawStats ? .on : .off
      profileSwitch.state = settings.drawProfile ? .on : .off
      zoomSlider.floatValue = settings.zoomScale
      zoomTextField.stringValue = String(format: "%.1f", settings.zoomScale)
    }
  }
  weak var delegate: SettingViewControllerDelegate? = nil
  
  // MARK: row 1: Shapes
  let shapesLabel = NSTextField(labelWithString: "Shapes:")

  lazy var shapesSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(DrawSettingsViewController.onShapesChanged)
    return ctl
  }()

  @objc func onShapesChanged(sender: Any) {
    guard let settings else { return }
    settings.drawShapes = shapesSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }

  // MARK: row 2: Joints
  let jointsLabel = NSTextField(labelWithString: "Joints:")
  
  lazy var jointsSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(DrawSettingsViewController.onJointsChanged)
    return ctl
  }()

  @objc func onJointsChanged(sender: Any) {
    guard let settings else { return }
    settings.drawJoints = jointsSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }

  // MARK: row 3: AABBs
  let aabbsLabel = NSTextField(labelWithString: "AABBs:")

  lazy var aabbsSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(DrawSettingsViewController.onAABBsChanged)
    return ctl
  }()

  @objc func onAABBsChanged(sender: Any) {
    guard let settings else { return }
    settings.drawAABBs = aabbsSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }

  // MARK: row 4: Contact Points
  let contactPointsLabel = NSTextField(labelWithString: "Contact Points:")
  
  lazy var contactPointsSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(DrawSettingsViewController.onContactPointsChanged)
    return ctl
  }()

  @objc func onContactPointsChanged(sender: Any) {
    guard let settings else { return }
    settings.drawContactPoints = contactPointsSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }

  // MARK: row 5: Contact Normals
  let contactNormalsLabel = NSTextField(labelWithString: "Contact Normals:")
  
  lazy var contactNormalsSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(DrawSettingsViewController.onContactNormalsChanged)
    return ctl
  }()
  
  @objc func onContactNormalsChanged(sender: Any) {
    guard let settings else { return }
    settings.drawContactNormals = contactNormalsSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }

  // MARK: row 6: Contact Impulses
  let contactImpulsesLabel = NSTextField(labelWithString: "Contact Impulses:")
  
  lazy var contactImpulsesSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(DrawSettingsViewController.onContactImpulsesChanged)
    return ctl
  }()
  
  @objc func onContactImpulsesChanged(sender: Any) {
    guard let settings else { return }
    settings.drawContactImpulse = contactImpulsesSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }

  // MARK: row 7: Friction Impulses
  let frictionImpulsesLabel = NSTextField(labelWithString: "Friction Impulses:")
  
  lazy var frictionImpulsesSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(DrawSettingsViewController.onFrictionImpulsesChanged)
    return ctl
  }()
  
  @objc func onFrictionImpulsesChanged(sender: Any) {
    guard let settings else { return }
    settings.drawFrictionImpulse = frictionImpulsesSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }

  // MARK: row 8: Center of Masses
  let centerOfMassesLabel = NSTextField(labelWithString: "Center of Masses:")
  
  lazy var centerOfMassesSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(DrawSettingsViewController.onCenterOfMassesChanged)
    return ctl
  }()
  
  @objc func onCenterOfMassesChanged(sender: Any) {
    guard let settings else { return }
    settings.drawCOMs = centerOfMassesSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }

  // MARK: row 9: Statistics
  let statisticsLabel = NSTextField(labelWithString: "Statistics:")
  
  lazy var statisticsSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(DrawSettingsViewController.onStatisticsChanged)
    return ctl
  }()
  
  @objc func onStatisticsChanged(sender: Any) {
    guard let settings else { return }
    settings.drawStats = statisticsSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }

  // MARK: row 10: Profile
  let profileLabel = NSTextField(labelWithString: "Profile:")
  
  lazy var profileSwitch = { () -> NSSwitch in
    let ctl = NSSwitch(frame: .zero)
    ctl.target = self
    ctl.action = #selector(DrawSettingsViewController.onProfileChanged)
    return ctl
  }()
  
  @objc func onProfileChanged(sender: Any) {
    guard let settings else { return }
    settings.drawProfile = profileSwitch.state == .on
    delegate?.didSettingsChanged(settings)
  }

  // MARK: zoom scale controls
  let zoomLabel = NSTextField(labelWithString: "Zoom Scale:")
  let zoomTextField = NSTextField(string: "1.0")
  let zoomSlider = NSSlider(value: 10.0, minValue: 0.1, maxValue: 100.0, target: nil, action: nil)
  
  @objc func onZoomSliderChanged(_ sender: NSSlider) {
    guard let settings else { return }
    let scale = sender.floatValue
    settings.zoomScale = scale
    zoomTextField.stringValue = String(format: "%.1f", scale)
    delegate?.didSettingsChanged(settings)
  }
  
  @objc func onZoomTextFieldChanged(_ sender: NSTextField) {
    guard let settings else { return }
    if let scale = Float(sender.stringValue) {
      settings.zoomScale = scale
      zoomSlider.floatValue = scale
      delegate?.didSettingsChanged(settings)
    }
  }

  override func loadView() {
    view = NSView(frame: .zero)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = "Draw"
    
    zoomSlider.target = self
    zoomSlider.action = #selector(onZoomSliderChanged)
    zoomTextField.formatter = NumberFormatter()
    zoomTextField.target = self
    zoomTextField.action = #selector(onZoomTextFieldChanged)
    zoomTextField.widthAnchor.constraint(equalToConstant: 60).isActive = true
    
    let zoomContainer = NSStackView(views: [zoomSlider, zoomTextField])
    zoomContainer.orientation = .horizontal
    zoomContainer.spacing = 8
    
    // Make the slider take all available width
    zoomSlider.translatesAutoresizingMaskIntoConstraints = false
    zoomSlider.setContentHuggingPriority(.defaultLow, for: .horizontal)
    zoomContainer.setHuggingPriority(.defaultHigh, for: .horizontal)
    
    // Adjust the switch controls to be centered
    shapesSwitch.controlSize = .regular
    jointsSwitch.controlSize = .regular
    aabbsSwitch.controlSize = .regular
    contactPointsSwitch.controlSize = .regular
    contactNormalsSwitch.controlSize = .regular
    contactImpulsesSwitch.controlSize = .regular
    frictionImpulsesSwitch.controlSize = .regular
    centerOfMassesSwitch.controlSize = .regular
    statisticsSwitch.controlSize = .regular
    profileSwitch.controlSize = .regular
    
    // Create Save & Apply button
    let saveApplyButton = NSButton(title: "Save & Apply", target: nil, action: nil)
    saveApplyButton.bezelStyle = .rounded
    saveApplyButton.target = self.parent
    saveApplyButton.action = #selector(SettingsViewController.saveAndApplySettings)
    
    let gridView = NSGridView(views: [
      [shapesLabel, shapesSwitch],
      [jointsLabel, jointsSwitch],
      [aabbsLabel, aabbsSwitch],
      [contactPointsLabel, contactPointsSwitch],
      [contactNormalsLabel, contactNormalsSwitch],
      [contactImpulsesLabel, contactImpulsesSwitch],
      [frictionImpulsesLabel, frictionImpulsesSwitch],
      [centerOfMassesLabel, centerOfMassesSwitch],
      [statisticsLabel, statisticsSwitch],
      [profileLabel, profileSwitch],
      [zoomLabel, zoomContainer],
      [NSView(), saveApplyButton], // Add button directly to the grid
    ])
    
    // Center the button in the cell
    gridView.cell(atColumnIndex: 1, rowIndex: 11).xPlacement = .center
    
    // Set a height for the spacer row
    gridView.row(at: 11).height = 60
    
    // Make column 1 (with the controls) expand to fill available space
    gridView.column(at: 1).xPlacement = .fill
    
    // Center the switches horizontally
    for row in 0..<10 {
      gridView.cell(atColumnIndex: 1, rowIndex: row).xPlacement = .center
    }
    
    // Set minimum width for the window to be more reasonable
    gridView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    gridView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    
    gridView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(gridView)
    
    let inset = SettingsViewController.inset
    NSLayoutConstraint.activate([
      gridView.topAnchor.constraint(equalTo: view.topAnchor, constant: inset),
      gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: inset),
      view.bottomAnchor.constraint(greaterThanOrEqualTo: gridView.bottomAnchor, constant: inset + 50),
      view.trailingAnchor.constraint(greaterThanOrEqualTo: gridView.trailingAnchor, constant: inset),
      gridView.widthAnchor.constraint(greaterThanOrEqualToConstant: 350),
    ])
    gridView.column(at: 0).xPlacement = .trailing
    gridView.rowSpacing = 12
    gridView.columnSpacing = 16
  }
  
}

class PlinkoSettingsViewController : NSViewController {
  weak var settings: Settings? = nil {
    didSet {
      guard let settings else { return }
      pinSpacingXField.floatValue = settings.pinSpacingX
      pinSpacingYField.floatValue = settings.pinSpacingY
      boardRowsField.integerValue = settings.boardRows
      topPegCountField.integerValue = settings.topPegCount
      pegRadiusField.floatValue = settings.pegRadius
      ballRadiusField.floatValue = settings.ballRadius
      gravityField.floatValue = settings.physicsGravity
    }
  }
  weak var delegate: SettingViewControllerDelegate? = nil
  
  // MARK: row 1: Pin Spacing X
  let pinSpacingXLabel = NSTextField(labelWithString: "Pin Spacing X:")
  let pinSpacingXField = NSTextField(string: "15.0")
  let pinSpacingXStepper = NSStepper(frame: .zero)
  
  @objc func onPinSpacingXStepperAction(sender: NSStepper) {
    guard let settings else { return }
    view.window?.makeFirstResponder(pinSpacingXField)
    pinSpacingXField.floatValue = pinSpacingXStepper.floatValue
    settings.pinSpacingX = pinSpacingXField.floatValue
    delegate?.didSettingsChanged(settings)
  }
  
  @objc func onPinSpacingXFieldChanged(sender: NSTextField) {
    guard let settings else { return }
    settings.pinSpacingX = pinSpacingXField.floatValue
    delegate?.didSettingsChanged(settings)
  }
  
  // MARK: row 2: Pin Spacing Y
  let pinSpacingYLabel = NSTextField(labelWithString: "Pin Spacing Y:")
  let pinSpacingYField = NSTextField(string: "15.0")
  let pinSpacingYStepper = NSStepper(frame: .zero)
  
  @objc func onPinSpacingYStepperAction(sender: NSStepper) {
    guard let settings else { return }
    view.window?.makeFirstResponder(pinSpacingYField)
    pinSpacingYField.floatValue = pinSpacingYStepper.floatValue
    settings.pinSpacingY = pinSpacingYField.floatValue
    delegate?.didSettingsChanged(settings)
  }
  
  @objc func onPinSpacingYFieldChanged(sender: NSTextField) {
    guard let settings else { return }
    settings.pinSpacingY = pinSpacingYField.floatValue
    delegate?.didSettingsChanged(settings)
  }
  
  // MARK: row 3: Board Rows
  let boardRowsLabel = NSTextField(labelWithString: "Board Rows:")
  let boardRowsField = NSTextField(string: "13")
  let boardRowsStepper = NSStepper(frame: .zero)
  
  @objc func onBoardRowsStepperAction(sender: NSStepper) {
    guard let settings else { return }
    view.window?.makeFirstResponder(boardRowsField)
    boardRowsField.integerValue = boardRowsStepper.integerValue
    settings.boardRows = boardRowsField.integerValue
    delegate?.didSettingsChanged(settings)
  }
  
  @objc func onBoardRowsFieldChanged(sender: NSTextField) {
    guard let settings else { return }
    settings.boardRows = boardRowsField.integerValue
    delegate?.didSettingsChanged(settings)
  }
  
  // MARK: row 4: Top Peg Count
  let topPegCountLabel = NSTextField(labelWithString: "Top Peg Count:")
  let topPegCountField = NSTextField(string: "4")
  let topPegCountStepper = NSStepper(frame: .zero)
  
  @objc func onTopPegCountStepperAction(sender: NSStepper) {
    guard let settings else { return }
    view.window?.makeFirstResponder(topPegCountField)
    topPegCountField.integerValue = topPegCountStepper.integerValue
    settings.topPegCount = topPegCountField.integerValue
    delegate?.didSettingsChanged(settings)
  }
  
  @objc func onTopPegCountFieldChanged(sender: NSTextField) {
    guard let settings else { return }
    settings.topPegCount = topPegCountField.integerValue
    delegate?.didSettingsChanged(settings)
  }
  
  // MARK: row 5: Peg Radius
  let pegRadiusLabel = NSTextField(labelWithString: "Peg Radius:")
  let pegRadiusField = NSTextField(string: "3.0")
  let pegRadiusStepper = NSStepper(frame: .zero)
  
  @objc func onPegRadiusStepperAction(sender: NSStepper) {
    guard let settings else { return }
    view.window?.makeFirstResponder(pegRadiusField)
    pegRadiusField.floatValue = pegRadiusStepper.floatValue
    settings.pegRadius = pegRadiusField.floatValue
    delegate?.didSettingsChanged(settings)
  }
  
  @objc func onPegRadiusFieldChanged(sender: NSTextField) {
    guard let settings else { return }
    settings.pegRadius = pegRadiusField.floatValue
    delegate?.didSettingsChanged(settings)
  }
  
  // MARK: row 6: Ball Radius
  let ballRadiusLabel = NSTextField(labelWithString: "Ball Radius:")
  let ballRadiusField = NSTextField(string: "6.0")
  let ballRadiusStepper = NSStepper(frame: .zero)
  
  @objc func onBallRadiusStepperAction(sender: NSStepper) {
    guard let settings else { return }
    view.window?.makeFirstResponder(ballRadiusField)
    ballRadiusField.floatValue = ballRadiusStepper.floatValue
    settings.ballRadius = ballRadiusField.floatValue
    delegate?.didSettingsChanged(settings)
  }
  
  @objc func onBallRadiusFieldChanged(sender: NSTextField) {
    guard let settings else { return }
    settings.ballRadius = ballRadiusField.floatValue
    delegate?.didSettingsChanged(settings)
  }
  
  // MARK: row 7: Physics Gravity
  let gravityLabel = NSTextField(labelWithString: "Physics Gravity:")
  let gravityField = NSTextField(string: "-200.0")
  let gravityStepper = NSStepper(frame: .zero)
  
  @objc func onGravityStepperAction(sender: NSStepper) {
    guard let settings else { return }
    view.window?.makeFirstResponder(gravityField)
    gravityField.floatValue = gravityStepper.floatValue
    settings.physicsGravity = gravityField.floatValue
    delegate?.didSettingsChanged(settings)
  }
  
  @objc func onGravityFieldChanged(sender: NSTextField) {
    guard let settings else { return }
    settings.physicsGravity = gravityField.floatValue
    delegate?.didSettingsChanged(settings)
  }
  
  override func loadView() {
    view = NSView(frame: .zero)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = "Plinko"
    
    // Configure Pin Spacing X
    pinSpacingXField.formatter = NumberFormatter()
    pinSpacingXField.placeholderString = "15.0"
    pinSpacingXField.target = self
    pinSpacingXField.action = #selector(onPinSpacingXFieldChanged)
    pinSpacingXField.widthAnchor.constraint(equalToConstant: 80).isActive = true
    
    pinSpacingXStepper.minValue = 5.0
    pinSpacingXStepper.maxValue = 50.0
    pinSpacingXStepper.increment = 1.0
    pinSpacingXStepper.floatValue = 15.0
    pinSpacingXStepper.valueWraps = false
    pinSpacingXStepper.target = self
    pinSpacingXStepper.action = #selector(onPinSpacingXStepperAction)
    
    let pinSpacingXStack = NSStackView(views: [pinSpacingXField, pinSpacingXStepper])
    pinSpacingXStack.orientation = .horizontal
    pinSpacingXStack.spacing = 8
    pinSpacingXStack.setHuggingPriority(.defaultHigh, for: .horizontal)
    
    // Configure Pin Spacing Y
    pinSpacingYField.formatter = NumberFormatter()
    pinSpacingYField.placeholderString = "15.0"
    pinSpacingYField.target = self
    pinSpacingYField.action = #selector(onPinSpacingYFieldChanged)
    pinSpacingYField.widthAnchor.constraint(equalToConstant: 80).isActive = true
    
    pinSpacingYStepper.minValue = 5.0
    pinSpacingYStepper.maxValue = 50.0
    pinSpacingYStepper.increment = 1.0
    pinSpacingYStepper.floatValue = 15.0
    pinSpacingYStepper.valueWraps = false
    pinSpacingYStepper.target = self
    pinSpacingYStepper.action = #selector(onPinSpacingYStepperAction)
    
    let pinSpacingYStack = NSStackView(views: [pinSpacingYField, pinSpacingYStepper])
    pinSpacingYStack.orientation = .horizontal
    pinSpacingYStack.spacing = 8
    pinSpacingYStack.setHuggingPriority(.defaultHigh, for: .horizontal)
    
    // Configure Board Rows
    boardRowsField.formatter = NumberFormatter()
    boardRowsField.placeholderString = "13"
    boardRowsField.target = self
    boardRowsField.action = #selector(onBoardRowsFieldChanged)
    boardRowsField.widthAnchor.constraint(equalToConstant: 80).isActive = true
    
    boardRowsStepper.minValue = 5
    boardRowsStepper.maxValue = 30
    boardRowsStepper.increment = 1
    boardRowsStepper.integerValue = 13
    boardRowsStepper.valueWraps = false
    boardRowsStepper.target = self
    boardRowsStepper.action = #selector(onBoardRowsStepperAction)
    
    let boardRowsStack = NSStackView(views: [boardRowsField, boardRowsStepper])
    boardRowsStack.orientation = .horizontal
    boardRowsStack.spacing = 8
    boardRowsStack.setHuggingPriority(.defaultHigh, for: .horizontal)
    
    // Configure Top Peg Count
    topPegCountField.formatter = NumberFormatter()
    topPegCountField.placeholderString = "4"
    topPegCountField.target = self
    topPegCountField.action = #selector(onTopPegCountFieldChanged)
    topPegCountField.widthAnchor.constraint(equalToConstant: 80).isActive = true
    
    topPegCountStepper.minValue = 2
    topPegCountStepper.maxValue = 20
    topPegCountStepper.increment = 1
    topPegCountStepper.integerValue = 4
    topPegCountStepper.valueWraps = false
    topPegCountStepper.target = self
    topPegCountStepper.action = #selector(onTopPegCountStepperAction)
    
    let topPegCountStack = NSStackView(views: [topPegCountField, topPegCountStepper])
    topPegCountStack.orientation = .horizontal
    topPegCountStack.spacing = 8
    topPegCountStack.setHuggingPriority(.defaultHigh, for: .horizontal)
    
    // Configure Peg Radius
    pegRadiusField.formatter = NumberFormatter()
    pegRadiusField.placeholderString = "3.0"
    pegRadiusField.target = self
    pegRadiusField.action = #selector(onPegRadiusFieldChanged)
    pegRadiusField.widthAnchor.constraint(equalToConstant: 80).isActive = true
    
    pegRadiusStepper.minValue = 0.5
    pegRadiusStepper.maxValue = 10.0
    pegRadiusStepper.increment = 0.5
    pegRadiusStepper.floatValue = 3.0
    pegRadiusStepper.valueWraps = false
    pegRadiusStepper.target = self
    pegRadiusStepper.action = #selector(onPegRadiusStepperAction)
    
    let pegRadiusStack = NSStackView(views: [pegRadiusField, pegRadiusStepper])
    pegRadiusStack.orientation = .horizontal
    pegRadiusStack.spacing = 8
    pegRadiusStack.setHuggingPriority(.defaultHigh, for: .horizontal)
    
    // Configure Ball Radius
    ballRadiusField.formatter = NumberFormatter()
    ballRadiusField.placeholderString = "6.0"
    ballRadiusField.target = self
    ballRadiusField.action = #selector(onBallRadiusFieldChanged)
    ballRadiusField.widthAnchor.constraint(equalToConstant: 80).isActive = true
    
    ballRadiusStepper.minValue = 1.0
    ballRadiusStepper.maxValue = 15.0
    ballRadiusStepper.increment = 0.5
    ballRadiusStepper.floatValue = 6.0
    ballRadiusStepper.valueWraps = false
    ballRadiusStepper.target = self
    ballRadiusStepper.action = #selector(onBallRadiusStepperAction)
    
    let ballRadiusStack = NSStackView(views: [ballRadiusField, ballRadiusStepper])
    ballRadiusStack.orientation = .horizontal
    ballRadiusStack.spacing = 8
    ballRadiusStack.setHuggingPriority(.defaultHigh, for: .horizontal)
    
    // Configure Gravity
    gravityField.formatter = NumberFormatter()
    gravityField.placeholderString = "-200.0"
    gravityField.target = self
    gravityField.action = #selector(onGravityFieldChanged)
    gravityField.widthAnchor.constraint(equalToConstant: 80).isActive = true
    
    gravityStepper.minValue = -500.0
    gravityStepper.maxValue = -50.0
    gravityStepper.increment = 10.0
    gravityStepper.floatValue = -200.0
    gravityStepper.valueWraps = false
    gravityStepper.target = self
    gravityStepper.action = #selector(onGravityStepperAction)
    
    let gravityStack = NSStackView(views: [gravityField, gravityStepper])
    gravityStack.orientation = .horizontal
    gravityStack.spacing = 8
    gravityStack.setHuggingPriority(.defaultHigh, for: .horizontal)
    
    // Create Save & Apply button to add directly to the grid
    let saveApplyButton = NSButton(title: "Save & Apply", target: nil, action: nil)
    saveApplyButton.bezelStyle = .rounded
    saveApplyButton.target = self.parent
    saveApplyButton.action = #selector(SettingsViewController.saveAndApplySettings)
    
    let gridView = NSGridView(views: [
      [pinSpacingXLabel, pinSpacingXStack],
      [pinSpacingYLabel, pinSpacingYStack],
      [boardRowsLabel, boardRowsStack],
      [topPegCountLabel, topPegCountStack],
      [pegRadiusLabel, pegRadiusStack],
      [ballRadiusLabel, ballRadiusStack],
      [gravityLabel, gravityStack],
      [NSView(), saveApplyButton] // Add button directly to the grid
    ])
    
    // Center the button in the cell
    gridView.cell(atColumnIndex: 1, rowIndex: 7).xPlacement = .center
    
    // Set a height for the spacer row in Plinko tab
    gridView.row(at: 7).height = 60
    
    // Make column 1 (with the controls) expand to fill available space
    gridView.column(at: 1).xPlacement = .fill
    
    // Make the grid view take all available width
    gridView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    
    gridView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(gridView)
    
    let inset = SettingsViewController.inset
    NSLayoutConstraint.activate([
      gridView.topAnchor.constraint(equalTo: view.topAnchor, constant: inset),
      gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: inset),
      view.bottomAnchor.constraint(greaterThanOrEqualTo: gridView.bottomAnchor, constant: inset),
      view.trailingAnchor.constraint(greaterThanOrEqualTo: gridView.trailingAnchor, constant: inset),
      gridView.widthAnchor.constraint(greaterThanOrEqualToConstant: 350),
    ])
    gridView.column(at: 0).xPlacement = .trailing
    gridView.rowSpacing = 12
    gridView.columnSpacing = 16
  }
}
