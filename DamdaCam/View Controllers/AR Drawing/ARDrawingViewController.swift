//
//  ARDrawingViewController.swift
//  DamdaCam
//
//  Created by Yebin Kim on 2020/01/24.
//  Copyright © 2020 김예빈. All rights reserved.
//

import UIKit
import ARKit
import SceneKit
import CoreData

import AVKit
import AVFoundation
import ReplayKit

import FlexColorPicker

let sm = """
    float u = _surface.diffuseTexcoord.x;
    float v = _surface.diffuseTexcoord.y;
    int u100 = int(u * 100);
    int v100 = int(v * 100);
    if (u100 % 99 == 0 || v100 % 99 == 0) {
      // do nothing
    } else {
        discard_fragment();
    }
    """

enum ViewMode {
    case DRAW
    case TRACKING
}

enum TrackingMessageType {
    case looking
    case lookingEscalated
    case anchorLost
}

var pickedColor = #colorLiteral(red: 0.9999960065, green: 1, blue: 1, alpha: 1)
var previewSize: Int = 0

class TouchView: UIView {
    var touchDelegate: ARDrawingViewController?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesBegan(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesMoved(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let delegate = touchDelegate {
            delegate.touchesEnded(touches, with: event)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesCancelled(touches, with: event)
    }
}

class ARDrawingViewController: UIViewController, AVCapturePhotoCaptureDelegate, UITextViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    
    static let identifier: String = "ARDrawingViewController"
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var localRecords: [NSManagedObject] = []
    
    @IBOutlet var sceneView: ARSCNView!
    let configuration = ARWorldTrackingConfiguration()
    
    @IBOutlet weak var touchView: TouchView!
    
    // Record UI
    @IBOutlet var recordView: UIView!
    @IBOutlet var recordModePhoto: UIButton!
    @IBOutlet var recordModeVideo: UIButton!
    @IBOutlet var recordMoveButton: UIButton!
    @IBOutlet var recordViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet var recordGradient: UIImageView!
    var selectedMode: Bool = true // true -> photo, false -> video
    var videoState: Bool = false
    @IBOutlet var modeSelected: UIView!
    
    // Stroke UI
    @IBOutlet weak var clearAllButton: UIButton!
    @IBOutlet weak var undoButton: UIButton!
    
    // Message UI
    @IBOutlet weak var messagesContainerView: UIView!
    @IBOutlet weak var drawPromptContainer: UIView!
    @IBOutlet weak var drawPromptLabel: UILabel!
    @IBOutlet weak var trackingPromptContainer: UIView!
    @IBOutlet weak var trackingPromptLabel: UILabel!
    @IBOutlet weak var trackingImage: UIImageView!
    @IBOutlet weak var trackingImageCenterConstraint: NSLayoutConstraint!
    @IBOutlet var trackingStartView: UIView!
    @IBOutlet var drawingStartView: UIView!
    @IBOutlet var remove3DView: UIImageView!
    
    // Drawing edit UI
    @IBOutlet var editView: UIView!
    @IBOutlet var drawingPenButton: UIButton!
    @IBOutlet var drawingPenOne: UIButton!
    @IBOutlet var drawingPenTwo: UIButton!
    @IBOutlet var drawingPenThree: UIButton!
    @IBOutlet var drawingPenPlus: UIButton!
    @IBOutlet var drawingPenStackView: [UIButton]! {
        didSet {
            drawingPenStackView.forEach {
                $0.isHidden = true
            }
        }
    }
    
    // Icon
    @IBOutlet var settingButton: UIButton!
    @IBOutlet var clipButton: UIButton!
    @IBOutlet var changeButton: UIButton!
    @IBOutlet var galleryButton: UIButton!
    @IBOutlet var menuButton: UIButton!
    
    // Clip
    var clipViewState: Bool! = false
    var clipTime: Double! = 0.0
    @IBOutlet var clipView: UIView!
    @IBOutlet var oneClipButton: UIButton!
    @IBOutlet var twoClipButton: UIButton!
    @IBOutlet var threeClipButton: UIButton!
    @IBOutlet var plusClipButton: UIButton!
    var oneClipState: Bool = false
    var twoClipState: Bool = false
    var threeClipState: Bool = false
    var plusClipState: Bool = false
    @IBOutlet var plusClipPicker: UIPickerView!
    @IBOutlet var clipViewDivideBar: UIView!
    
    // Menu
    @IBOutlet var menuView: UIView!
    @IBOutlet var menuXButton: UIButton!
    @IBOutlet var menuXButtonOn: UIButton!
    @IBOutlet var menuTextButton: UIButton!
    @IBOutlet var menuFigureButton: UIButton!
    @IBOutlet var menuBrushButton: UIButton!
    @IBOutlet var menuPaletteButton: UIButton!
    @IBOutlet var menuTextLabel: UILabel!
    @IBOutlet var menuFigureLabel: UILabel!
    @IBOutlet var menuBrushLabel: UILabel!
    @IBOutlet var menuPaletteLabel: UILabel!
    var textButtonCenter: CGPoint!
    var figureButtonCenter: CGPoint!
    var paletteButtonCenter: CGPoint!
    var brushButtonCenter: CGPoint!
    var textLabelCenter: CGPoint!
    var figureLabelCenter: CGPoint!
    var paletteLabelCenter: CGPoint!
    var brushLabelCenter: CGPoint!
    var textButtonState: Bool = false
    var figureButtonState: Bool = false
    var paletteButtonState: Bool = false
    var brushButtonState: Bool = false
    
    // Text Set
    @IBOutlet var textView: UIView!
    @IBOutlet var textXButton: UIButton!
    @IBOutlet var textField: UITextView!
    @IBOutlet var textPreviewColor: CircleShapedView!
    @IBOutlet var textPreviewColorButton: UIButton!
    @IBOutlet var textDepthLabel: UILabel!
    @IBOutlet var textDepthSlider: UISlider!
    @IBOutlet var textAlignLeftButton: UIButton!
    @IBOutlet var textAlignCenterButton: UIButton!
    @IBOutlet var textAlignRightButton: UIButton!
    var textDepth: Float = 2.0
    
    var firstSet3DState: Bool = true
    
    // Figure Set
    @IBOutlet var figureView: UIView!
    @IBOutlet var figureXButton: UIButton!
    @IBOutlet var figurePreview: UIView!
    @IBOutlet var figurePreviewColor: CircleShapedView!
    @IBOutlet var figurePreviewColorButton: UIButton!
    @IBOutlet var figureFillButton: ISRadioButton!
    @IBOutlet var figureStrokeButton: ISRadioButton!
    @IBOutlet var figureWidthTitle: UILabel!
    @IBOutlet var figureWidthLabel: UILabel!
    @IBOutlet var figureWidthSlider: UISlider!
    @IBOutlet var figureDepthLabel: UILabel!
    @IBOutlet var figureDepthSlider: UISlider!
    @IBOutlet var figureRectangleButton: UIButton!
    @IBOutlet var figureRoundedButton: UIButton!
    @IBOutlet var figureCircleButton: UIButton!
    @IBOutlet var figureTriangleButton: UIButton!
    @IBOutlet var figureHeartButton: UIButton!
    var figure = Figure()
    
    // Brush Set
    @IBOutlet var brushView: UIView!
    @IBOutlet var brushXButton: UIButton!
    @IBOutlet var brushPreview: UIView!
    @IBOutlet var brushBasicButton: ISRadioButton!
    @IBOutlet var brushNeonButton: ISRadioButton!
    @IBOutlet var brushWidthLabel: UILabel!
    @IBOutlet var brushWidthSlider: UISlider!
    var brushWidth: Float = 0.015
    
    // Palette Set
    @IBOutlet var paletteView: UIView!
    @IBOutlet var paletteXButton: UIButton!
    @IBOutlet var paletteRadialPicker: RadialPaletteControl!
    @IBOutlet var paletteRGBView: UIView!
    @IBOutlet var paletteRLabel: UILabel!
    @IBOutlet var paletteGLabel: UILabel!
    @IBOutlet var paletteBLabel: UILabel!
    @IBOutlet var paletteHSBView: UIView!
    @IBOutlet var paletteHLabel: UILabel!
    @IBOutlet var paletteSLabel: UILabel!
    @IBOutlet var paletteVLabel: UILabel!
    @IBOutlet var paletteCustomView: UIView!
    @IBOutlet var paletteCustomCollectionView: UICollectionView!
    @IBOutlet weak var paletteCustomFlowLayout: UICollectionViewFlowLayout!
    var customPaletteArray: [UIColor]!
    public let colorPicker = ColorPickerController()
    
    // preview palette setup
    @IBOutlet var previewPaletteView: UIView!
    @IBOutlet var previewXButton: UIButton!
    
    var hasDrawnInSession: Bool = false
    var recordingTimer: Timer?
    
    // AR Drawing
    /// store current touch location in view
    var touchPoint: CGPoint = .zero
    var touchState: Bool = true
    var movingNow = false
    var tappedObjectNode = SCNNode()
    
    /// SCNNode floating in front of camera the distance drawing begins
    var hitNode: SCNNode?
    
    /// array of strokes a user has drawn in current session
    var strokes: [Stroke] = [Stroke]()
    
    var shouldRetryAnchorResolve = false
    
    /// Currently selected stroke size
    var strokeSize: Float = 0.0010
    
    var neonState: Bool = false
    var color: CGColor = Properties.shared.color.white.cgColor
    
    /// After 3 seconds of tracking changes trackingMessage to escalated value
    var trackingMessageTimer: Timer?
    
    /// When session returns from interruption, hold time to limit relocalization
    var resumeFromInterruptionTimer: Timer?
    
    /// When in limited tracking mode, hold previous mode to return to
    var modeBeforeTracking: ViewMode?
    
    /// Most situations we show the looking message, but when relocalizing and currently paired, show anchorLost type
    var trackingMessage: TrackingMessageType = .looking
    
    /// capture first time establish tracking
    var hasInitialTracking = false
    
    var mode: ViewMode = .DRAW {
        didSet {
            switch mode {
            case .DRAW:
                if (strokes.count > 0) {
                    hideDrawingPrompt()
                } else {
                    showDrawingPrompt()
                }
                
                drawingUIHidden(false)
                stopTrackingAnimation()
                messagesContainerView?.isHidden = true
                setStrokeVisibility(isHidden: false)
                UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: touchView)
                
                //#if DEBUG
                //sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]
                //#else
                sceneView.debugOptions = []
                //#endif
                
            case .TRACKING:
                hideDrawingPrompt()
                startTrackingAnimation(trackingMessage)
                
                // hiding fullBackground hides everything except close button
                setStrokeVisibility(isHidden: true)
                touchView.isHidden = true
                UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: trackingPromptLabel)
            }
            
            // if we're tracking and the mode changes, update our previous mode state
            if (modeBeforeTracking != nil && mode != .TRACKING) {
                print("Updating mode to return to after tracking: \(mode)")
                modeBeforeTracking = mode
            }
        }
    }
    
    // MARK: UI
    /// window with UI elements to keep them out of screen recording
    var uiWindow: UIWindow?
    
    // Video
    
    /// ReplayKit shared screen recorder
    var screenRecorder: RPScreenRecorder?
    
    /// writes CMSampleBuffer for screen recording
    var assetWriter: AVAssetWriter?
    
    /// holds asset writer settings for media
    var assetWriterInput: AVAssetWriterInput?
    
    /// temporary bool for toggling recording state
    var isRecording: Bool = false
    
    // MARK: - View State
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set drawing scene view
        self.touchView.touchDelegate = self
        self.initializeDrawingView()
        self.drawingUIHidden(false)
        
        DispatchQueue.main.async {
            // Set message
            self.initializeMessageView()
            // Set drawing pen stack view
            self.initializeDrawingPenView()
            // Set clip View
            self.initializeClipView()
            // Set menu view
            self.initializeMenuView()
        }
        
        // Set accessibility
        self.configureAccessibility()
        
        // Set notification observers
        self.addObservers()
        
        // Register gesture recognizer
        self.registerUIGestureRecognizers()
        self.registerNodeGestureRecognizers(view: editView)
        
        // Set record
        self.screenRecorder = RPScreenRecorder.shared()
        self.screenRecorder?.isMicrophoneEnabled = true
        self.initializeRecordButton()
        
        // FIXME: deleete remove3DView
        self.remove3DView.isHidden = true
        self.remove3DView.alpha = 0.0
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.configureARSession()
        
        self.setPreviewSize()
        
        // Set ui icon
        if previewSize == 0 {
            self.settingButton.setImage(UIImage(named: "ic_setup_wh"), for: .normal)
            self.clipButton.setImage(UIImage(named: "ic_clip_wh"), for: .normal)
            self.changeButton.setImage(UIImage(named: "ic_change_wh"), for: .normal)
            self.galleryButton.setImage(UIImage(named: "ic_gallery_wh"), for: .normal)
            self.menuButton.setImage(UIImage(named: "ic_menu_wh"), for: .normal)
            self.settingButton.dropShadow(state: true)
            self.clipButton.dropShadow(state: true)
            self.changeButton.dropShadow(state: true)
            self.galleryButton.dropShadow(state: true)
            self.menuButton.dropShadow(state: true)
            
            self.recordModePhoto.titleLabel?.textColor = Properties.shared.color.white
            self.recordModeVideo.titleLabel?.textColor = Properties.shared.color.white
            
            self.recordMoveButton.isHidden = false
            
        } else if previewSize == 1 {
            self.settingButton.setImage(UIImage(named: "ic_setup_bl"), for: .normal)
            self.clipButton.setImage(UIImage(named: "ic_clip_bl"), for: .normal)
            self.changeButton.setImage(UIImage(named: "ic_change_bl"), for: .normal)
            self.galleryButton.setImage(UIImage(named: "ic_gallery_bl"), for: .normal)
            self.menuButton.setImage(UIImage(named: "ic_menu_bl"), for: .normal)
            self.settingButton.dropShadow(state: false)
            self.clipButton.dropShadow(state: false)
            self.changeButton.dropShadow(state: false)
            self.galleryButton.dropShadow(state: false)
            self.menuButton.dropShadow(state: false)
            
            self.recordModePhoto.titleLabel?.textColor = Properties.shared.color.darkGray
            self.recordModeVideo.titleLabel?.textColor = Properties.shared.color.darkGray
            
            self.recordMoveButton.isHidden = true
            
        } else {
            self.settingButton.setImage(UIImage(named: "ic_setup_wh"), for: .normal)
            self.clipButton.setImage(UIImage(named: "ic_clip_wh"), for: .normal)
            self.changeButton.setImage(UIImage(named: "ic_change_wh"), for: .normal)
            self.galleryButton.setImage(UIImage(named: "ic_gallery_bl"), for: .normal)
            self.menuButton.setImage(UIImage(named: "ic_menu_bl"), for: .normal)
            self.settingButton.dropShadow(state: false)
            self.clipButton.dropShadow(state: false)
            self.changeButton.dropShadow(state: false)
            self.galleryButton.dropShadow(state: false)
            self.menuButton.dropShadow(state: false)
            
            self.recordModePhoto.titleLabel?.textColor = Properties.shared.color.darkGray
            self.recordModeVideo.titleLabel?.textColor = Properties.shared.color.darkGray
            
            self.recordMoveButton.isHidden = true
        }
        
        // Menu Set
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.buttonAnimation(button: self.menuTextButton, label: self.menuTextLabel, buttonPosition: self.menuXButton.center, size: 0.5, labelPosition: self.menuXButton.center)
            self.buttonAnimation(button: self.menuFigureButton, label: self.menuFigureLabel, buttonPosition: self.menuXButton.center, size: 0.5, labelPosition: self.menuXButton.center)
            self.buttonAnimation(button: self.menuBrushButton, label: self.menuBrushLabel, buttonPosition: self.menuXButton.center, size: 0.5, labelPosition: self.menuXButton.center)
            self.buttonAnimation(button: self.menuPaletteButton, label: self.menuPaletteLabel, buttonPosition: self.menuXButton.center, size: 0.5, labelPosition: self.menuXButton.center)
            self.menuView.alpha = 0.0
        }
        
        self.stopTrackingAnimation()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        self.sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
        self.resetTouches()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        self.touchPoint = .zero
    }
    
    private func registerUIGestureRecognizers() {
        // camera mode set
        let swipeModeRight: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(modePhoto))
        swipeModeRight.direction = .right
        self.modeSelected.addGestureRecognizer(swipeModeRight)
        
        let swipeModeLeft: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(modeVideo))
        swipeModeLeft.direction = .left
        self.modeSelected.addGestureRecognizer(swipeModeLeft)
        
        // record set
        let recordVideoStart: UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(recordVideo))
        recordVideoStart.minimumPressDuration = 0.5
        recordButton.addGestureRecognizer(recordVideoStart)
        
        let swipeButtonDown: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(recordButtonDown))
        swipeButtonDown.direction = .down
        self.recordMoveButton.addGestureRecognizer(swipeButtonDown)
        
        let swipeButtonUp: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(recordButtonUp))
        swipeButtonUp.direction = .up
        self.recordMoveButton.addGestureRecognizer(swipeButtonUp)
        
        // menu set
        let tapMenuView: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(MenuViewTap))
        menuView.addGestureRecognizer(tapMenuView)
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { (notification) in
            self.touchPoint = .zero
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(voiceOverStatusChanged), name: UIAccessibility.voiceOverStatusDidChangeNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func initializeDrawingView() {
        // Set the view's delegate
        self.sceneView.delegate = self
        self.sceneView.scene = SCNScene()
        
        self.hitNode = SCNNode()
        self.hitNode!.position = SCNVector3Make(0, 0, -0.4)  // 드로잉 거리 조절
        self.sceneView.pointOfView?.addChildNode(hitNode!)
        
        self.setStrokeSize(brushWidth)
        
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.shadowMode = .deferred
        ambientLight.light?.color = UIColor.white
        ambientLight.light?.type = SCNLight.LightType.ambient
        ambientLight.position = SCNVector3(x: 0,y: 5,z: 0)
        self.sceneView.scene.rootNode.addChildNode(ambientLight)
        self.sceneView.automaticallyUpdatesLighting = true   // lighting 설정
        
        // Neon Set
        if let path = Bundle.main.path(forResource: "NodeTechnique", ofType: "plist") {
            if let dict = NSDictionary(contentsOfFile: path)  {
                let dict2 = dict as! [String : AnyObject]
                let technique = SCNTechnique(dictionary:dict2)
                self.sceneView.technique = technique
            }
        }
        
        self.clearAllButton.layer.cornerRadius = 13
        self.clearAllButton.dropShadow(opacity: 0.16, radius: 10.0, offset: CGSize(width: 1, height: 1))
    }
    
    private func initializeMessageView() {
        self.drawPromptContainer.alpha = 0
        self.initializeTrackingStartView()
        self.initializeDrawingStartView()
    }
    
    private func initializeTrackingStartView() {
        self.trackingStartView.isHidden = true
        self.trackingStartView.alpha = 0.0
        self.trackingStartView.layer.cornerRadius = 17
        self.trackingStartView.dropShadow()
    }
    
    private func initializeDrawingStartView() {
        self.drawingStartView.isHidden = true
        self.drawingStartView.alpha = 0.0
        self.drawingStartView.layer.cornerRadius = 17
        self.drawingStartView.dropShadow()
    }
    
    private func initializeRecordButton() {
        self.recordButton.layer.cornerRadius = 27.5
        self.recordBackgroundGradient()
    }
    
    private func initializeDrawingPenView() {
        self.drawingPenButton.layer.cornerRadius = 11
        self.drawingPenButton.backgroundColor = colorPicker.selectedColor
        self.drawingPenButton.dropShadow(opacity: 0.16, radius: 10.0, offset: CGSize(width: 1, height: 1))
        self.drawingPenButton.layer.borderWidth = 2
        self.drawingPenButton.layer.borderColor = Properties.shared.color.drawingPen_border.cgColor
        
        self.drawingPenOne.layer.cornerRadius = 11
        self.drawingPenOne.backgroundColor = Properties.shared.color.drawingPen_blue
        self.drawingPenOne.dropShadow(opacity: 0.16, radius: 10.0, offset: CGSize(width: 1, height: 1))
        
        self.drawingPenTwo.layer.cornerRadius = 11
        self.drawingPenTwo.backgroundColor = Properties.shared.color.drawingPen_green
        self.drawingPenTwo.dropShadow(opacity: 0.16, radius: 10.0, offset: CGSize(width: 1, height: 1))
        
        self.drawingPenThree.layer.cornerRadius = 11
        self.drawingPenThree.backgroundColor = Properties.shared.color.drawingPen_red
        self.drawingPenThree.dropShadow(opacity: 0.16, radius: 10.0, offset: CGSize(width: 1, height: 1))
    }
    
    private func initializeClipView() {
        self.clipButton.isHidden = true
        self.clipView.alpha = 0.0
        self.clipView.layer.cornerRadius = 5
        
        self.oneClipButton.layer.cornerRadius = 20
        self.twoClipButton.layer.cornerRadius = 20
        self.threeClipButton.layer.cornerRadius = 20
        self.plusClipButton.layer.cornerRadius = 20
        
        self.oneClipButton.dropShadow(state: true)
        self.twoClipButton.dropShadow(state: true)
        self.threeClipButton.dropShadow(state: true)
        self.plusClipButton.dropShadow(state: true)
        
        self.oneClipButton.applyGradient(colors: [Properties.shared.color.white.cgColor, Properties.shared.color.white.cgColor], state: false)
        self.twoClipButton.applyGradient(colors: [Properties.shared.color.white.cgColor, Properties.shared.color.white.cgColor], state: false)
        self.threeClipButton.applyGradient(colors: [Properties.shared.color.white.cgColor, Properties.shared.color.white.cgColor], state: false)
        self.plusClipButton.applyGradient(colors: [Properties.shared.color.white.cgColor, Properties.shared.color.white.cgColor], state: false)
        
        self.plusClipPicker.selectRow(5, inComponent: 0, animated: false)
        
        let secLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        secLabel.font = Properties.shared.font.bold(13.0)
        secLabel.textColor = Properties.shared.color.darkGray
        secLabel.text = "m"
        secLabel.sizeToFit()
        secLabel.frame = CGRect(x: 81.0, y: 49.0, width: secLabel.bounds.width, height: secLabel.bounds.height)
        plusClipPicker.addSubview(secLabel)
        
        let minLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        minLabel.font = Properties.shared.font.bold(13.0)
        minLabel.textColor = Properties.shared.color.darkGray
        minLabel.text = "s"
        minLabel.sizeToFit()
        minLabel.frame = CGRect(x: 210.0, y: 49.0, width: minLabel.bounds.width, height: minLabel.bounds.height)
        plusClipPicker.addSubview(minLabel)
    }
    
    private func initializeMenuView() {
        self.textButtonCenter = self.menuTextButton.center
        self.figureButtonCenter = self.menuFigureButton.center
        self.brushButtonCenter = self.menuBrushButton.center
        self.paletteButtonCenter = self.menuPaletteButton.center
        self.textLabelCenter = self.menuTextLabel.center
        self.figureLabelCenter = self.menuFigureLabel.center
        self.brushLabelCenter = self.menuBrushLabel.center
        self.paletteLabelCenter = self.menuPaletteLabel.center
        self.menuTextLabel.alpha = 0.0
        self.menuFigureLabel.alpha = 0.0
        self.menuBrushLabel.alpha = 0.0
        self.menuPaletteLabel.alpha = 0.0
        
        self.menuView.isHidden = true
        self.menuView.alpha = 0.0
        addBackView(view: self.menuView, color: Properties.shared.color.black, alpha: 0.6, cornerRadius: 0)
        
        self.initializeTextView()
        self.initializeFigureView()
        self.initializeBrushView()
        self.initializePalleteView()
    }
    
    private func initializeTextView() {
        // Text Set
        self.textView.alpha = 0.0
        self.textView.layer.cornerRadius = 10
        
        self.textField.delegate = self as UITextViewDelegate
        self.textField.text = "Text"
        self.textField.textAlignment = .center
        self.textField.centerVertically()
        self.alignSet(tapped: textAlignCenterButton)
        
        self.textDepthSlider.setThumbImage(UIImage(named: "thumb_slider"), for: .normal)
        
        addBackView(view: self.textView, color: Properties.shared.color.black, alpha: 0.6, cornerRadius: 10)
    }
    
    private func initializeFigureView() {
        // Figure Set
        self.figureView.alpha = 0.0
        self.figureView.layer.cornerRadius = 10
        
        self.figureFillButton.isSelected = true
        self.figureWidthTitle.textColor = Properties.shared.color.text_disable
        self.figureWidthLabel.textColor = Properties.shared.color.text_disable
        self.figureWidthSlider.isEnabled = false
        self.figureWidthSlider.setThumbImage(UIImage(named: "thumb_slider"), for: .normal)
        figureDepthSlider.setThumbImage(UIImage(named: "thumb_slider"), for: .normal)
        
        addBackView(view: self.figureView, color: Properties.shared.color.black, alpha: 0.6, cornerRadius: 10)
    }
    
    private func initializeBrushView() {
        // Brush Set
        self.brushView.alpha = 0.0
        self.brushView.layer.cornerRadius = 10
        
        self.brushBasicButton.isSelected = true
        self.brushWidthSlider.setThumbImage(UIImage(named: "thumb_slider"), for: .normal)
        
        addBackView(view: self.brushView, color: Properties.shared.color.black, alpha: 0.6, cornerRadius: 10)
    }
    
    private func initializePalleteView() {
        // Palette Set
        self.paletteView.alpha = 0.0
        self.paletteView.layer.cornerRadius = 10
        self.paletteRadialPicker.dropShadow()
        
        self.createCustomPaletteArray()
        self.colorPicker.selectedColor = pickedColor
        
        // Preview Color Set
        self.previewPaletteView.layer.cornerRadius = 18
        self.previewPaletteView.dropShadow()
        
        addBackView(view: self.paletteView, color: Properties.shared.color.black, alpha: 0.6, cornerRadius: 10)
    }
    
    // MARK: - View Configuration
    
    func configureARSession(runOptions: ARSession.RunOptions = []) {
        // Create a session configuration
        configuration.planeDetection = [.horizontal]
        //  configuration.isAutoFocusEnabled = false
        
        // Run the view's session
        sceneView.session.run(configuration, options: runOptions)
        sceneView.session.delegate = self
    }
    
    // MARK: - Stroke Code
    
    /// Places anchor on hitNode plane at point
    func makeAnchor(at point: CGPoint) -> ARAnchor? {
        
        guard let hitNode = hitNode else {
            return nil
        }
        let projectedOrigin = sceneView.projectPoint(hitNode.worldPosition)
        let offset = sceneView.unprojectPoint(SCNVector3Make(Float(point.x), Float(point.y), projectedOrigin.z))
        
        var blankTransform = matrix_float4x4(1)
        //        var transform = hitNode.simdWorldTransform
        blankTransform.columns.3.x = offset.x
        blankTransform.columns.3.y = offset.y
        blankTransform.columns.3.z = offset.z
        
        return ARAnchor(transform: blankTransform)
    }
    
    /// Updates stroke with new SCNVector3 point, and regenerates line geometry
    func updateLine(for stroke: Stroke) {
        if touchState {
            guard let _ = stroke.points.last, let strokeNode = stroke.node else {
                return
            }
            let offset = unprojectedPosition(for: stroke, at: touchPoint)
            let newPoint = strokeNode.convertPosition(offset, from: sceneView.scene.rootNode)
            
            stroke.lineWidth = strokeSize
            if (stroke.add(point: newPoint, neonState: neonState)) {
                updateGeometry(stroke)
            }
            //            print("Total Points: \(stroke.points.count)")
        }
    }
    
    func updateGeometry(_ stroke: Stroke) {
        if touchState {
            if stroke.positionsVec3.count > 4 {
                let vectors = stroke.positionsVec3
                let sides = stroke.mSide
                let width = stroke.mLineWidth
                let lengths = stroke.mLength
                let totalLength = (stroke.drawnLocally) ? stroke.totalLength : stroke.animatedLength
                let line = LineGeometry(vectors: vectors,
                                        sides: sides,
                                        width: width,
                                        lengths: lengths,
                                        endCapPosition: totalLength,
                                        color: color)
                
                stroke.node?.geometry = line
                hasDrawnInSession = true
                hideDrawingPrompt()
            }
        }
    }
    
    // Stroke Helper Methods
    func unprojectedPosition(for stroke: Stroke, at touch: CGPoint) -> SCNVector3 {
        guard let hitNode = self.hitNode else {
            return SCNVector3Zero
        }
        
        let projectedOrigin = sceneView.projectPoint(hitNode.worldPosition)
        let offset = sceneView.unprojectPoint(SCNVector3Make(Float(touch.x), Float(touch.y), projectedOrigin.z))
        
        return offset
    }
    
    /// Checks user's strokes for match, then partner's strokes
    func getStroke(for anchor: ARAnchor) -> Stroke? {
        let matchStrokeArray = strokes.filter { (stroke) -> Bool in
            return stroke.anchor == anchor
        }
        
        return matchStrokeArray.first
    }
    
    /// Checks user's strokes for match, then partner's strokes
    func getStroke(for node: SCNNode) -> Stroke? {
        let matchStrokeArray = strokes.filter { (stroke) -> Bool in
            return stroke.node == node
        }
        
        return matchStrokeArray.first
    }
    
    func setStrokeVisibility(isHidden: Bool) {
        strokes.forEach { stroke in
            stroke.node?.isHidden = isHidden
        }
    }
    
    @IBAction func changeButtonTapped(_ sender: UIButton) {
        self.showStoryboard(ARMotionViewController.identifier)
    }
    
    @IBAction func settingButtonTapped(_ sender: UIButton) {
        self.showStoryboard(SettingTableViewController.identifier)
    }
    
    @IBAction func galleryButtonTapped(_ sender: UIButton) {
        self.showStoryboard(GalleryViewController.identifier)
    }
    
    @objc func modePhoto(gestureRecognizer: UISwipeGestureRecognizer){
        self.changeModePhoto()
    }
    
    @objc func modeVideo(gestureRecognizer: UISwipeGestureRecognizer){
        self.changeModeVideo()
    }
    
    @objc func recordButtonDown(gestureRecognizer: UISwipeGestureRecognizer){
        UIView.animate(withDuration: Double(0.5), animations: {
            self.recordViewBottomConstraint.constant = 130
            self.view.layoutIfNeeded()
        })
    }
    
    @objc func recordButtonUp(gestureRecognizer: UISwipeGestureRecognizer){
        UIView.animate(withDuration: Double(0.5), animations: {
            self.recordViewBottomConstraint.constant = 0
            self.view.layoutIfNeeded()
        })
    }
    
    func configureAccessibility() {
        clearAllButton.accessibilityLabel = NSLocalizedString("menu_clear", comment: "Clear Drawing")
        
        let key = NSAttributedString.Key.accessibilitySpeechIPANotation
        
        let attributedString = NSAttributedString(
            string: NSLocalizedString("content_description_record", comment: "Record"), attributes: [key: "record"]
        )
        
        recordButton.accessibilityAttributedLabel = attributedString
        recordButton.accessibilityHint = NSLocalizedString("content_description_record_accessible", comment: "Tap to record a video for ten seconds.")
        
        voiceOverStatusChanged()
    }
    
    @objc func voiceOverStatusChanged() {
        //        sizeButtonStackView.alpha = (UIAccessibility.isVoiceOverRunning) ? 1 : 0
    }
    
    @IBAction func recordTapped(_ sender: UIButton) {
        if selectedMode {
            print("still")
            takePhoto()
            //            sessionOutput.capturePhoto(with: sessionOutputSetting, delegate: self as! AVCapturePhotoCaptureDelegate)
        } else {
            if !videoState {
                recordTapped(sender: sender)
                
                UIView.animate(withDuration: 0.5, delay: 0.0, options: [.curveLinear, .repeat, .autoreverse, .allowUserInteraction], animations: {
                    self.recordButton.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                    self.recordButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                })
            } else {
                stopRecording()
                recordButton.layer.removeAllAnimations()
            }
            
            videoState = !videoState
        }
    }
    
    @objc func recordVideo(gestureRecognizer: UILongPressGestureRecognizer){
        //        print("video")
        if gestureRecognizer.state != .ended {
            //            print("video start")
            //            recordTapped(sender: recordButton)
            //            recordingAnimation()
        } else {
            //            print("video stop")
        }
    }
    
    func recordBackgroundGradient() {
        var count = 1
        var loadingImages = [UIImage]()
        
        while let loadingImage = UIImage(named: "recordGradient/\(count).png") {
            loadingImages.append(loadingImage)
            count += 1
        }
        
        self.recordGradient.animationImages = loadingImages
        self.recordGradient.animationDuration = 3.0
        self.recordGradient.startAnimating()
    }
    
    @IBAction func drawingPenTapped(_ sender: UIButton) {
        UIView.animate(withDuration: 0.3) {
            self.drawingPenStackView.forEach {
                $0.isHidden = !$0.isHidden
            }
        }
        
        setTouchState(true)
        editView.isHidden = true
        drawingPenButton.layer.borderWidth = 2
    }
    
    @IBAction func selectedDrawingPen(_ sender: UIButton) {
        if sender == drawingPenOne {
            pickedColor = Properties.shared.color.drawingPen_blue
            colorPicker.selectedColor = pickedColor
            drawingPenButton.backgroundColor = pickedColor
            self.setStrokeColor(pickedColor.cgColor)
        }
        
        if sender == drawingPenTwo {
            pickedColor = Properties.shared.color.drawingPen_green
            colorPicker.selectedColor = pickedColor
            drawingPenButton.backgroundColor = pickedColor
            self.setStrokeColor(pickedColor.cgColor)
        }
        
        if sender == drawingPenThree {
            pickedColor = Properties.shared.color.drawingPen_red
            colorPicker.selectedColor = pickedColor
            drawingPenButton.backgroundColor = pickedColor
            self.setStrokeColor(pickedColor.cgColor)
        }
        
        setTouchState(true)
        editView.isHidden = true
        drawingPenButton.layer.borderWidth = 2
    }
    
    @IBAction func selectedDrawingPenColor(_ sender: UIButton) {
        palettebuttonTapped(menuPaletteButton)
    }
    
    @IBAction func clearAllStrokes(_ sender: UIButton) {
        clearStrokesTapped(sender: sender)
    }
    
    @IBAction func undoLastStroke(_ sender: UIButton) {
        undoLastStroke(sender: sender)
    }
    
    // Clip Set
    @IBAction func setClipLength(_ sender: UIButton) {
        if clipView.isHidden {
            self.clipView.isHidden = false
            
            UIView.animate(withDuration: 0.2, animations: {
                self.clipView.alpha = 0.85
            })
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.clipView.alpha = 0.0
            })
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.clipView.isHidden = true
            }
        }
    }
    
    @IBAction func clipOneButtonTapped(_ sender: UIButton) {
        if (oneClipState) {
            clipTime = 0.0
            oneClipState = false
        } else {
            clipTime = 5.0
            oneClipState = true
            twoClipState = false
            threeClipState = false
            plusClipState = false
        }
        
        clipButtonStateCheck()
        
        if (clipViewState) {
            clipView.layer.frame = CGRect(x: 54.5 , y: 56, width: clipView.frame.width, height: clipView.frame.height / 3)
            clipViewDivideBar.isHidden = true
            plusClipPicker.isHidden = true
            clipViewState = false
        }
    }
    
    @IBAction func clipTwoButtonTapped(_ sender: UIButton) {
        if (twoClipState) {
            clipTime = 0.0
            twoClipState = false
        } else {
            clipTime = 10.0
            oneClipState = false
            twoClipState = true
            threeClipState = false
            plusClipState = false
        }
        
        clipButtonStateCheck()
        
        if (clipViewState) {
            clipView.layer.frame = CGRect(x: 54.5 , y: 56, width: clipView.frame.width, height: clipView.frame.height / 3)
            clipViewDivideBar.isHidden = true
            plusClipPicker.isHidden = true
            clipViewState = false
        }
    }
    
    @IBAction func clipThreeButtonTapped(_ sender: UIButton) {
        if (threeClipState) {
            clipTime = 0.0
            threeClipState = false
        } else {
            clipTime = 30.0
            oneClipState = false
            twoClipState = false
            threeClipState = true
            plusClipState = false
        }
        
        clipButtonStateCheck()
        
        if (clipViewState) {
            clipView.layer.frame = CGRect(x: 54.5 , y: 56, width: clipView.frame.width, height: clipView.frame.height / 3)
            clipViewDivideBar.isHidden = true
            plusClipPicker.isHidden = true
            clipViewState = false
        }
    }
    
    @IBAction func clipPlusButtonTapped(_ sender: UIButton) {
        if (plusClipState) {
            clipTime = 0.0
            plusClipState = false
        } else {
            oneClipState = false
            twoClipState = false
            threeClipState = false
            plusClipState = true
        }
        
        clipButtonStateCheck()
        
        if (clipViewState) {
            clipView.layer.frame = CGRect(x: 54.5 , y: 56, width: clipView.frame.width, height: clipView.frame.height / 3)
            clipViewDivideBar.isHidden = true
            plusClipPicker.isHidden = true
            clipViewState = false
        } else {
            clipView.layer.frame = CGRect(x: 54.5, y: 56, width: clipView.frame.width, height: clipView.frame.height * 3)
            clipViewDivideBar.isHidden = false
            plusClipPicker.isHidden = false
            clipViewState = true
        }
    }
    
    func clipButtonStateCheck() {
        if (oneClipState) {
            oneClipButton.setTitleColor(Properties.shared.color.white, for: .normal)
            oneClipButton.applyGradient(colors: [Properties.shared.color.main_blue.cgColor, Properties.shared.color.main_pink.cgColor], state: true)
        } else {
            oneClipButton.setTitleColor(Properties.shared.color.darkGray, for: .normal)
            oneClipButton.applyGradient(colors: [Properties.shared.color.white.cgColor, Properties.shared.color.white.cgColor], state: true)
        }
        
        if (twoClipState) {
            twoClipButton.setTitleColor(Properties.shared.color.white, for: .normal)
            twoClipButton.applyGradient(colors: [Properties.shared.color.main_blue.cgColor, Properties.shared.color.main_pink.cgColor], state: true)
        } else {
            twoClipButton.setTitleColor(Properties.shared.color.darkGray, for: .normal)
            twoClipButton.applyGradient(colors: [Properties.shared.color.white.cgColor, Properties.shared.color.white.cgColor], state: true)
        }
        
        if (threeClipState) {
            threeClipButton.setTitleColor(Properties.shared.color.white, for: .normal)
            threeClipButton.applyGradient(colors: [Properties.shared.color.main_blue.cgColor, Properties.shared.color.main_pink.cgColor], state: true)
        } else {
            threeClipButton.setTitleColor(Properties.shared.color.darkGray, for: .normal)
            threeClipButton.applyGradient(colors: [Properties.shared.color.white.cgColor, Properties.shared.color.white.cgColor], state: true)
        }
        
        if (plusClipState) {
            plusClipButton.setTitleColor(Properties.shared.color.white, for: .normal)
            plusClipButton.applyGradient(colors: [Properties.shared.color.main_blue.cgColor, Properties.shared.color.main_pink.cgColor], state: true)
        } else {
            plusClipButton.setTitleColor(Properties.shared.color.darkGray, for: .normal)
            plusClipButton.applyGradient(colors: [Properties.shared.color.white.cgColor, Properties.shared.color.white.cgColor], state: true)
        }
    }
    
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if component == 0 {
            return 10
        } else {
            return 60
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let title = UILabel()
        title.font = Properties.shared.font.regular(15.0)
        title.textColor = UIColor(red: 84.0/255.0, green: 84.0/255.0, blue: 84.0/255.0, alpha: 1.0)
        title.text = String(row)
        title.textAlignment = .center
        
        if component == 0 {
            return title
        }
        else {
            return title
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        clipTime = (Double(plusClipPicker.selectedRow(inComponent: 0)) * 60.0) + Double(plusClipPicker.selectedRow(inComponent: 1))
    }
    
    func drawingUIHidden(_ isHidden: Bool) {
        clearAllButton.isHidden = (isHidden == true) ? true : shouldHideTrashButton()
        //            undoButton.isHidden = (isHidden == true) ? true : delegate.shouldHideUndoButton()
    }
    
    func showDrawingPrompt(isPaired: Bool = false) {
        //        drawPromptLabel.text = ("화면에 손을 대고 \n이리저리 움직여보세요")
        touchView.accessibilityLabel = NSLocalizedString("draw_action_accessible", comment: "Draw")
        
        clearAllButton.isHidden = true
        drawingStartView.isHidden = false
        //        drawPromptLabel.isHidden = hasDrawnInSession
        
        touchView.accessibilityHint = NSLocalizedString("draw_prompt_accessible", comment: "Double-tap and hold your finger and move around")
        
        UIView.animate(withDuration: 0.25) {
            self.drawingStartView.alpha = 0.8
            self.drawPromptContainer.alpha = 1.0
        }
    }
    
    func hideDrawingPrompt() {
        UIView.animate(withDuration: 0.25) {
            self.drawingStartView.alpha = 0.0
            self.drawPromptContainer.alpha = 0.0
        }
        DispatchQueue.main.async {
            self.drawingStartView.isHidden = false
            self.drawingUIHidden(false)
        }
    }
    
    /// When tracking state is .notavailable or .limited, start tracking animation
    func startTrackingAnimation(_ trackingMessage: TrackingMessageType = .looking) {
        switch trackingMessage {
        case .looking:
            //            trackingPromptLabel.text = ("그림 그릴 공간을 구성하고 있어요")
            self.trackingStartView.isHidden = false
            
        case .lookingEscalated:
            //            trackingPromptLabel.text = ("그림 그릴 공간을 찾을 수 없어요")
            self.trackingStartView.isHidden = false
            
        case .anchorLost:
            //            trackingPromptLabel.text = ("앱을 다시 시작해주세요 :(")
            self.trackingStartView.isHidden = false
        }
        
        trackingPromptLabel.accessibilityLabel = trackingPromptLabel.text
        
        hideDrawingPrompt()
        
        // Fade in
        UIView.animate(withDuration: 0.25) {
            self.trackingPromptContainer.alpha = 1
        }
        
        // Loop right-left tracking animation
        UIView.animate(withDuration: 1.0, delay: 0, options: [.repeat, .curveEaseInOut, .autoreverse], animations: {
            self.trackingStartView.alpha = 0.8
            self.trackingImageCenterConstraint.constant = 15
            
            self.trackingPromptContainer.layoutIfNeeded()
        })
    }
    
    /// When tracking state is .normal, end tracking animation
    func stopTrackingAnimation() {
        // Fade out
        UIView.animate(withDuration: 0.25, animations: {
            self.trackingPromptContainer.alpha = 0
            self.trackingStartView.alpha = 0
            
            // Reset state
        }) { (isComplete) in
            ///            self.trackingPromptContainer.isHidden = true
            self.trackingImageCenterConstraint.constant = -15
            self.trackingPromptContainer.layoutIfNeeded()
            self.trackingPromptContainer.layer.removeAllAnimations()
        }
        
        DispatchQueue.main.async {
            self.trackingStartView.isHidden = true
        }
    }
    
    func recordingWillStart() {
        if clipTime != 0.0 {
            DispatchQueue.main.async {
                self.recordingTimer = Timer.scheduledTimer(withTimeInterval: self.clipTime, repeats: false, block: { (timer) in
                    DispatchQueue.main.async {
                        print(self.clipTime)
                        self.stopRecording()
                        self.recordButton.layer.removeAllAnimations()
                        self.recordButton.isEnabled = true
                    }
                })
                
                self.recordButton.isEnabled = false
            }
        }
    }
    
    func recordingHasUpdated() {
        
    }
    
    func recordingHasEnded() {
        if let timer = recordingTimer {
            timer.invalidate()
        }
        recordingTimer = nil
    }
    
    func addBackView(view: UIView, color: UIColor, alpha: CGFloat, cornerRadius: CGFloat) {
        let backView = UIView()
        backView.frame = view.bounds
        backView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backView.backgroundColor = color
        backView.alpha = alpha
        backView.layer.cornerRadius = cornerRadius
        view.addSubview(backView)
        view.sendSubviewToBack(backView)
    }
    
    func changeModePhoto() {
        UIView.animate(withDuration: Double(0.5), animations: {
            self.modeSelected.center += CGPoint(x: 58.0, y: 0.0)
        })
        
        clipButton.isHidden = true
        
        selectedMode = true
    }
    
    func changeModeVideo() {
        UIView.animate(withDuration: Double(0.5), animations: {
            self.modeSelected.center -= CGPoint(x: 58.0, y: 0.0)
        })
        
        clipButton.isHidden = false
        
        selectedMode = false
    }
    
    @IBAction func photoButtonTapped(_ sender: UIButton) {
        self.changeModePhoto()
    }
    
    @IBAction func videoButtonTapped(_ sender: UIButton) {
        self.changeModeVideo()
    }
    
    // Menu Set
    @objc func MenuViewTap(gestureRecognizer: UITapGestureRecognizer){
        self.XbuttonTapped(menuXButtonOn)
        
        gestureRecognizer.cancelsTouchesInView = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            gestureRecognizer.cancelsTouchesInView = true
        }
    }
    
    @objc func OnMenuViewTap(gestureRecognizer: UITapGestureRecognizer){
        self.XbuttonTapped(menuXButtonOn)
        self.textViewXTapped(textXButton)
        self.figureViewXTapped(figureXButton)
        self.brushViewXTapped(brushXButton)
        self.paletteViewXTapped(paletteXButton)
        self.previewPaletteXTapped(previewXButton)
        
        gestureRecognizer.cancelsTouchesInView = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            gestureRecognizer.cancelsTouchesInView = true
        }
    }
    
    @IBAction func menuTapped(_ sender: UIButton) {
        setTouchState(false)
        editView.isHidden = false
        drawingPenButton.layer.borderWidth = 0
        
        menuXButton.isEnabled = false
        menuXButtonOn.isEnabled = false
        
        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.curveLinear], animations: {
            self.menuView.isHidden = false
            self.menuView.alpha = 1.0
            self.menuXButton.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            self.menuXButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.menuXButtonOn.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            self.menuXButtonOn.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.menuXButton.alpha = 1.0
        })
        UIView.animate(withDuration: 0.15, delay: 0.3, options: [.curveLinear], animations: {
            self.buttonAnimation(button: self.menuTextButton, label: self.menuTextLabel, buttonPosition: self.textButtonCenter, size: 1.0, labelPosition: self.textLabelCenter)
        })
        UIView.animate(withDuration: 0.15, delay: 0.4, options: [.curveLinear], animations: {
            self.buttonAnimation(button: self.menuFigureButton, label: self.menuFigureLabel, buttonPosition: self.figureButtonCenter, size: 1.0, labelPosition: self.figureLabelCenter)
        })
        UIView.animate(withDuration: 0.15, delay: 0.5, options: [.curveLinear], animations: {
            self.buttonAnimation(button: self.menuBrushButton, label: self.menuBrushLabel, buttonPosition: self.brushButtonCenter, size: 1.0, labelPosition: self.brushLabelCenter)
        })
        UIView.animate(withDuration: 0.15, delay: 0.6, options: [.curveLinear], animations: {
            self.buttonAnimation(button: self.menuPaletteButton, label: self.menuPaletteLabel, buttonPosition: self.paletteButtonCenter, size: 1.0, labelPosition: self.paletteLabelCenter)
        })
        UIView.animate(withDuration: 0.2, delay: 0.7, options: [.curveLinear], animations: {
            self.menuXButton.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            self.menuXButtonOn.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            self.menuXButtonOn.alpha = 0.0
            
            self.menuTextLabel.alpha = 1.0
            self.menuFigureLabel.alpha = 1.0
            self.menuBrushLabel.alpha = 1.0
            self.menuPaletteLabel.alpha = 1.0
            
            self.menuXButton.isEnabled = true
            self.menuXButtonOn.isEnabled = true
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.menuXButton.isEnabled = true
            self.menuXButtonOn.isEnabled = true
        }
    }
    
    @IBAction func XbuttonTapped(_ sender: UIButton) {
        menuXButton.isEnabled = false
        menuXButtonOn.isEnabled = false
        
        UIView.animate(withDuration: 0.15, delay: 0.0, options: [.curveLinear], animations: {
            self.menuTextLabel.alpha = 0.0
            self.menuFigureLabel.alpha = 0.0
            self.menuBrushLabel.alpha = 0.0
            self.menuPaletteLabel.alpha = 0.0
            
            self.menuXButtonOn.alpha = 1.0
            self.menuXButton.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            self.menuXButton.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.menuXButtonOn.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            self.menuXButtonOn.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.menuXButton.alpha = 0.0
            self.buttonAnimation(button: self.menuTextButton, label: self.menuTextLabel, buttonPosition: self.menuXButton.center, size: 0.5, labelPosition: self.menuXButton.center)
        })
        UIView.animate(withDuration: 0.15, delay: 0.1, options: [.curveLinear], animations: {
            self.buttonAnimation(button: self.menuFigureButton, label: self.menuFigureLabel, buttonPosition: self.menuXButton.center, size: 0.5, labelPosition: self.menuXButton.center)
        })
        UIView.animate(withDuration: 0.15, delay: 0.2, options: [.curveLinear], animations: {
            self.buttonAnimation(button: self.menuBrushButton, label: self.menuBrushLabel, buttonPosition: self.menuXButton.center, size: 0.5, labelPosition: self.menuXButton.center)
        })
        UIView.animate(withDuration: 0.15, delay: 0.3, options: [.curveLinear], animations: {
            self.buttonAnimation(button: self.menuPaletteButton, label: self.menuPaletteLabel, buttonPosition: self.menuXButton.center, size: 0.5, labelPosition: self.menuXButton.center)
        })
        UIView.animate(withDuration: 0.15, delay: 0.4, options: [.curveLinear], animations: {
            self.menuXButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.menuXButtonOn.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.menuView.alpha = 0.0
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.menuView.isHidden = true
            
            self.menuXButton.isEnabled = true
            self.menuXButtonOn.isEnabled = true
        }
    }
    
    @IBAction func textbuttonTapped(_ sender: UIButton) {
        let onTapMenuView: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(OnMenuViewTap))
        menuView.addGestureRecognizer(onTapMenuView)
        
        setTouchState(false)
        editView.isHidden = false
        drawingPenButton.layer.borderWidth = 0
        
        textPreviewColor.backgroundColor = colorPicker.selectedColor
        textField.textColor = colorPicker.selectedColor
        textDepthLabel.text = String(Int(textDepthSlider.value))
        
        textButtonState = true
        figureButtonState = false
        paletteButtonState = false
        brushButtonState = false
        
        previewPaletteView.frame.origin.y = 286.0
        
        buttonHide(state: true)
        textView.isHidden = false
        
        UIView.animate(withDuration: 0.2, animations: {
            self.textView.alpha = 1.0
        })
        
        self.menuButtonStateCheck()
    }
    
    @IBAction func figurebuttonTapped(_ sender: UIButton) {
        let onTapMenuView: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(OnMenuViewTap))
        menuView.addGestureRecognizer(onTapMenuView)
        
        setTouchState(false)
        editView.isHidden = false
        drawingPenButton.layer.borderWidth = 0
        
        figurePreview.layer.sublayers?[0].removeFromSuperlayer()
        drawShape(figure)
        
        figurePreviewColor.backgroundColor = colorPicker.selectedColor
        figureWidthLabel.text = String(Int(figureWidthSlider.value))
        figureDepthLabel.text = String(Int(figureDepthSlider.value))
        
        previewPaletteView.frame.origin.y = 214.5
        
        textButtonState = false
        figureButtonState = true
        paletteButtonState = false
        brushButtonState = false
        
        buttonHide(state: true)
        figureView.isHidden = false
        
        UIView.animate(withDuration: 0.2, animations: {
            self.figureView.alpha = 1.0
        })
        
        self.menuButtonStateCheck()
    }
    
    @IBAction func brushbuttonTapped(_ sender: UIButton) {
        let onTapMenuView: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(OnMenuViewTap))
        menuView.addGestureRecognizer(onTapMenuView)
        
        setTouchState(false)
        editView.isHidden = false
        drawingPenButton.layer.borderWidth = 0
        
        brushPreview.layer.sublayers?[0].removeFromSuperlayer()
        drawLineShape()
        
        brushWidthLabel.text = String(Int(brushWidthSlider.value))
        
        textButtonState = false
        figureButtonState = false
        paletteButtonState = false
        brushButtonState = true
        
        buttonHide(state: true)
        brushView.isHidden = false
        
        UIView.animate(withDuration: 0.2, animations: {
            self.brushView.alpha = 1.0
        })
        
        self.menuButtonStateCheck()
    }
    
    @IBAction func palettebuttonTapped(_ sender: UIButton) {
        let onTapMenuView: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(OnMenuViewTap))
        menuView.addGestureRecognizer(onTapMenuView)
        
        setTouchState(false)
        editView.isHidden = false
        drawingPenButton.layer.borderWidth = 0
        
        paletteCustomCollectionView.reloadData()
        pickedColor = colorPicker.selectedColor
        createCustomPaletteArray()
        
        textButtonState = false
        figureButtonState = false
        paletteButtonState = true
        brushButtonState = false
        
        buttonHide(state: true)
        paletteView.isHidden = false
        
        UIView.animate(withDuration: 0.2, animations: {
            self.paletteView.alpha = 1.0
        })
        
        self.menuButtonStateCheck()
    }
    
    func menuSelectedOn(button: UIButton, changeImage: UIImage) {
        button.setImage(changeImage, for: .normal)
        
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            button.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            button.dropShadow(opacity: 0.16, radius: 10.0, offset: CGSize(width: 1, height: 1))
        }
    }
    
    func menuSelectedOff(button: UIButton, changeImage: UIImage) {
        button.setImage(changeImage, for: .normal)
        
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            button.layer.shadowOpacity = 0.0
        }
    }
    
    func buttonAnimation(button: UIButton, label: UILabel, buttonPosition: CGPoint, size: CGFloat, labelPosition: CGPoint) {
        button.center = buttonPosition
        label.center = labelPosition
        button.transform = CGAffineTransform(scaleX: size, y: size)
        label.transform = CGAffineTransform(scaleX: size, y: size)
    }
    
    func menuButtonStateCheck() {
        if (textButtonState) {
            UIView.animate(withDuration: 0.1) {
                //                self.menuTextLabel.alpha = 1.0
            }
            self.menuSelectedOn(button: self.menuTextButton, changeImage: UIImage(named: "ic_text_on")!)
        } else {
            UIView.animate(withDuration: 0.1) {
                //                self.menuTextLabel.alpha = 0.0
            }
            self.menuSelectedOff(button: self.menuTextButton, changeImage: UIImage(named: "ic_text_off")!)
        }
        
        if (figureButtonState) {
            UIView.animate(withDuration: 0.1) {
                //                self.menuFigureLabel.alpha = 1.0
            }
            self.menuSelectedOn(button: self.menuFigureButton, changeImage: UIImage(named: "ic_figure_on")!)
        } else {
            UIView.animate(withDuration: 0.1) {
                //                self.menuFigureLabel.alpha = 0.0
            }
            self.menuSelectedOff(button: self.menuFigureButton, changeImage: UIImage(named: "ic_figure_off")!)
        }
        
        if (brushButtonState) {
            UIView.animate(withDuration: 0.1) {
                //                self.menuBrushLabel.alpha = 1.0
            }
            self.menuSelectedOn(button: self.menuBrushButton, changeImage: UIImage(named: "ic_brush_on")!)
        } else {
            UIView.animate(withDuration: 0.1) {
                //                self.menuBrushLabel.alpha = 0.0
            }
            self.menuSelectedOff(button: self.menuBrushButton, changeImage: UIImage(named: "ic_brush_off")!)
        }
        
        if (paletteButtonState) {
            UIView.animate(withDuration: 0.1) {
                //                self.menuPaletteLabel.alpha = 1.0
            }
            self.menuSelectedOn(button: self.menuPaletteButton, changeImage: UIImage(named: "ic_palette_on")!)
        } else {
            UIView.animate(withDuration: 0.1) {
                //                self.menuPaletteLabel.alpha = 0.0
            }
            self.menuSelectedOff(button: self.menuPaletteButton, changeImage: UIImage(named: "ic_palette_off")!)
        }
    }
    
    func buttonHide(state: Bool) {
        menuXButton.isHidden = state
        menuXButtonOn.isHidden = state
        menuTextButton.isHidden = state
        menuFigureButton.isHidden = state
        menuBrushButton.isHidden = state
        menuPaletteButton.isHidden = state
        
        menuTextLabel.isHidden = state
        menuFigureLabel.isHidden = state
        menuBrushLabel.isHidden = state
        menuPaletteLabel.isHidden = state
    }
    
    // Text Set
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if textView.frame.origin.y == 198 {
                textView.frame.origin.y = keyboardSize.height / 2.0
                previewPaletteView.frame.origin.y = keyboardSize.height / 1.1
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if textView.frame.origin.y != 198 {
            textView.frame.origin.y = 198
            previewPaletteView.frame.origin.y = 286
        }
    }
    
    func alignSet(tapped: UIButton!) {
        if (tapped == textAlignLeftButton) {
            textField.textAlignment = .left
            textAlignLeftButton.setImage(UIImage(named: "textAlign_left_on"), for: .normal)
            textAlignCenterButton.setImage(UIImage(named: "textAlign_center_off"), for: .normal)
            textAlignRightButton.setImage(UIImage(named: "textAlign_right_off"), for: .normal)
        } else if (tapped == textAlignCenterButton) {
            textField.textAlignment = .center
            textAlignLeftButton.setImage(UIImage(named: "textAlign_left_off"), for: .normal)
            textAlignCenterButton.setImage(UIImage(named: "textAlign_center_on"), for: .normal)
            textAlignRightButton.setImage(UIImage(named: "textAlign_right_off"), for: .normal)
        } else if (tapped == textAlignRightButton) {
            textField.textAlignment = .right
            textAlignLeftButton.setImage(UIImage(named: "textAlign_left_off"), for: .normal)
            textAlignCenterButton.setImage(UIImage(named: "textAlign_center_off"), for: .normal)
            textAlignRightButton.setImage(UIImage(named: "textAlign_right_on"), for: .normal)
        }
    }
    
    @IBAction func textAlignTapped(_ sender: UIButton) {
        self.alignSet(tapped: sender)
    }
    
    @IBAction func textDepthChanged(_ sender: UISlider) {
        textDepthLabel.text = String(Int(sender.value))
        textDepth = sender.value
    }
    
    @IBAction func textViewXTapped(_ sender: UIButton) {
        buttonHide(state: false)
        
        UIView.animate(withDuration: 0.2, animations: {
            self.previewPaletteXTapped(self.previewXButton)
            self.textView.endEditing(true)
            self.textView.alpha = 0.0
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.textView.isHidden = true
        }
    }
    
    @IBAction func textViewCheckTapped(_ sender: UIButton) {
        if firstSet3DState {
            remove3DView.isHidden = false
            firstSet3DState = !firstSet3DState
            
            UIView.animate(withDuration: 0.1, animations: {
                self.remove3DView.alpha = 0.8
            })
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.remove3DView.isHidden = true
            }
        }
        
        create3DText(message: textField.text, depth: CGFloat(textDepth), color: pickedColor, align: textField!.textAlignment.rawValue)
        
        buttonHide(state: false)
        self.XbuttonTapped(menuXButtonOn)
        
        UIView.animate(withDuration: 0.2, animations: {
            self.textView.endEditing(true)
            self.textView.alpha = 0.0
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.textView.isHidden = true
        }
    }
    
    // Figure Set
    @IBAction func figureStateTapped(_ sender: UIButton) {
        if sender == figureFillButton {
            figureWidthTitle.textColor = Properties.shared.color.text_disable
            figureWidthLabel.textColor = Properties.shared.color.text_disable
            figureWidthSlider.isEnabled = false
        } else {
            figureWidthTitle.textColor = Properties.shared.color.white
            figureWidthLabel.textColor = Properties.shared.color.white
            figureWidthSlider.isEnabled = true
        }
        figurePreview.layer.sublayers?[0].removeFromSuperlayer()
        drawShape(figure)
    }
    
    @IBAction func figureWidthChanged(_ sender: UISlider) {
        figurePreview.layer.sublayers?[0].removeFromSuperlayer()
        drawShape(figure)
        figureWidthLabel.text = String(Int(sender.value))
        
        figure.width = CGFloat(sender.value)
    }
    
    @IBAction func figureDepthChanged(_ sender: UISlider) {
        figurePreview.layer.sublayers?[0].removeFromSuperlayer()
        drawShape(figure)
        figureDepthLabel.text = String(Int(sender.value))
        
        figure.depth = CGFloat(sender.value)
    }
    
    @IBAction func figureShapedSelected(_ sender: UIButton) {
        if sender == figureRectangleButton {
            figure.shape = .rectangle
        }
        
        if sender == figureRoundedButton {
            figure.shape = .rounded
        }
        
        if sender == figureCircleButton {
            figure.shape = .circle
        }
        
        if sender == figureTriangleButton {
            figure.shape = .triangle
        }
        
        if sender == figureHeartButton {
            figure.shape = .heart
        }
        
        figurePreview.layer.sublayers?[0].removeFromSuperlayer()
        drawShape(figure)
    }
    
    func drawShape(_ figure: Figure) {
        let layer = CAShapeLayer()
        layer.path = figure.shape.path.cgPath
        
        if figureFillButton.isSelected {
            layer.fillColor = colorPicker.selectedColor.cgColor
            layer.strokeColor = UIColor.clear.cgColor
            layer.lineWidth = 0.0
        } else if figureStrokeButton.isSelected {
            layer.fillColor = UIColor.clear.cgColor
            layer.strokeColor = colorPicker.selectedColor.cgColor
            layer.lineWidth = figure.width
        }
        
        figurePreview.layer.addSublayer(layer)
    }
    
    @IBAction func figureViewXTapped(_ sender: UIButton) {
        buttonHide(state: false)
        
        UIView.animate(withDuration: 0.2, animations: {
            self.previewPaletteXTapped(self.previewXButton)
            self.figureView.alpha = 0.0
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.figureView.isHidden = true
        }
    }
    
    @IBAction func figureViewCheckTapped(_ sender: UIButton) {
        if firstSet3DState {
            remove3DView.isHidden = false
            firstSet3DState = !firstSet3DState
            
            UIView.animate(withDuration: 0.1, animations: {
                self.remove3DView.alpha = 0.8
            })
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.remove3DView.isHidden = true
            }
        }
        
        figure.color = pickedColor
        create3DFigure(figure)
        
        buttonHide(state: false)
        self.XbuttonTapped(menuXButtonOn)
        
        UIView.animate(withDuration: 0.2, animations: {
            self.figureView.alpha = 0.0
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.figureView.isHidden = true
        }
    }
    
    // Brush Set
    @IBAction func brushStateTapped(_ sender: UIButton) {
        brushPreview.layer.sublayers?[0].removeFromSuperlayer()
        drawLineShape()
        
        self.setStrokeNeon(brushNeonButton.isSelected)
    }
    
    @IBAction func brushWidthChanged(_ sender: UISlider) {
        brushPreview.layer.sublayers?[0].removeFromSuperlayer()
        drawLineShape()
        brushWidthLabel.text = String(Int(sender.value))
        
        brushWidth = sender.value / 2000
    }
    
    func drawLineShape() {
        let shapeLayer = CAShapeLayer()
        shapeLayer.lineWidth = CGFloat(brushWidthSlider.value / 2)
        shapeLayer.lineCap = CAShapeLayerLineCap.round
        let path = CGMutablePath()
        path.addLines(between: [CGPoint(x: 30, y: 40),CGPoint(x: 220, y: 40)])
        shapeLayer.path = path
        
        if brushBasicButton.isSelected {
            shapeLayer.strokeColor = colorPicker.selectedColor.cgColor
            shapeLayer.shadowRadius = 0
            shapeLayer.shadowOpacity = 0
        } else {
            shapeLayer.strokeColor = Properties.shared.color.white.cgColor
            shapeLayer.shadowOffset = .zero
            shapeLayer.shadowColor = colorPicker.selectedColor.cgColor
            shapeLayer.shadowRadius = 7
            shapeLayer.shadowOpacity = 1
        }
        
        brushPreview.layer.addSublayer(shapeLayer)
    }
    
    @IBAction func brushViewXTapped(_ sender: UIButton) {
        brushWidth = self.getStrokeSize()
        
        buttonHide(state: false)
        
        UIView.animate(withDuration: 0.2, animations: {
            self.previewPaletteXTapped(self.previewXButton)
            self.brushView.alpha = 0.0
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.brushView.isHidden = true
            
            self.setTouchState(true)
            self.editView.isHidden = true
            self.drawingPenButton.layer.borderWidth = 2
        }
    }
    
    @IBAction func brushViewCheckTapped(_ sender: UIButton) {
        self.setStrokeSize(brushWidth)
        
        buttonHide(state: false)
        self.XbuttonTapped(menuXButtonOn)
        
        UIView.animate(withDuration: 0.2, animations: {
            self.brushView.alpha = 0.0
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.brushView.isHidden = true
            
            self.setTouchState(true)
            self.editView.isHidden = true
            self.drawingPenButton.layer.borderWidth = 2
        }
    }
    
    // Palette Set
    @IBAction func paletteRGBTapped(_ sender: UIButton) {
        paletteRGBView.isHidden = false
        paletteHSBView.isHidden = true
        paletteCustomView.isHidden = true
    }
    
    @IBAction func paletteHSBTapped(_ sender: UIButton) {
        paletteRGBView.isHidden = true
        paletteHSBView.isHidden = false
        paletteCustomView.isHidden = true
    }
    
    @IBAction func paletteCustomTapped(_ sender: UIButton) {
        paletteRGBView.isHidden = true
        paletteHSBView.isHidden = true
        paletteCustomView.isHidden = false
    }
    
    @IBOutlet public var colorPreview: ColorPreviewWithHex? {
        get {
            return colorPicker.colorPreview
        }
        set {
            colorPicker.colorPreview = newValue
        }
    }
    
    @IBOutlet open var customControl1: AbstractColorControl? {
        get {
            return colorPicker.customControl1
        }
        set {
            colorPicker.customControl1 = newValue
        }
    }
    
    @IBOutlet open var redSlider: RedSliderControl? {
        get {
            return colorPicker.redSlider
        }
        set {
            colorPicker.redSlider = newValue
        }
    }
    
    @IBOutlet open var greenSlider: GreenSliderControl? {
        get {
            return colorPicker.greenSlider
        }
        set {
            colorPicker.greenSlider = newValue
        }
    }
    
    @IBOutlet open var blueSlider: BlueSliderControl? {
        get {
            return colorPicker.blueSlider
        }
        set {
            colorPicker.blueSlider = newValue
        }
    }
    
    @IBOutlet weak var hueSlider: HueSliderControl? {
        get {
            return colorPicker.hueSlider
        }
        set {
            colorPicker.hueSlider = newValue
        }
    }
    
    @IBOutlet open var saturationSlider: SaturationSliderControl? {
        get {
            return colorPicker.saturationSlider
        }
        set {
            colorPicker.saturationSlider = newValue
        }
    }
    
    @IBOutlet open var brightnessSlider: BrightnessSliderControl? {
        get {
            return colorPicker.brightnessSlider
        }
        set {
            colorPicker.brightnessSlider = newValue
        }
    }
    
    func getContext() -> NSManagedObjectContext {
        return appDelegate.persistentContainer.viewContext
    }
    
    func createCustomPaletteArray() {
        customPaletteArray = Array()
        let context = self.getContext()
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "CustomPalette")
        
        do {
            localRecords = try context.fetch(fetchRequest)
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        
        for index in 0 ..< localRecords.count {
            let localRecord = localRecords[index]
            let hexToColor = UIColor(hex: localRecord.value(forKey: "colorHex") as! String)
            customPaletteArray.append(hexToColor!)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let CustomColor = collectionView.dequeueReusableCell(withReuseIdentifier: "CustomColor", for: indexPath) as! CustomPaletteCollectionViewCell
        
        CustomColor.customColor.layer.cornerRadius = 4
        
        if indexPath.row < customPaletteArray.count {
            CustomColor.customColor.backgroundColor = customPaletteArray[indexPath.row]
            CustomColor.customColor.layer.borderColor = UIColor.clear.cgColor
        } else {
            CustomColor.customColor.backgroundColor = UIColor.clear
            CustomColor.customColor.layer.borderWidth = 1
            CustomColor.customColor.layer.borderColor = Properties.shared.color.gray.cgColor
        }
        
        return CustomColor
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 18
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let _ = collectionView.dequeueReusableCell(withReuseIdentifier: "CustomColor", for: indexPath) as! CustomPaletteCollectionViewCell
        
        if indexPath.row < customPaletteArray.count {
            pickedColor = customPaletteArray[indexPath.row]
            colorPicker.selectedColor = pickedColor
            drawingPenButton.backgroundColor = pickedColor
            self.setStrokeColor(pickedColor.cgColor)
        }
    }
    
    @IBAction func paletteViewXTapped(_ sender: UIButton) {
        colorPicker.selectedColor = pickedColor
        
        buttonHide(state: false)
        
        UIView.animate(withDuration: 0.2, animations: {
            self.previewPaletteXTapped(self.previewXButton)
            self.paletteView.alpha = 0.0
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.paletteView.isHidden = true
        }
    }
    
    @IBAction func paletteViewCheckTapped(_ sender: UIButton) {
        let context = self.getContext()
        let entity = NSEntityDescription.entity(forEntityName: "CustomPalette", in: context)
        
        // 중복 저장 방지
        var overlap: Bool = false
        
        for index in 0 ..< customPaletteArray.count {
            if colorPicker.selectedColor.hexValue() == customPaletteArray[index].hexValue() {
                overlap = true
            }
        }
        
        if !(overlap) {
            let object = NSManagedObject(entity: entity!, insertInto: context)
            let colorToHex = colorPicker.selectedColor.hexValue()
            object.setValue(colorToHex, forKey: "colorHex")
            
            do {
                try context.save()
                print("saved!")
            } catch let error as NSError {
                print("Could not save \(error), \(error.userInfo)")
            }
        }
        
        pickedColor = colorPicker.selectedColor
        drawingPenButton.backgroundColor = pickedColor
        self.setStrokeColor(pickedColor.cgColor)
        
        buttonHide(state: false)
        self.XbuttonTapped(menuXButtonOn)
        
        UIView.animate(withDuration: 0.2, animations: {
            self.paletteView.alpha = 0.0
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            self.paletteView.isHidden = true
            
            self.setTouchState(true)
            self.editView.isHidden = true
            self.drawingPenButton.layer.borderWidth = 2
        }
    }
    
    // Preview Palette Set
    @IBOutlet open var radialHsbPalette: RadialPaletteControl? {
        get {
            return colorPicker.radialHsbPalette
        }
        set {
            colorPicker.radialHsbPalette = newValue
        }
    }
    
    @IBAction func previewPaletteOnTapped(_ sender: UIButton) {
        previewPaletteView.isHidden = false
        
        UIView.animate(withDuration: 0.2, animations: {
            self.previewPaletteView.alpha = 1.0
        })
    }
    
    @IBAction func previewPaletteXTapped(_ sender: UIButton) {
        let context = self.getContext()
        let entity = NSEntityDescription.entity(forEntityName: "CustomPalette", in: context)
        
        // 중복 저장 방지
        var overlap: Bool = false
        
        for index in 0 ..< customPaletteArray.count {
            if colorPicker.selectedColor.hexValue() == customPaletteArray[index].hexValue() {
                overlap = true
            }
        }
        
        if !(overlap) {
            let object = NSManagedObject(entity: entity!, insertInto: context)
            let colorToHex = colorPicker.selectedColor.hexValue()
            object.setValue(colorToHex, forKey: "colorHex")
            
            do {
                try context.save()
                print("saved!")
            } catch let error as NSError {
                print("Could not save \(error), \(error.userInfo)")
            }
        }
        
        pickedColor = colorPicker.selectedColor
        drawingPenButton.backgroundColor = pickedColor
        self.setStrokeColor(pickedColor.cgColor)
        
        figurePreviewColor.backgroundColor = colorPicker.selectedColor
        figurePreview.layer.sublayers?[0].removeFromSuperlayer()
        drawShape(figure)
        
        textPreviewColor.backgroundColor = colorPicker.selectedColor
        textField.textColor = colorPicker.selectedColor
        
        UIView.animate(withDuration: 0.2, animations: {
            self.previewPaletteView.alpha = 0.0
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.previewPaletteView.isHidden = true
        }
    }
    
    // MARK: - Handle Touch
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touchInView = touches.first?.location(in: sceneView), mode == .DRAW else {
            return
        }
        
        // hold onto touch location for projection
        touchPoint = touchInView
        
        // begin a neㅇ stroke
        let stroke = Stroke()
        print("Touch")
        if let anchor = makeAnchor(at:touchPoint) {
            stroke.anchor = anchor
            stroke.points.append(SCNVector3Zero)
            stroke.touchStart = touchPoint
            stroke.lineWidth = strokeSize
            
            strokes.append(stroke)
            //            self.undoButton.isHidden = shouldHideUndoButton()
            //            self.clearAllButton.isHidden = shouldHideTrashButton()
            sceneView.session.add(anchor: anchor)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touchInView = touches.first?.location(in: sceneView), mode == .DRAW, touchPoint != .zero else {
            return
        }
        
        // hold onto touch location for projection
        touchPoint = touchInView
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchPoint = CGPoint.zero
        strokes.last?.resetMemory()
        
        // for some reason putting this in the touchesBegan does not trigger
        UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: nil)
        
    }
    
    override var shouldAutorotate: Bool {
        get {
            if let recorder = screenRecorder, recorder.isRecording { return false }
            return true
        }
    }
    
    func setPreviewSize() {
        if previewSize == 0 {
            sceneView.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        } else if previewSize == 1 {
            sceneView.frame = CGRect(x: 0, y: 60, width: 375, height: 440)
        } else if previewSize == 2 {
            sceneView.frame = CGRect(x: 0, y: 0, width: 375, height: 500)
        }
    }
    
    // MARK: - UI Methods
    
    func takePhoto() {
        //1. Create A Snapshot
        let snapShot = sceneView.snapshot()
        
        //2. Save It The Photos Album
        UIImageWriteToSavedPhotosAlbum(snapShot, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        
        if let error = error {
            print("Error Saving ARDrawing Scene \(error)")
        } else {
            print("ARDrawing Scene Successfully Saved")
        }
    }
    
    func recordTapped(sender: UIButton?) {
        resetTouches()
        
        if screenRecorder?.isRecording == true {
            // Reset record button accessibility label to original value
            configureAccessibility()
            
            stopRecording()
        } else {
            sender?.accessibilityLabel = NSLocalizedString("content_description_record_stop", comment: "Stop Recording")
            startRecording()
        }
    }
    
    func startRecording() {
        screenRecorder?.startRecording(handler: { (error) in
            guard error == nil else {
                return
            }
            self.recordingWillStart()
            
        })
    }
    
    func stopRecording() {
        //        progressCircle.stop()
        screenRecorder?.stopRecording(handler: { (previewViewController, error) in
            DispatchQueue.main.async {
                guard error == nil, let preview = previewViewController else {
                    return
                }
                self.recordingHasEnded()
                previewViewController?.previewControllerDelegate = self as RPPreviewViewControllerDelegate
                previewViewController?.modalPresentationStyle = .overFullScreen
                
                self.present(preview, animated: true, completion:nil)
                self.uiWindow?.isHidden = true
            }
        })
    }
    
    func undoLastStroke(sender: UIButton?) {
        resetTouches()
        
        if let lastStroke = strokes.last {
            if let anchor = lastStroke.anchor {
                sceneView.session.remove(anchor: anchor)
            }
        }
    }
    
    func clearStrokesTapped(sender: UIButton?) {
        self.resetTouches()
        self.clearAllStrokes()
    }
    
    func clearAllStrokes() {
        for stroke in self.strokes {
            if let anchor = stroke.anchor {
                self.sceneView.session.remove(anchor: anchor)
            }
        }
    }
    
    func setTouchState(_ state: Bool) {
        touchState = state
    }
    
    func getTouchState() -> Bool {
        return touchState
    }
    
    func setStrokeSize(_ radius: Float) {
        strokeSize = radius
    }
    
    func getStrokeSize() -> Float {
        return strokeSize
    }
    
    func setStrokeNeon(_ state: Bool) {
        neonState = state
    }
    
    func getStrokeNeon() -> Bool {
        return neonState
    }
    
    func setStrokeColor(_ selectedColor: CGColor) {
        color = selectedColor
    }
    
    func getStrokeColor() -> CGColor {
        return color
    }
    
    func shouldHideTrashButton()->Bool {
        if (strokes.count > 0) {
            return false
        }
        return true
    }
    
    func shouldHideUndoButton()->Bool {
        if (strokes.count > 0) {
            return false
        }
        return true
    }
    
    func resetTouches() {
        touchPoint = .zero
    }
    
    // Text Set
    func create3DText(message: String, depth: CGFloat, color: UIColor, align: Int) {
        let text = SCNText(string: message, extrusionDepth: depth)
        text.firstMaterial?.diffuse.contents = color
        text.font = Properties.shared.font.regular(5.0)
        text.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        
        guard let pointOfView = sceneView.pointOfView else {return}
        let transform = pointOfView.transform   // 변환 행렬
        let orientation = SCNVector3(-transform.m31 / 2.0, -transform.m32 / 2.0, -transform.m33 / 2.0)   // 방향은 3번째 열에 정보를 담고 있음, 일반적인 오른손잡이 규칙에 따를 수 있게 값을 뒤집어줌
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)  // 위치는 4번째 열에 정보를 담고 있음
        let frontOfCamera: SCNVector3 = orientation + location  // CNVector 타입에 일반적인 + 연산자 사용 불가능하기 때문에 연산자 오버로딩, 드로잉이 될 위치
        
        let node = SCNNode()
        node.position = frontOfCamera
        node.orientation = pointOfView.orientation
        node.scale = SCNVector3(x: 0.05, y: 0.05, z: 0.05)
        node.geometry = text
        
        node.light = SCNLight()
        node.light?.type = SCNLight.LightType.directional
        node.light?.color = UIColor.white
        node.light?.castsShadow = true
        node.light?.automaticallyAdjustsShadowProjection = true
        node.light?.shadowSampleCount = 64
        node.light?.shadowRadius = 16
        node.light?.shadowMode = .deferred
        node.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        node.light?.shadowColor = UIColor.black.withAlphaComponent(0.75)
        
        if align == 0 {
            let (minVec, maxVec) = node.boundingBox
            node.pivot = SCNMatrix4MakeTranslation(0, (maxVec.y - minVec.y) / 2 + minVec.y, 0)
        } else if align == 1 {
            let (minVec, maxVec) = node.boundingBox
            node.pivot = SCNMatrix4MakeTranslation((maxVec.x - minVec.x) / 2 + minVec.x, (maxVec.y - minVec.y) / 2 + minVec.y, 0)
        } else if align == 2 {
            let (minVec, maxVec) = node.boundingBox
            node.pivot = SCNMatrix4MakeTranslation(maxVec.x, (maxVec.y - minVec.y) / 2 + minVec.y, 0)
        }
        
        sceneView.scene.rootNode.addChildNode(node)
    }
    
    // Figure Set
    func create3DFigure(_ figure: Figure) {
        guard let pointOfView = sceneView.pointOfView else {return}
        let transform = pointOfView.transform
        let orientation = SCNVector3(-transform.m31 / 2.0, -transform.m32 / 2.0, -transform.m33 / 2.0)
        let location = SCNVector3(transform.m41, transform.m42, transform.m43)
        let frontOfCamera: SCNVector3 = orientation + location
        
        let node = SCNNode()
        let layer = CALayer()
        
        switch figure.shape {
        case .rectangle:
            node.geometry = SCNBox(width: 5.0, height: 5.0, length: figure.depth, chamferRadius: 0.0)
            layer.frame = CGRect(x: 0, y: 0, width: 5.0, height: 5.0)
        case .rounded:
            node.geometry = SCNBox(width: 5.0, height: 5.0, length: figure.depth, chamferRadius: 2.0)
            layer.frame = CGRect(x: 0, y: 0, width: 5.0, height: 5.0)
            layer.cornerRadius = 2.0
        case .circle:
            node.geometry = SCNSphere(radius: figure.width)
        case .triangle, .heart:
            let centerPoint = CGPoint(x: CGFloat(frontOfCamera.x), y: CGFloat(frontOfCamera.y))
            let path = draw3DShape(figure, centerPoint: centerPoint)
            let nodeShape = SCNShape(path: path, extrusionDepth: figure.depth)
            node.geometry = nodeShape
        }
        
        if figure.fillState {
            //            layer.backgroundColor = color.cgColor
            
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.isDoubleSided = true
            node.geometry!.materials = [material]
        } else {
            //            layer.borderColor = color.cgColor
            //            layer.borderWidth = width * 100
            
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.isDoubleSided = true
            node.geometry!.materials = [material]
        }
        
        node.position = frontOfCamera
        node.orientation = pointOfView.orientation
        node.scale = SCNVector3(x: 0.05, y: 0.05, z: 0.05)
        
        node.light = SCNLight()
        node.light?.type = SCNLight.LightType.directional
        node.light?.color = UIColor.white
        node.light?.castsShadow = true
        node.light?.automaticallyAdjustsShadowProjection = true
        node.light?.shadowSampleCount = 64
        node.light?.shadowRadius = 16
        node.light?.shadowMode = .deferred
        node.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        node.light?.shadowColor = UIColor.black.withAlphaComponent(0.75)
        
        sceneView.scene.rootNode.addChildNode(node)
    }
    
    func draw3DShape(_ figure: Figure, centerPoint: CGPoint) -> UIBezierPath {
        var path = UIBezierPath()
        let originalRect = CGRect(center: centerPoint, size: CGSize(width: 5.0, height: 5.0))
        
        switch figure.shape {
        case .triangle:
            path = UIBezierPath()
            path.move(to: CGPoint(x: originalRect.minX, y: originalRect.minY))
            path.addLine(to: CGPoint(x: originalRect.maxX, y: originalRect.minY))
            path.addLine(to: CGPoint(x: originalRect.midX, y: originalRect.maxX))
            path.close()
            break
            
        case .heart:
            path = UIBezierPath()
            let scale: Double = 1.0
            
            let scaledWidth = (originalRect.size.width * CGFloat(scale))
            let scaledXValue = originalRect.minX
            let scaledHeight = (originalRect.size.height * CGFloat(scale))
            let scaledYValue = originalRect.minY
            
            let scaledRect = CGRect(x: scaledXValue, y: scaledYValue, width: scaledWidth, height: scaledHeight)
            
            path.move(to: CGPoint(x: originalRect.midX, y: scaledRect.origin.y + scaledRect.size.height))
            
            
            path.addCurve(to: CGPoint(x: scaledRect.origin.x, y: scaledRect.origin.y + (scaledRect.size.height/4)),
                          controlPoint1: CGPoint(x: scaledRect.origin.x + (scaledRect.size.width/2), y: scaledRect.origin.y + (scaledRect.size.height*3/4)) ,
                          controlPoint2: CGPoint(x: scaledRect.origin.x, y: scaledRect.origin.y + (scaledRect.size.height/2)) )
            
            path.addArc(withCenter: CGPoint(x: scaledRect.origin.x + (scaledRect.size.width/4),y: scaledRect.origin.y + (scaledRect.size.height/4)),
                        radius: (scaledRect.size.width/4),
                        startAngle: CGFloat(Double.pi),
                        endAngle: 0,
                        clockwise: true)
            
            path.addArc(withCenter: CGPoint(x: scaledRect.origin.x + (scaledRect.size.width * 3/4),y: scaledRect.origin.y + (scaledRect.size.height/4)),
                        radius: (scaledRect.size.width/4),
                        startAngle: CGFloat(Double.pi),
                        endAngle: 0,
                        clockwise: true)
            
            path.addCurve(to: CGPoint(x: originalRect.midX, y: scaledRect.origin.y + scaledRect.size.height),
                          controlPoint1: CGPoint(x: scaledRect.origin.x + scaledRect.size.width, y: scaledRect.origin.y + (scaledRect.size.height/2)),
                          controlPoint2: CGPoint(x: scaledRect.origin.x + (scaledRect.size.width/2), y: scaledRect.origin.y + (scaledRect.size.height*3/4)) )
            
            path.close()
            path.apply(CGAffineTransform(rotationAngle: .pi))
            break
            
        default: break
        }
        
        return path
    }
    
    func showStoryboard(_ name: String) {
        let storyboard: UIStoryboard = UIStoryboard(name: name, bundle: nil)
        if let nextView = storyboard.instantiateInitialViewController() {
            present(nextView, animated: true, completion: nil)
        }
    }
}
