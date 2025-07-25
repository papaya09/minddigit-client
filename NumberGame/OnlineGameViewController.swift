import UIKit

class OnlineGameViewController: UIViewController {
    
    // UI Elements
    var roomLabel: UILabel!
    var secretLabel: UILabel!
    var turnLabel: UILabel!
    var guessTextField: UITextField!
    var submitButton: UIButton!
    var leaveButton: UIButton!
    var keypadButtons: [UIButton] = []
    var allKeypadButtons: [UIButton] = [] // Separate array for ALL buttons including clear
    var historyContainer: UIStackView!
    
    // Game state properties  
    var roomId: String = ""
    var playerId: String = ""
    var digits: Int = 0
    var currentTurn: String = ""
    var gameState: String = ""
    var isMyTurn: Bool = false
    var gameTimer: Timer?
    var yourSecret: String = ""
    var opponentSecret: String = "" // For continue guessing mode
    var lastHistoryHash: Int = 0 // For smart history updates
    
    // Network
    let baseURL = "https://minddigit-server.vercel.app/api"
    
    // Network recovery properties
    var retryCount = 0
    let maxRetries = 3
    var isRecovering = false
    var lastSuccessfulResponse: [String: Any]?
    
    // Aggressive polling properties
    var aggressivePollingTimer: Timer?
    var aggressivePollingCount = 0
    let maxAggressivePolls = 5
    
    // Ultra-smooth gaming properties
    var pendingOptimisticUpdates: [String: Any] = [:]
    var ultraFastTimer: Timer?
    var backgroundSyncTimer: Timer?
    var sharedURLSession: URLSession!
    var performanceMetrics: [String: Any] = [:]

    // Network optimization properties
    var lastQuickCheckTime: TimeInterval = 0
    var isQuickCheckInProgress = false
    var isBackgroundSyncInProgress = false
    var adaptivePollingEnabled = true

    // 🎯 CLIENT-SIDE CACHE & ADAPTIVE POLLING
    var cachedGameHistory: [[String: Any]] = []
    var lastHistorySync: TimeInterval = 0
    var historyCache: [String: Any] = [:]
    var currentHistorySignature: Int = 0
    
    // 🎯 PERSISTENT HISTORY TRACKING
    var displayedHistoryEntries: [[String: Any]] = [] // Track what's currently shown
    var historyRefreshButton: UIButton!
    
    // Network Health Tracking
    var networkHealth: [String: Any] = [
        "successRate": 1.0,
        "avgResponseTime": 0.0,
        "consecutiveErrors": 0,
        "totalRequests": 0,
        "successfulRequests": 0
    ]
    
    // Adaptive Polling Configuration
    var adaptivePollingConfig: [String: Any] = [
        "baseInterval": 0.5,
        "currentInterval": 0.5,
        "minInterval": 0.2,
        "maxInterval": 5.0,
        "errorMultiplier": 1.5,
        "successDivider": 1.2
    ]
    
    // Silent Retry System
    var silentRetryConfig: [String: Any] = [
        "maxConsecutiveErrors": 10,
        "retryDelay": 1.0,
        "exponentialBackoff": false,
        "showSubtleIndicator": true
    ]
    
    // 🎯 CONNECTION QUALITY INDICATOR
    private let connectionIndicator = UIView()
    private let connectionLabel = UILabel()
    private let performanceLabel = UILabel()
    
    // Request Prioritization
    var requestQueue: [String] = []
    var isProcessingHighPriority = false
    
    // UI Background
    private let backgroundImageView = UIImageView()
    private let backgroundOverlay = UIView()
    
    // UI Sections
    private let titleLabel = UILabel()
    private let gameInfoCard = UIView()
    
    // Game Board
    private let gameBoardContainer = UIView()
    private let keypadContainer = UIView()
    
    // History
    private let historyTitleLabel = UILabel()
    let historyScrollView = UIScrollView()
    let historyStackView = UIStackView()
    
    // Control buttons
    let loadingSpinner = UIActivityIndicatorView(style: .large)
    private let refreshButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupRefreshButton()
        
        // Setup history after UI is complete with longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setupHistoryDelayed()
        }
        
        // Start polling after everything is set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.startGamePolling()
        }
        
        // 🎯 Setup connection quality indicator
        setupConnectionIndicator()
        
        print("🎮 OnlineGameViewController fully loaded and configured")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        gameTimer?.invalidate()
    }
    
    // MARK: - Configuration
    func configure(roomId: String, playerId: String, digits: Int) {
        self.roomId = roomId
        self.playerId = playerId
        self.digits = digits
        print("🎯 OnlineGameViewController configured:")
        print("   Room: \(roomId)")
        print("   Player: \(playerId)")  
        print("   Digits: \(digits)")
        
        // Update room label immediately with safety check - only if view is loaded
        if Thread.isMainThread && isViewLoaded {
            if let roomLabel = self.roomLabel, roomLabel.superview != nil {
                roomLabel.text = "MISSION ID: \(roomId)"
            }
            if let secretLabel = self.secretLabel, secretLabel.superview != nil {
                secretLabel.text = "🔐 SECURITY PROTOCOL: ACTIVE"
            }
        } else if isViewLoaded {
            DispatchQueue.main.async {
                if let roomLabel = self.roomLabel, roomLabel.superview != nil {
                    roomLabel.text = "MISSION ID: \(roomId)"
                }
                if let secretLabel = self.secretLabel, secretLabel.superview != nil {
                    secretLabel.text = "🔐 SECURITY PROTOCOL: ACTIVE"
                }
            }
        } else {
            print("⚠️ View not loaded yet in configure(), skipping UI updates")
        }
    }
    
    func updateTurnUI() {
        print("🔄 updateTurnUI called: currentTurn='\(currentTurn)', playerId='\(playerId)', isMyTurn=\(isMyTurn), gameState=\(gameState)")
        
        // MUST be called from main thread only - no more nested dispatches
        assert(Thread.isMainThread, "updateTurnUI() must be called from main thread")
        
        // Don't update turn UI if we're in continue guessing mode - preserve continue mode UI
        if gameState == "CONTINUE_GUESSING" {
            print("🛑 BLOCKED: updateTurnUI - in continue guessing mode, preserving UI")
            return
        }
        
        // If no turn is set and we have players, auto-assign first turn
        if currentTurn.isEmpty && !playerId.isEmpty {
            print("🎯 Auto-assigning turn to first player: \(playerId)")
            currentTurn = playerId
            isMyTurn = true
            
            // Send turn assignment to server
            assignFirstTurn()
        }
        
        // Update turn label safely
        guard let turnLabel = self.turnLabel else {
            print("⚠️ turnLabel not initialized")
            return
        }
        
        if isMyTurn {
            turnLabel.text = "🎯 WEAPONS ARMED • READY TO FIRE"
            turnLabel.textColor = UIColor(red: 0.2, green: 0.9, blue: 0.3, alpha: 1.0) // SpaceX green
        } else {
            turnLabel.text = "⏳ AWAITING TARGET LOCK"
            turnLabel.textColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0) // Orange alert
        }
        
        // Display field styling based on turn - with safety checks
        guard let guessTextField = self.guessTextField else {
            print("⚠️ guessTextField not initialized")
            return
        }
        
        if isMyTurn {
            guessTextField.layer.borderColor = UIColor.systemGreen.cgColor
            guessTextField.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        } else {
            guessTextField.layer.borderColor = UIColor.systemGray4.cgColor
            guessTextField.backgroundColor = UIColor.systemGray6
        }
        
        // Enable/disable controls safely
        guard let submitButton = self.submitButton else {
            print("⚠️ submitButton not initialized")
            return
        }
        
        let currentText = guessTextField.text ?? ""
        let hasValidInput = (currentText.count == digits)
        
        submitButton.isEnabled = isMyTurn && hasValidInput
        submitButton.alpha = isMyTurn ? 1.0 : 0.5
        
        print("🎯 Submit button state: enabled=\(submitButton.isEnabled), text='\(currentText)' (\(currentText.count)/\(digits))")
        
        // Enable/disable ALL keypad buttons with safe UI updates
        updateKeypadButtonsState()
        
        print("🎯 UI updated - Turn: \(isMyTurn ? "MY TURN" : "OPPONENT'S TURN"), Submit enabled: \(submitButton.isEnabled)")
    }
    
    func updateKeypadButtonsState() {
        // MUST be on main thread
        assert(Thread.isMainThread, "updateKeypadButtonsState() must be called from main thread")
        
        print("🔧 updateKeypadButtonsState called - gameState: \(gameState), isMyTurn: \(isMyTurn)")
        
        guard !allKeypadButtons.isEmpty else {
            print("⚠️ Keypad buttons not initialized yet")
            return
        }
        
        // Filter valid buttons - no UI access in loop
        let validButtons = allKeypadButtons.filter { $0.superview != nil }
        
        guard !validButtons.isEmpty else {
            print("⚠️ No valid keypad buttons found")
            return
        }
        
        // Update button states immediately - no animation to prevent conflicts
        // Enable buttons if it's my turn OR we're in continue guessing mode
        let buttonsEnabled = isMyTurn || gameState == "CONTINUE_GUESSING"
        
        print("🎯 Setting keypad buttons enabled: \(buttonsEnabled) (turn: \(isMyTurn), continue mode: \(gameState == "CONTINUE_GUESSING"))")
        
        for button in validButtons {
            button.isEnabled = buttonsEnabled
            
            // Immediate visual update - no animation to prevent thread issues
            if buttonsEnabled {
                button.alpha = 1.0
                button.transform = CGAffineTransform.identity
            } else {
                button.alpha = 0.4
                button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        }
        
        print("✅ Updated \(validButtons.count) keypad buttons - enabled: \(buttonsEnabled)")
    }
    
    func assignFirstTurn() {
        let url = URL(string: "\(baseURL)/game/assign-turn-local")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "roomId": roomId,
            "playerId": playerId,
            "turnPlayer": playerId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("🎯 Assigning turn to: \(playerId)")
            
            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                if let error = error {
                    print("❌ Error assigning turn: \(error)")
                    return
                }
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ Turn assignment response: \(json)")
                }
            }.resume()
        } catch {
            print("❌ Error creating turn assignment request: \(error)")
        }
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .systemBackground
        setupBackground()
        setupTitleSection()
        setupGameInfo()
        setupGameBoard()
        setupKeypad()
        setupControlButtons()
        setupRefreshButton() // Add refresh button
        // setupHistory() // Temporarily disabled to avoid crash
        setupConstraints()
    }
    
    private func setupRefreshButton() {
        refreshButton.setTitle("🔄", for: .normal)
        refreshButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        refreshButton.setTitleColor(.white, for: .normal)
        refreshButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        refreshButton.layer.cornerRadius = 20
        refreshButton.layer.borderWidth = 2
        refreshButton.layer.borderColor = UIColor.systemCyan.cgColor
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add glow effect
        refreshButton.layer.shadowColor = UIColor.systemBlue.cgColor
        refreshButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        refreshButton.layer.shadowOpacity = 0.6
        refreshButton.layer.shadowRadius = 8
        
        refreshButton.addTarget(self, action: #selector(manualRefresh), for: .touchUpInside)
        view.addSubview(refreshButton)
        
        NSLayoutConstraint.activate([
            refreshButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 15),
            refreshButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            refreshButton.widthAnchor.constraint(equalToConstant: 40),
            refreshButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc func manualRefresh() {
        print("🔄 Manual refresh triggered")
        
        // Visual feedback
        refreshButton.setTitle("🔄", for: .normal)
        refreshButton.isEnabled = false
        
        // Reset network health and fetch fresh data
        initializeNetworkHealth()
        
        // Force fresh fetch from server
        fetchGameStateWithSilentRetry()
        fetchGameHistory()
        
        // Re-enable refresh button after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.refreshButton.setTitle("🔄", for: .normal)
            self.refreshButton.isEnabled = true
        }
    }
    
    // MARK: - 🎯 Connection Quality Indicator
    
    private func setupConnectionIndicator() {
        // Connection indicator setup
        connectionIndicator.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        connectionIndicator.layer.cornerRadius = 6
        connectionIndicator.clipsToBounds = true
        
        connectionLabel.text = "🟢 Excellent"
        connectionLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        connectionLabel.textColor = .white
        connectionLabel.textAlignment = .center
        
        performanceLabel.text = "⚡ 200ms"
        performanceLabel.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        performanceLabel.textColor = .white.withAlphaComponent(0.8)
        performanceLabel.textAlignment = .center
        
        // Add to view hierarchy
        view.addSubview(connectionIndicator)
        connectionIndicator.addSubview(connectionLabel)
        connectionIndicator.addSubview(performanceLabel)
        
        // Setup constraints
        connectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        connectionLabel.translatesAutoresizingMaskIntoConstraints = false
        performanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Position in top-left corner, below safe area
            connectionIndicator.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            connectionIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            connectionIndicator.heightAnchor.constraint(equalToConstant: 44),
            connectionIndicator.widthAnchor.constraint(equalToConstant: 120),
            
            // Connection label layout
            connectionLabel.topAnchor.constraint(equalTo: connectionIndicator.topAnchor, constant: 4),
            connectionLabel.leadingAnchor.constraint(equalTo: connectionIndicator.leadingAnchor, constant: 8),
            connectionLabel.trailingAnchor.constraint(equalTo: connectionIndicator.trailingAnchor, constant: -8),
            connectionLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // Performance label layout
            performanceLabel.topAnchor.constraint(equalTo: connectionLabel.bottomAnchor),
            performanceLabel.leadingAnchor.constraint(equalTo: connectionIndicator.leadingAnchor, constant: 8),
            performanceLabel.trailingAnchor.constraint(equalTo: connectionIndicator.trailingAnchor, constant: -8),
            performanceLabel.bottomAnchor.constraint(equalTo: connectionIndicator.bottomAnchor, constant: -4)
        ])
        
        // Start with hidden state
        connectionIndicator.alpha = 0.0
        
        // Fade in after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UIView.animate(withDuration: 0.3) {
                self.connectionIndicator.alpha = 1.0
            }
        }
        
        print("🎯 Connection quality indicator setup complete")
    }
    
    func updateConnectionQuality(successRate: Double, avgResponseTime: Double, consecutiveErrors: Int) {
        DispatchQueue.main.async {
            let quality = self.determineConnectionQuality(successRate: successRate, avgResponseTime: avgResponseTime, consecutiveErrors: consecutiveErrors)
            
            UIView.animate(withDuration: 0.3) {
                self.connectionIndicator.backgroundColor = quality.color
                self.connectionLabel.text = quality.text
                self.performanceLabel.text = "⚡ \(Int(avgResponseTime))ms"
            }
            
            // Auto-hide if quality is excellent for extended period
            if quality.level == "excellent" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    UIView.animate(withDuration: 0.5) {
                        self.connectionIndicator.alpha = 0.3
                    }
                }
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.connectionIndicator.alpha = 1.0
                }
            }
        }
    }
    
    private func determineConnectionQuality(successRate: Double, avgResponseTime: Double, consecutiveErrors: Int) -> (level: String, text: String, color: UIColor) {
        if consecutiveErrors >= 5 {
            return ("poor", "🔴 Poor", UIColor.systemRed.withAlphaComponent(0.8))
        } else if successRate < 0.7 || avgResponseTime > 3000 {
            return ("fair", "🟡 Fair", UIColor.systemOrange.withAlphaComponent(0.8))
        } else if successRate < 0.9 || avgResponseTime > 1000 {
            return ("good", "🟠 Good", UIColor.systemYellow.withAlphaComponent(0.8))
        } else {
            return ("excellent", "🟢 Excellent", UIColor.systemGreen.withAlphaComponent(0.8))
        }
    }
    
    private func setupBackground() {
        // SpaceX Dark Space Background
        view.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0) // Very dark space blue
        
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)
        
        backgroundOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundOverlay)
        
        // SpaceX-inspired gradient - dark space to lighter cosmic blue
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.03, green: 0.07, blue: 0.15, alpha: 0.95).cgColor, // Deep space
            UIColor(red: 0.08, green: 0.12, blue: 0.25, alpha: 0.9).cgColor,  // Mid space
            UIColor(red: 0.15, green: 0.20, blue: 0.35, alpha: 0.85).cgColor, // Cosmic blue
            UIColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 0.9).cgColor   // Return to deep
        ]
        gradientLayer.locations = [0.0, 0.3, 0.7, 1.0]
        gradientLayer.type = .radial
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.3)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        backgroundOverlay.layer.addSublayer(gradientLayer)
        
        // Add subtle star-like dots pattern
        let starLayer = CAShapeLayer()
        let starPath = UIBezierPath()
        
        // Create random star positions
        for _ in 0..<50 {
            let x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
            let y = CGFloat.random(in: 0...UIScreen.main.bounds.height)
            starPath.addArc(withCenter: CGPoint(x: x, y: y), radius: 1, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        }
        
        starLayer.path = starPath.cgPath
        starLayer.fillColor = UIColor.white.withAlphaComponent(0.7).cgColor
        backgroundOverlay.layer.addSublayer(starLayer)
        
        DispatchQueue.main.async {
            gradientLayer.frame = self.backgroundOverlay.bounds
        }
    }
    
    private func setupTitleSection() {
        // SpaceX Mission Style Title
        titleLabel.text = "🚀 DRAGON MISSION • BATTLE ARENA"
        titleLabel.font = UIFont(name: "Menlo-Bold", size: 18) ?? UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0) // Cool white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // SpaceX-style futuristic glow effect
        titleLabel.layer.shadowColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0).cgColor // Blue glow
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
        titleLabel.layer.shadowOpacity = 0.8
        titleLabel.layer.shadowRadius = 8
        
        // Add subtle border frame around title
        let titleContainer = UIView()
        titleContainer.backgroundColor = UIColor.clear
        titleContainer.layer.borderWidth = 1
        titleContainer.layer.borderColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.6).cgColor
        titleContainer.layer.cornerRadius = 12
        titleContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleContainer)
        
        titleContainer.addSubview(titleLabel)
        
        // Mission status indicator
        let statusIndicator = UIView()
        statusIndicator.backgroundColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0) // SpaceX green
        statusIndicator.layer.cornerRadius = 4
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addSubview(statusIndicator)
        
        // Animate status indicator
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 0.3
        pulseAnimation.toValue = 1.0
        pulseAnimation.duration = 1.0
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.autoreverses = true
        statusIndicator.layer.add(pulseAnimation, forKey: "pulse")
        
        view.addSubview(titleLabel)
        
        // SpaceX-style loading spinner
        loadingSpinner.color = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
        loadingSpinner.style = .large
        loadingSpinner.hidesWhenStopped = true
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingSpinner)
        
        NSLayoutConstraint.activate([
            titleContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            titleContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleContainer.widthAnchor.constraint(equalToConstant: 320),
            titleContainer.heightAnchor.constraint(equalToConstant: 45),
            
            titleLabel.centerXAnchor.constraint(equalTo: titleContainer.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            
            statusIndicator.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor, constant: 12),
            statusIndicator.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 8),
            statusIndicator.heightAnchor.constraint(equalToConstant: 8)
        ])
    }
    
    private func setupGameInfo() {
        // Initialize UI elements
        roomLabel = UILabel()
        turnLabel = UILabel()
        secretLabel = UILabel()
        
        // SpaceX Mission Control Panel Style
        gameInfoCard.backgroundColor = UIColor(red: 0.08, green: 0.12, blue: 0.18, alpha: 0.9)
        gameInfoCard.layer.cornerRadius = 16
        gameInfoCard.layer.borderWidth = 2
        gameInfoCard.layer.borderColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.8).cgColor
        
        // Add inner glow effect
        gameInfoCard.layer.shadowColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.5).cgColor
        gameInfoCard.layer.shadowOffset = CGSize(width: 0, height: 0)
        gameInfoCard.layer.shadowOpacity = 0.6
        gameInfoCard.layer.shadowRadius = 12
        
        // Add subtle inner border
        let innerBorder = CALayer()
        innerBorder.borderColor = UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 0.3).cgColor
        innerBorder.borderWidth = 1
        innerBorder.cornerRadius = 14
        gameInfoCard.layer.addSublayer(innerBorder)
        
        gameInfoCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gameInfoCard)
        
        // Room Label - Mission ID Style
        roomLabel.text = "MISSION ID: ----"
        roomLabel.font = UIFont(name: "Menlo-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13, weight: .medium)
        roomLabel.textColor = UIColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0) // SpaceX blue
        roomLabel.textAlignment = .center
        roomLabel.translatesAutoresizingMaskIntoConstraints = false
        gameInfoCard.addSubview(roomLabel)
        
        // Turn Label - Status Display Style
        turnLabel.text = "⚡ SYSTEM STANDBY"
        turnLabel.font = UIFont(name: "Menlo-Bold", size: 15) ?? UIFont.systemFont(ofSize: 15, weight: .bold)
        turnLabel.textColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0) // Warm orange
        turnLabel.textAlignment = .center
        turnLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add pulsing effect for turn label
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 0.6
        pulseAnimation.toValue = 1.0
        pulseAnimation.duration = 1.2
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.autoreverses = true
        turnLabel.layer.add(pulseAnimation, forKey: "statusPulse")
        
        gameInfoCard.addSubview(turnLabel)
        
        // Secret Label - Security Status Style
        secretLabel.text = "🔐 SECURITY PROTOCOL: INACTIVE"
        secretLabel.font = UIFont(name: "Menlo-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .regular)
        secretLabel.textColor = UIColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 0.8) // Light gray-blue
        secretLabel.textAlignment = .center
        secretLabel.translatesAutoresizingMaskIntoConstraints = false
        gameInfoCard.addSubview(secretLabel)
        
        NSLayoutConstraint.activate([
            roomLabel.topAnchor.constraint(equalTo: gameInfoCard.topAnchor, constant: 8),
            roomLabel.leadingAnchor.constraint(equalTo: gameInfoCard.leadingAnchor, constant: 15),
            roomLabel.trailingAnchor.constraint(equalTo: gameInfoCard.trailingAnchor, constant: -15),
            
            turnLabel.topAnchor.constraint(equalTo: roomLabel.bottomAnchor, constant: 5),
            turnLabel.leadingAnchor.constraint(equalTo: gameInfoCard.leadingAnchor, constant: 15),
            turnLabel.trailingAnchor.constraint(equalTo: gameInfoCard.trailingAnchor, constant: -15),
            
            secretLabel.topAnchor.constraint(equalTo: turnLabel.bottomAnchor, constant: 5),
            secretLabel.leadingAnchor.constraint(equalTo: gameInfoCard.leadingAnchor, constant: 15),
            secretLabel.trailingAnchor.constraint(equalTo: gameInfoCard.trailingAnchor, constant: -15),
            secretLabel.bottomAnchor.constraint(equalTo: gameInfoCard.bottomAnchor, constant: -8)
        ])
    }
    
    private func setupGameBoard() {
        // Initialize UI elements
        guessTextField = UITextField()
        submitButton = UIButton(type: .system)
        
        // SpaceX Command Console Style
        gameBoardContainer.backgroundColor = UIColor(red: 0.06, green: 0.1, blue: 0.16, alpha: 0.95)
        gameBoardContainer.layer.cornerRadius = 18
        gameBoardContainer.layer.borderWidth = 2
        gameBoardContainer.layer.borderColor = UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.8).cgColor
        
        // Add command console glow
        gameBoardContainer.layer.shadowColor = UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.4).cgColor
        gameBoardContainer.layer.shadowOffset = CGSize(width: 0, height: 0)
        gameBoardContainer.layer.shadowOpacity = 0.8
        gameBoardContainer.layer.shadowRadius = 10
        
        gameBoardContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gameBoardContainer)
        
        // SpaceX Display Terminal Style
        guessTextField.placeholder = "◦ ◦ ◦ ◦"
        guessTextField.borderStyle = .none
        guessTextField.textAlignment = .center
        guessTextField.font = UIFont(name: "Menlo-Bold", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .bold)
        guessTextField.backgroundColor = UIColor(red: 0.02, green: 0.05, blue: 0.12, alpha: 1.0) // Very dark screen
        guessTextField.textColor = UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1.0) // Matrix green
        guessTextField.translatesAutoresizingMaskIntoConstraints = false
        guessTextField.addTarget(self, action: #selector(guessTextChanged), for: .editingChanged)
        
        // Terminal screen styling
        guessTextField.layer.borderWidth = 3
        guessTextField.layer.borderColor = UIColor(red: 0.1, green: 0.4, blue: 0.7, alpha: 0.8).cgColor
        guessTextField.layer.cornerRadius = 12
        
        // Add screen glow effect
        guessTextField.layer.shadowColor = UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 0.6).cgColor
        guessTextField.layer.shadowOffset = CGSize(width: 0, height: 0)
        guessTextField.layer.shadowOpacity = 0.8
        guessTextField.layer.shadowRadius = 8
        
        // Disable direct input - keypad only
        guessTextField.isUserInteractionEnabled = false
        gameBoardContainer.addSubview(guessTextField)
        
        // SpaceX Launch Button Style
        submitButton.setTitle("🚀 LAUNCH ATTACK", for: .normal)
        submitButton.backgroundColor = UIColor(red: 0.9, green: 0.3, blue: 0.1, alpha: 0.9) // SpaceX red-orange
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = UIFont(name: "Menlo-Bold", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        submitButton.layer.cornerRadius = 14
        submitButton.layer.borderWidth = 2
        submitButton.layer.borderColor = UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 1.0).cgColor
        
        // Launch button glow
        submitButton.layer.shadowColor = UIColor(red: 0.9, green: 0.3, blue: 0.1, alpha: 0.8).cgColor
        submitButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        submitButton.layer.shadowOpacity = 0.8
        submitButton.layer.shadowRadius = 6
        
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        submitButton.addTarget(self, action: #selector(submitGuess), for: .touchUpInside)
        gameBoardContainer.addSubview(submitButton)
        
        NSLayoutConstraint.activate([
            guessTextField.topAnchor.constraint(equalTo: gameBoardContainer.topAnchor, constant: 8),
            guessTextField.leadingAnchor.constraint(equalTo: gameBoardContainer.leadingAnchor, constant: 12),
            guessTextField.trailingAnchor.constraint(equalTo: gameBoardContainer.trailingAnchor, constant: -12),
            guessTextField.heightAnchor.constraint(equalToConstant: 32),
            
            submitButton.topAnchor.constraint(equalTo: guessTextField.bottomAnchor, constant: 6),
            submitButton.centerXAnchor.constraint(equalTo: gameBoardContainer.centerXAnchor),
            submitButton.widthAnchor.constraint(equalToConstant: 110),
            submitButton.heightAnchor.constraint(equalToConstant: 28)
            // Remove bottom constraint to prevent conflict
        ])
    }
    
    private func setupKeypad() {
        keypadContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keypadContainer)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        keypadContainer.addSubview(stackView)
        
        // Clear existing buttons to prevent duplicates
        keypadButtons.removeAll()
        allKeypadButtons.removeAll()
        
        // Create keypad buttons (0-9)
        for row in 0..<4 {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 10
            
            if row < 3 {
                // Rows 0-2: numbers 7-9, 4-6, 1-3
                let startNumber = 7 - (row * 3)
                for col in 0..<3 {
                    let number = startNumber + col
                    let button = createKeypadButton(number: number)
                    rowStack.addArrangedSubview(button)
                    keypadButtons.append(button)
                    allKeypadButtons.append(button)
                }
            } else {
                // Row 3: 0 and Clear
                let zeroButton = createKeypadButton(number: 0)
                let spacer = UIView()
                let clearButton = createClearButton()
                
                rowStack.addArrangedSubview(zeroButton)
                rowStack.addArrangedSubview(spacer)
                rowStack.addArrangedSubview(clearButton)
                
                // Add both buttons to arrays
                keypadButtons.append(zeroButton)
                allKeypadButtons.append(zeroButton)
                allKeypadButtons.append(clearButton)
            }
            
            stackView.addArrangedSubview(rowStack)
        }
        
        print("🔢 Keypad setup complete with \(keypadButtons.count) number buttons and \(allKeypadButtons.count) total buttons")
        
        // Apply constraints with error handling
        do {
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: keypadContainer.topAnchor, constant: 4),
                stackView.leadingAnchor.constraint(equalTo: keypadContainer.leadingAnchor, constant: 4),
                stackView.trailingAnchor.constraint(equalTo: keypadContainer.trailingAnchor, constant: -4),
                stackView.bottomAnchor.constraint(lessThanOrEqualTo: keypadContainer.bottomAnchor, constant: -4)
            ])
            print("✅ Keypad constraints applied successfully")
        } catch {
            print("❌ Keypad constraint error: \(error)")
        }
    }
    
    private func createKeypadButton(number: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("\(number)", for: .normal)
        
        // SpaceX Control Panel Button Style
        button.backgroundColor = UIColor(red: 0.08, green: 0.15, blue: 0.25, alpha: 0.9) // Dark space blue
        button.setTitleColor(UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0), for: .normal) // Cool white
        button.titleLabel?.font = UIFont(name: "Menlo-Bold", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .bold)
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.7).cgColor
        
        // Add button glow effect
        button.layer.shadowColor = UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.5).cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 0)
        button.layer.shadowOpacity = 0.6
        button.layer.shadowRadius = 4
        
        // Add inner highlight
        let highlightLayer = CAGradientLayer()
        highlightLayer.colors = [
            UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.3).cgColor,
            UIColor(red: 0.1, green: 0.2, blue: 0.4, alpha: 0.1).cgColor
        ]
        highlightLayer.cornerRadius = 16
        button.layer.insertSublayer(highlightLayer, at: 0)
        
        button.tag = number
        button.addTarget(self, action: #selector(keypadNumberTapped(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: 36)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true
        
        // Add touch animation
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        
        DispatchQueue.main.async {
            highlightLayer.frame = button.bounds
        }
        
        return button
    }
    
    private func createClearButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("🗑 CLEAR", for: .normal)
        
        // SpaceX Emergency/Reset Button Style
        button.backgroundColor = UIColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 0.9) // Emergency red
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont(name: "Menlo-Bold", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .bold)
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 0.8).cgColor
        
        // Emergency button glow
        button.layer.shadowColor = UIColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 0.7).cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 0)
        button.layer.shadowOpacity = 0.8
        button.layer.shadowRadius = 6
        
        // Warning stripes pattern
        let stripesLayer = CAShapeLayer()
        let stripesPath = UIBezierPath()
        for i in stride(from: -20, to: 60, by: 8) {
            stripesPath.move(to: CGPoint(x: i, y: 0))
            stripesPath.addLine(to: CGPoint(x: i + 4, y: 0))
            stripesPath.addLine(to: CGPoint(x: i + 8, y: 36))
            stripesPath.addLine(to: CGPoint(x: i + 4, y: 36))
            stripesPath.close()
        }
        stripesLayer.path = stripesPath.cgPath
        stripesLayer.fillColor = UIColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 0.3).cgColor
        button.layer.addSublayer(stripesLayer)
        
        button.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: 36)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true
        
        // Add touch animation
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        
        return button
    }
    
    func setupHistory() {
        print("📜 setupHistory: Starting...")
        
        // Ensure leaveButton is initialized
        guard let leaveButton = leaveButton else {
            print("❌ setupHistory: leaveButton is nil!")
            return
        }
        print("✅ setupHistory: leaveButton is available")
        
        let historyLabel = UILabel()
        historyLabel.text = "Game History"
        historyLabel.font = UIFont.boldSystemFont(ofSize: 18)
        historyLabel.textColor = .label
        historyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(historyLabel)
        
        // Create history container as UIStackView
        historyContainer = UIStackView()
        historyContainer.axis = .vertical
        historyContainer.spacing = 4
        historyContainer.distribution = .equalSpacing
        historyContainer.alignment = .fill
        historyContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.addSubview(historyContainer)
        view.addSubview(scrollView)
        
        print("📜 setupHistory: About to create constraints...")
        
        do {
            NSLayoutConstraint.activate([
                // History label
                historyLabel.topAnchor.constraint(equalTo: leaveButton.bottomAnchor, constant: 20),
                historyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                historyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                
                // Scroll view
                scrollView.topAnchor.constraint(equalTo: historyLabel.bottomAnchor, constant: 10),
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                
                // History container in scroll view
                historyContainer.topAnchor.constraint(equalTo: scrollView.topAnchor),
                historyContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                historyContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                historyContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                historyContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
            ])
            print("✅ setupHistory: Constraints activated successfully")
        } catch {
            print("❌ setupHistory: Constraint error: \(error)")
        }
        
        print("✅ setupHistory: Completed successfully")
    }
    
    func setupHistoryDelayed() {
        print("📜 setupHistoryDelayed: Starting...")
        
        // Ensure all required elements are available
        guard let leaveButton = leaveButton else {
            print("❌ setupHistoryDelayed: leaveButton is nil!")
            return
        }
        
        guard leaveButton.superview != nil else {
            print("❌ setupHistoryDelayed: leaveButton not in view hierarchy!")
            return
        }
        
        print("✅ setupHistoryDelayed: All prerequisites met")
        
        // SpaceX Mission Log Style
        let historyCard = UIView()
        historyCard.backgroundColor = UIColor(red: 0.06, green: 0.1, blue: 0.16, alpha: 0.95)
        historyCard.layer.cornerRadius = 18
        historyCard.layer.borderWidth = 2
        historyCard.layer.borderColor = UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.8).cgColor
        
        // Add SpaceX mission log glow
        historyCard.layer.shadowColor = UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.4).cgColor
        historyCard.layer.shadowOffset = CGSize(width: 0, height: 0)
        historyCard.layer.shadowOpacity = 0.8
        historyCard.layer.shadowRadius = 12
        
        historyCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(historyCard)
        
        let historyLabel = UILabel()
        historyLabel.text = "📡 MISSION LOG • BATTLE DATA"
        historyLabel.font = UIFont(name: "Menlo-Bold", size: 16) ?? UIFont.boldSystemFont(ofSize: 16)
        historyLabel.textColor = UIColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0) // SpaceX blue
        historyLabel.textAlignment = .center
        historyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // SpaceX glow effect for mission log title
        historyLabel.layer.shadowColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0).cgColor
        historyLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
        historyLabel.layer.shadowOpacity = 0.8
        historyLabel.layer.shadowRadius = 6
        
        historyCard.addSubview(historyLabel)
        
        // 🎯 MANUAL HISTORY REFRESH BUTTON
        historyRefreshButton = UIButton(type: .system)
        historyRefreshButton.setTitle("🔄 REFRESH", for: .normal)
        historyRefreshButton.titleLabel?.font = UIFont(name: "Menlo-Bold", size: 12) ?? UIFont.boldSystemFont(ofSize: 12)
        historyRefreshButton.setTitleColor(UIColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0), for: .normal)
        historyRefreshButton.backgroundColor = UIColor(red: 0.06, green: 0.1, blue: 0.16, alpha: 0.8)
        historyRefreshButton.layer.cornerRadius = 12
        historyRefreshButton.layer.borderWidth = 1
        historyRefreshButton.layer.borderColor = UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.6).cgColor
        historyRefreshButton.translatesAutoresizingMaskIntoConstraints = false
        historyRefreshButton.addTarget(self, action: #selector(manualRefreshHistory), for: .touchUpInside)
        
        // SpaceX glow effect for refresh button
        historyRefreshButton.layer.shadowColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.6).cgColor
        historyRefreshButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        historyRefreshButton.layer.shadowOpacity = 0.6
        historyRefreshButton.layer.shadowRadius = 4
        
        historyCard.addSubview(historyRefreshButton)
        
        // Create history container as UIStackView - Better spacing for content
        historyContainer = UIStackView()
        historyContainer.axis = .vertical
        historyContainer.spacing = 8
        historyContainer.distribution = .equalSpacing
        historyContainer.alignment = .fill
        historyContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.backgroundColor = UIColor.clear
        scrollView.addSubview(historyContainer)
        historyCard.addSubview(scrollView)
        
        print("📜 setupHistoryDelayed: Creating constraints...")
        
        NSLayoutConstraint.activate([
            // History card - Make it taller and wider
            historyCard.topAnchor.constraint(equalTo: leaveButton.bottomAnchor, constant: 15),
            historyCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            historyCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            historyCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            
            // History label - Compact
            historyLabel.topAnchor.constraint(equalTo: historyCard.topAnchor, constant: 12),
            historyLabel.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 15),
            historyLabel.trailingAnchor.constraint(equalTo: historyRefreshButton.leadingAnchor, constant: -10),
            
            // 🎯 REFRESH BUTTON CONSTRAINTS
            historyRefreshButton.topAnchor.constraint(equalTo: historyCard.topAnchor, constant: 10),
            historyRefreshButton.trailingAnchor.constraint(equalTo: historyCard.trailingAnchor, constant: -15),
            historyRefreshButton.widthAnchor.constraint(equalToConstant: 80),
            historyRefreshButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Scroll view - Maximum space for content
            scrollView.topAnchor.constraint(equalTo: historyRefreshButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: historyCard.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: historyCard.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: historyCard.bottomAnchor, constant: -8),
            
            // History container in scroll view
            historyContainer.topAnchor.constraint(equalTo: scrollView.topAnchor),
            historyContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            historyContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            historyContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            historyContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        print("✅ setupHistoryDelayed: Completed successfully")
    }
    
    private func setupControlButtons() {
        print("🔧 setupControlButtons: Initializing leaveButton...")
        leaveButton = UIButton(type: .system)
        
        // SpaceX Abort Mission Button Style
        leaveButton.setTitle("⚠️ ABORT MISSION", for: .normal)
        leaveButton.backgroundColor = UIColor(red: 0.7, green: 0.15, blue: 0.05, alpha: 0.9) // Dark emergency red
        leaveButton.setTitleColor(.white, for: .normal)
        leaveButton.titleLabel?.font = UIFont(name: "Menlo-Bold", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        leaveButton.layer.cornerRadius = 16
        leaveButton.layer.borderWidth = 2
        leaveButton.layer.borderColor = UIColor(red: 1.0, green: 0.2, blue: 0.1, alpha: 0.9).cgColor
        
        // Emergency abort glow
        leaveButton.layer.shadowColor = UIColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 0.8).cgColor
        leaveButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        leaveButton.layer.shadowOpacity = 0.8
        leaveButton.layer.shadowRadius = 8
        
        // Warning pattern overlay
        let warningLayer = CAShapeLayer()
        let warningPath = UIBezierPath()
        for i in stride(from: -30, to: 150, by: 10) {
            warningPath.move(to: CGPoint(x: i, y: 0))
            warningPath.addLine(to: CGPoint(x: i + 5, y: 0))
            warningPath.addLine(to: CGPoint(x: i + 10, y: 36))
            warningPath.addLine(to: CGPoint(x: i + 5, y: 36))
            warningPath.close()
        }
        warningLayer.path = warningPath.cgPath
        warningLayer.fillColor = UIColor(red: 1.0, green: 0.3, blue: 0.2, alpha: 0.2).cgColor
        leaveButton.layer.addSublayer(warningLayer)
        
        leaveButton.translatesAutoresizingMaskIntoConstraints = false
        leaveButton.addTarget(self, action: #selector(leaveGame), for: .touchUpInside)
        
        // Add touch animation
        leaveButton.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        leaveButton.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        
        view.addSubview(leaveButton)
        print("✅ setupControlButtons: leaveButton initialized successfully")
    }
    
    // MARK: - Touch Animation Methods
    @objc private func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.allowUserInteraction, .curveEaseInOut], animations: {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 0.8
        })
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    @objc private func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [.allowUserInteraction, .curveEaseInOut], animations: {
            sender.transform = CGAffineTransform.identity
            sender.alpha = 1.0
        })
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Game info card - Smaller
            gameInfoCard.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            gameInfoCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            gameInfoCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            gameInfoCard.heightAnchor.constraint(equalToConstant: 80),
            
            // Game board - Smaller
            gameBoardContainer.topAnchor.constraint(equalTo: gameInfoCard.bottomAnchor, constant: 12),
            gameBoardContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            gameBoardContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            gameBoardContainer.heightAnchor.constraint(equalToConstant: 100),
            
            // Keypad - Smaller
            keypadContainer.topAnchor.constraint(equalTo: gameBoardContainer.bottomAnchor, constant: 12),
            keypadContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            keypadContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            keypadContainer.heightAnchor.constraint(equalToConstant: 130),
            
            // Leave button - Smaller
            leaveButton.topAnchor.constraint(equalTo: keypadContainer.bottomAnchor, constant: 12),
            leaveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            leaveButton.widthAnchor.constraint(equalToConstant: 120),
            leaveButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    // MARK: - History Management
    func updateHistory() {
        fetchGameHistory()
    }
    
    // 🎯 MANUAL HISTORY REFRESH
    @objc func manualRefreshHistory() {
        print("🔄 Manual history refresh triggered")
        
        // Visual feedback for button press
        UIView.animate(withDuration: 0.1, animations: {
            self.historyRefreshButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.historyRefreshButton.transform = CGAffineTransform.identity
            }
        }
        
        // Update button text to show loading
        historyRefreshButton.setTitle("🔄 ...", for: .normal)
        historyRefreshButton.isEnabled = false
        
        // Fetch new history and append only new entries
        fetchIncrementalHistory { [weak self] in
            DispatchQueue.main.async {
                self?.historyRefreshButton.setTitle("🔄 REFRESH", for: .normal)
                self?.historyRefreshButton.isEnabled = true
            }
        }
    }
    
    func updateTurnDisplay() {
        isMyTurn = (currentTurn == playerId)
        updateTurnUI()
    }
    
    func addHistoryEntry(_ entry: [String: Any]) {
        guard let playerName = entry["playerName"] as? String,
              let guess = entry["guess"] as? String,
              let bulls = entry["bulls"] as? Int,
              let cows = entry["cows"] as? Int else {
            return
        }
        
        let historyItemView = createHistoryItemView(playerName: playerName, guess: guess, bulls: bulls, cows: cows)
        historyContainer.addArrangedSubview(historyItemView)
    }
    
    // MARK: - Game Polling
    // stopGamePolling implementation in Network extension
    
    // 🎯 PLACEHOLDER REMOVED - Clean empty container approach
    // No more "mission standby" messages that flicker!
    
    func createHistoryItemView(playerName: String, guess: String, bulls: Int, cows: Int) -> UIView {
        let container = UIView()
        let isMe = playerName.lowercased().contains("player") && playerName.contains(playerId.suffix(4))
        
        // SpaceX Mission Data Entry Styling
        if bulls == digits {
            // Mission Success - SpaceX Green
            container.backgroundColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.3)
            container.layer.borderColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0).cgColor
            container.layer.borderWidth = 3
            
            // Mission success glow
            container.layer.shadowColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.8).cgColor
            container.layer.shadowOffset = CGSize(width: 0, height: 0)
            container.layer.shadowOpacity = 0.8
            container.layer.shadowRadius = 10
        } else if isMe {
            // Dragon Crew (Your moves) - SpaceX Blue
            container.backgroundColor = UIColor(red: 0.1, green: 0.3, blue: 0.5, alpha: 0.4)
            container.layer.borderColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.9).cgColor
            container.layer.borderWidth = 2
            
            // Your move glow
            container.layer.shadowColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.5).cgColor
            container.layer.shadowOffset = CGSize(width: 0, height: 0)
            container.layer.shadowOpacity = 0.6
            container.layer.shadowRadius = 6
        } else {
            // Enemy Craft (Opponent moves) - Warning Orange
            container.backgroundColor = UIColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 0.3)
            container.layer.borderColor = UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 0.9).cgColor
            container.layer.borderWidth = 2
            
            // Enemy move glow
            container.layer.shadowColor = UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 0.5).cgColor
            container.layer.shadowOffset = CGSize(width: 0, height: 0)
            container.layer.shadowOpacity = 0.6
            container.layer.shadowRadius = 6
        }
        
        container.layer.cornerRadius = 15
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Main stack view - Compact but readable
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // SpaceX Mission Operator Labels
        let playerLabel = UILabel()
        playerLabel.text = isMe ? "🚀 DRAGON CREW" : "⚠️ ENEMY CRAFT"
        playerLabel.font = UIFont(name: "Menlo-Bold", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .bold)
        
        if isMe {
            playerLabel.textColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0) // Cool white
            playerLabel.layer.shadowColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0).cgColor
        } else {
            playerLabel.textColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
            playerLabel.layer.shadowColor = UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 1.0).cgColor
        }
        
        // Add text shadow for better visibility
        playerLabel.layer.shadowOffset = CGSize(width: 1, height: 1)
        playerLabel.layer.shadowOpacity = 0.8
        playerLabel.layer.shadowRadius = 2
        
        // SpaceX Attack Data Display
        let guessLabel = UILabel()
        let bullsEmoji = String(repeating: "🎯", count: bulls)
        let cowsEmoji = String(repeating: "⚡", count: cows) // Lightning for SpaceX theme
        
        if bulls == digits {
            // Mission Accomplished!
            guessLabel.text = "🏆 TARGET ACQUIRED: \(guess) → MISSION SUCCESS!"
            guessLabel.textColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
            guessLabel.font = UIFont(name: "Menlo-Bold", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .heavy)
            
            // Mission success glow
            guessLabel.layer.shadowColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0).cgColor
            guessLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
            guessLabel.layer.shadowOpacity = 1.0
            guessLabel.layer.shadowRadius = 8
        } else {
            // Attack Analysis with SpaceX terminology
            var resultText = "ATTACK: \(guess) → "
            if bulls > 0 {
                resultText += "\(bulls) DIRECT HIT\(bulls > 1 ? "S" : "") 🎯"
            }
            if cows > 0 {
                if bulls > 0 { resultText += " " }
                resultText += "\(cows) GLANCING HIT\(cows > 1 ? "S" : "") ⚡"
            }
            if bulls == 0 && cows == 0 {
                resultText += "MISS • TARGET EVADED 🛡️"
            }
            
            guessLabel.text = resultText
            guessLabel.textColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
            guessLabel.font = UIFont(name: "Menlo-Regular", size: 13) ?? UIFont.systemFont(ofSize: 13, weight: .semibold)
            
            // Mission data glow
            guessLabel.layer.shadowColor = UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.8).cgColor
            guessLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
            guessLabel.layer.shadowOpacity = 0.8
            guessLabel.layer.shadowRadius = 4
        }
        
        // SpaceX Mission Analysis
        let explanationLabel = UILabel()
        if bulls == digits {
            explanationLabel.text = "🎊 MISSION ACCOMPLISHED • ALL SYSTEMS NOMINAL"
            explanationLabel.textColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
            explanationLabel.font = UIFont(name: "Menlo-Regular", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .bold)
        } else if bulls > 0 || cows > 0 {
            var analysis = "📊 DAMAGE REPORT: "
            if bulls > 0 {
                analysis += "\(bulls) critical hit\(bulls > 1 ? "s" : "") (correct position)"
            }
            if cows > 0 {
                if bulls > 0 { analysis += " • " }
                analysis += "\(cows) system damage (wrong position)"
            }
            explanationLabel.text = analysis
            explanationLabel.textColor = UIColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 1.0)
            explanationLabel.font = UIFont(name: "Menlo-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .medium)
        } else {
            explanationLabel.text = "🔄 TELEMETRY: All attack vectors missed target"
            explanationLabel.textColor = UIColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 1.0)
            explanationLabel.font = UIFont(name: "Menlo-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .medium)
        }
        
        explanationLabel.numberOfLines = 2
        
        // Add text shadow to explanation
        explanationLabel.layer.shadowColor = UIColor.black.cgColor
        explanationLabel.layer.shadowOffset = CGSize(width: 1, height: 1)
        explanationLabel.layer.shadowOpacity = 0.6
        explanationLabel.layer.shadowRadius = 1
        
        stackView.addArrangedSubview(playerLabel)
        stackView.addArrangedSubview(guessLabel)
        stackView.addArrangedSubview(explanationLabel)
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 75),
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        
        return container
    }
    
    func showGameOverAlert(won: Bool) {
        // Prevent duplicate modal displays
        guard !hasShownGameEndModal else {
            print("🛑 Game end modal already shown, skipping duplicate")
            return
        }
        
        hasShownGameEndModal = true
        print("✅ Setting hasShownGameEndModal = true")
        
        // Stop polling when game ends
        gameTimer?.invalidate()
        gameTimer = nil
        
        // Show custom modal instead of alert
        showGameEndModal(won: won)
        
        // Celebration haptic feedback
        if won {
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
    }
    
    private func showGameEndModal(won: Bool) {
        // Create modal background
        let modalBackground = UIView()
        modalBackground.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        modalBackground.translatesAutoresizingMaskIntoConstraints = false
        modalBackground.alpha = 0
        
        // Create modal container
        let modalContainer = UIView()
        modalContainer.backgroundColor = UIColor(red: 0.08, green: 0.12, blue: 0.18, alpha: 0.98)
        modalContainer.layer.cornerRadius = 20
        modalContainer.layer.borderWidth = 2
        modalContainer.layer.borderColor = won ? 
            UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0).cgColor : 
            UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 1.0).cgColor
        
        // Add glow effect
        modalContainer.layer.shadowColor = won ? 
            UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.8).cgColor : 
            UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 0.8).cgColor
        modalContainer.layer.shadowOffset = CGSize(width: 0, height: 0)
        modalContainer.layer.shadowOpacity = 0.8
        modalContainer.layer.shadowRadius = 15
        
        modalContainer.translatesAutoresizingMaskIntoConstraints = false
        modalContainer.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        
        // Create title label
        let titleLabel = UILabel()
        titleLabel.text = won ? "🎉 MISSION ACCOMPLISHED!" : "💪 MISSION CONTINUES"
        titleLabel.font = UIFont(name: "Menlo-Bold", size: 20) ?? UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = won ? 
            UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0) : 
            UIColor(red: 1.0, green: 0.4, blue: 0.2, alpha: 1.0)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add glow to title
        titleLabel.layer.shadowColor = titleLabel.textColor.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
        titleLabel.layer.shadowOpacity = 0.8
        titleLabel.layer.shadowRadius = 8
        
        // Create message label
        let messageLabel = UILabel()
        messageLabel.text = won ? 
            "TARGET ACQUIRED SUCCESSFULLY!\n🏆 You are the winner!" : 
            "Target eluded capture.\nBetter luck next time, soldier!"
        messageLabel.font = UIFont(name: "Menlo-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        messageLabel.textColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 0.9)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create button stack
        let buttonStack = UIStackView()
        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Button 1: Return to lobby
        let lobbyButton = createModalButton(
            title: "🚀 RETURN TO LOBBY", 
            subtitle: "Ready for next mission",
            isPrimary: true
        ) { [weak self] in
            self?.dismissModalAndReturnToLobby()
        }
        
        // Button 2: Return to main menu
        let mainMenuButton = createModalButton(
            title: "🏠 MAIN MENU", 
            subtitle: "Back to command center",
            isPrimary: false
        ) { [weak self] in
            self?.dismissModalAndReturnToMain()
        }
        
        buttonStack.addArrangedSubview(lobbyButton)
        buttonStack.addArrangedSubview(mainMenuButton)
        
        // Button 3: Continue guessing (for loser only)
        if !won {
            let continueButton = createModalButton(
                title: "🎯 CONTINUE ASSAULT", 
                subtitle: "Decode enemy secret",
                isPrimary: false
            ) { [weak self] in
                self?.dismissModalAndContinueGuessing()
            }
            buttonStack.addArrangedSubview(continueButton)
        }
        
        // Add to view hierarchy
        view.addSubview(modalBackground)
        modalBackground.addSubview(modalContainer)
        modalContainer.addSubview(titleLabel)
        modalContainer.addSubview(messageLabel)
        modalContainer.addSubview(buttonStack)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Modal background
            modalBackground.topAnchor.constraint(equalTo: view.topAnchor),
            modalBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            modalBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            modalBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Modal container
            modalContainer.centerXAnchor.constraint(equalTo: modalBackground.centerXAnchor),
            modalContainer.centerYAnchor.constraint(equalTo: modalBackground.centerYAnchor),
            modalContainer.widthAnchor.constraint(equalToConstant: 320),
            modalContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: won ? 280 : 360),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: modalContainer.topAnchor, constant: 25),
            titleLabel.leadingAnchor.constraint(equalTo: modalContainer.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: modalContainer.trailingAnchor, constant: -20),
            
            // Message
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            messageLabel.leadingAnchor.constraint(equalTo: modalContainer.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: modalContainer.trailingAnchor, constant: -20),
            
            // Button stack
            buttonStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 25),
            buttonStack.leadingAnchor.constraint(equalTo: modalContainer.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: modalContainer.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: modalContainer.bottomAnchor, constant: -25)
        ])
        
        // Animate modal in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            modalBackground.alpha = 1
            modalContainer.transform = CGAffineTransform.identity
        }
    }
    
    private func createModalButton(title: String, subtitle: String, isPrimary: Bool, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .custom)
        button.backgroundColor = isPrimary ? 
            UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.9) : 
            UIColor(red: 0.12, green: 0.18, blue: 0.25, alpha: 0.9)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = isPrimary ? 
            UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0).cgColor : 
            UIColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 0.8).cgColor
        
        // Add glow for primary button
        if isPrimary {
            button.layer.shadowColor = UIColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.8).cgColor
            button.layer.shadowOffset = CGSize(width: 0, height: 0)
            button.layer.shadowOpacity = 0.6
            button.layer.shadowRadius = 8
        }
        
        // Create button content stack
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 2
        contentStack.isUserInteractionEnabled = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont(name: "Menlo-Bold", size: 14) ?? UIFont.boldSystemFont(ofSize: 14)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont(name: "Menlo-Regular", size: 11) ?? UIFont.systemFont(ofSize: 11)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        subtitleLabel.textAlignment = .center
        
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        
        button.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Add touch animation
        button.addTarget(self, action: #selector(modalButtonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(modalButtonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        
        // Store action in button
        button.tag = buttonActions.count
        buttonActions.append(action)
        button.addTarget(self, action: #selector(modalButtonTapped(_:)), for: .touchUpInside)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    // Button actions storage
    private var buttonActions: [() -> Void] = []
    
    // Modal state management
    var hasShownGameEndModal = false
    var isInContinueMode = false
    
    // Modal button animation handlers
    @objc private func modalButtonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.alpha = 0.8
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    @objc private func modalButtonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            sender.transform = CGAffineTransform.identity
            sender.alpha = 1.0
        }
    }
    
    @objc private func modalButtonTapped(_ sender: UIButton) {
        let actionIndex = sender.tag
        print("🎯 Modal button tapped - tag: \(actionIndex), total actions: \(buttonActions.count)")
        if actionIndex < buttonActions.count {
            print("🎯 Executing action at index \(actionIndex)")
            buttonActions[actionIndex]()
        } else {
            print("❌ Action index out of bounds!")
        }
    }
    
    // Modal action handlers
    private func dismissModalAndReturnToLobby() {
        // Find and remove modal
        if let modalBackground = view.subviews.first(where: { $0.backgroundColor == UIColor.black.withAlphaComponent(0.7) }) {
            UIView.animate(withDuration: 0.3, animations: {
                modalBackground.alpha = 0
                if let modalContainer = modalBackground.subviews.first {
                    modalContainer.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                }
            }) { _ in
                modalBackground.removeFromSuperview()
            }
        }
        
        // Clear button actions
        buttonActions.removeAll()
        
        // Stop all network activities
        stopGamePolling()
        
        // Navigate back to waiting/lobby screen
        // Since we're in a presented view controller, we dismiss to go back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Try to find the OnlineWaitingViewController in navigation stack
            if let navigationController = self.navigationController {
                // Pop back to waiting screen
                for viewController in navigationController.viewControllers {
                    if viewController.className.contains("OnlineWaiting") {
                        navigationController.popToViewController(viewController, animated: true)
                        return
                    }
                }
            }
            
            // Fallback: dismiss this view controller
            self.dismiss(animated: true)
        }
    }
    
    private func dismissModalAndReturnToMain() {
        // Find and remove modal
        if let modalBackground = view.subviews.first(where: { $0.backgroundColor == UIColor.black.withAlphaComponent(0.7) }) {
            UIView.animate(withDuration: 0.3, animations: {
                modalBackground.alpha = 0
                if let modalContainer = modalBackground.subviews.first {
                    modalContainer.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                }
            }) { _ in
                modalBackground.removeFromSuperview()
            }
        }
        
        // Clear button actions
        buttonActions.removeAll()
        
        // Stop all network activities
        stopGamePolling()
        
        // Navigate back to main menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Try to dismiss all the way back to main menu
            if let navigationController = self.navigationController {
                navigationController.popToRootViewController(animated: true)
            } else {
                self.dismiss(animated: true)
            }
        }
    }
    
    private func dismissModalAndContinueGuessing() {
        print("🎯 Dismissing modal and enabling continue guessing mode")
        
        // Find and remove modal
        if let modalBackground = view.subviews.first(where: { $0.backgroundColor == UIColor.black.withAlphaComponent(0.7) }) {
            UIView.animate(withDuration: 0.3, animations: {
                modalBackground.alpha = 0
                if let modalContainer = modalBackground.subviews.first {
                    modalContainer.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
                }
            }) { _ in
                modalBackground.removeFromSuperview()
                print("🎯 Modal removed successfully")
            }
        }
        
        // Clear button actions
        buttonActions.removeAll()
        
        // Enable continue guessing mode
        enableContinueGuessingMode()
    }
    
    private func enableContinueGuessingMode() {
        print("🎯 Enabling continue guessing mode...")
        
        // Check if we have opponent secret
        if opponentSecret.isEmpty {
            print("⚠️ Warning: No opponent secret available for continue guessing")
            // Try to find it from current game state - this should be populated by now
        }
        
        // Set continue mode flag to prevent further modals
        isInContinueMode = true
        print("✅ Setting isInContinueMode = true")
        
        // Change game state to allow continued guessing
        gameState = "CONTINUE_GUESSING"
        print("🎯 Game state set to: \(gameState)")
        
        // Update UI to indicate continue mode
        turnLabel.text = "🎯 DECODE ENEMY SECRET"
        turnLabel.textColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        
        // Enable input regardless of turn (since we're in special mode)
        // In continue mode, we can always guess without waiting for turns
        isMyTurn = true
        currentTurn = playerId // Set ourselves as having the turn permanently in this mode
        print("🎯 Set isMyTurn = \(isMyTurn), currentTurn = \(currentTurn)")
        
        updateTurnUI()
        updateKeypadButtonsState()
        
        // Update submit button text and enable it
        submitButton.setTitle("🔍 ANALYZE", for: .normal)
        submitButton.isEnabled = true
        submitButton.alpha = 1.0
        print("🎯 Submit button configured: enabled=\(submitButton.isEnabled), alpha=\(submitButton.alpha)")
        
        // Don't restart full polling - we're in local analysis mode
        // But we can still do minimal background sync if needed
        
        // Add a note in secret label showing target secret
        if !opponentSecret.isEmpty {
            secretLabel.text = "🎯 TARGET: \(opponentSecret) • DECODE THIS SECRET!"
        } else {
            secretLabel.text = "🕵️ INTELLIGENCE GATHERING MODE • NO TURN LIMITS"
        }
        
        // Clear the text field for new guesses
        guessTextField.text = ""
        print("🎯 Text field cleared")
        
        // Force update the UI components
        DispatchQueue.main.async {
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
        
        print("🎯 Continue guessing mode enabled successfully!")
        print("🎯 Current state - gameState: \(gameState), isMyTurn: \(isMyTurn), submitEnabled: \(submitButton.isEnabled)")
    }
    
    func resetContinueGuessingButtonState() {
        print("🔄 resetContinueGuessingButtonState called - gameState: \(gameState)")
        
        submitButton.setTitle("🔍 ANALYZE", for: .normal)
        
        // Restore continue guessing UI state
        turnLabel.text = "🎯 DECODE ENEMY SECRET"
        turnLabel.textColor = UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)
        
        print("🎯 Turn label set to: \(turnLabel.text ?? "nil")")
        
        // Ensure keypad stays enabled in continue mode
        print("🔧 About to call updateKeypadButtonsState()")
        updateKeypadButtonsState()
        
        // Update submit button state based on current text (ensure main thread)
        DispatchQueue.main.async {
            print("🔤 About to call guessTextChanged()")
            self.guessTextChanged()
        }
        
        print("✅ Continue guessing state reset completed - ready for next guess")
    }
    
    func showContinueGuessingSuccessModal() {
        // Create modal background
        let modalBackground = UIView()
        modalBackground.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        modalBackground.translatesAutoresizingMaskIntoConstraints = false
        modalBackground.alpha = 0
        
        // Create modal container
        let modalContainer = UIView()
        modalContainer.backgroundColor = UIColor(red: 0.08, green: 0.12, blue: 0.18, alpha: 0.98)
        modalContainer.layer.cornerRadius = 20
        modalContainer.layer.borderWidth = 2
        modalContainer.layer.borderColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0).cgColor
        
        // Add glow effect
        modalContainer.layer.shadowColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.8).cgColor
        modalContainer.layer.shadowOffset = CGSize(width: 0, height: 0)
        modalContainer.layer.shadowOpacity = 0.8
        modalContainer.layer.shadowRadius = 15
        
        modalContainer.translatesAutoresizingMaskIntoConstraints = false
        modalContainer.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        
        // Create title label
        let titleLabel = UILabel()
        titleLabel.text = "🎯 SECRET DECODED!"
        titleLabel.font = UIFont(name: "Menlo-Bold", size: 20) ?? UIFont.boldSystemFont(ofSize: 20)
        titleLabel.textColor = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1.0)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add glow to title
        titleLabel.layer.shadowColor = titleLabel.textColor.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
        titleLabel.layer.shadowOpacity = 0.8
        titleLabel.layer.shadowRadius = 8
        
        // Create message label
        let messageLabel = UILabel()
        messageLabel.text = "ENEMY INTELLIGENCE ACQUIRED!\n🕵️ You successfully decoded their secret!"
        messageLabel.font = UIFont(name: "Menlo-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        messageLabel.textColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 0.9)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create button stack
        let buttonStack = UIStackView()
        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Button 1: Return to lobby
        let lobbyButton = createModalButton(
            title: "🚀 RETURN TO LOBBY", 
            subtitle: "Ready for next mission",
            isPrimary: true
        ) { [weak self] in
            self?.dismissModalAndReturnToLobby()
        }
        
        // Button 2: Return to main menu
        let mainMenuButton = createModalButton(
            title: "🏠 MAIN MENU", 
            subtitle: "Back to command center",
            isPrimary: false
        ) { [weak self] in
            self?.dismissModalAndReturnToMain()
        }
        
        buttonStack.addArrangedSubview(lobbyButton)
        buttonStack.addArrangedSubview(mainMenuButton)
        
        // Add to view hierarchy
        view.addSubview(modalBackground)
        modalBackground.addSubview(modalContainer)
        modalContainer.addSubview(titleLabel)
        modalContainer.addSubview(messageLabel)
        modalContainer.addSubview(buttonStack)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Modal background
            modalBackground.topAnchor.constraint(equalTo: view.topAnchor),
            modalBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            modalBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            modalBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Modal container
            modalContainer.centerXAnchor.constraint(equalTo: modalBackground.centerXAnchor),
            modalContainer.centerYAnchor.constraint(equalTo: modalBackground.centerYAnchor),
            modalContainer.widthAnchor.constraint(equalToConstant: 320),
            modalContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: modalContainer.topAnchor, constant: 25),
            titleLabel.leadingAnchor.constraint(equalTo: modalContainer.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: modalContainer.trailingAnchor, constant: -20),
            
            // Message
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 15),
            messageLabel.leadingAnchor.constraint(equalTo: modalContainer.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: modalContainer.trailingAnchor, constant: -20),
            
            // Button stack
            buttonStack.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 25),
            buttonStack.leadingAnchor.constraint(equalTo: modalContainer.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: modalContainer.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: modalContainer.bottomAnchor, constant: -25)
        ])
        
        // Animate modal in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            modalBackground.alpha = 1
            modalContainer.transform = CGAffineTransform.identity
        }
        
        // Stop game polling since we've completed the continue guessing phase
        stopGamePolling()
        
        // Success haptic feedback
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
    }
    
    func showWinDialog() {
        showGameOverAlert(won: true)
    }
    
    func showLoseDialog(winnerName: String) {
        stopGamePolling()
        
        let alert = UIAlertController(title: "😔 Game Over", 
                                    message: "\(winnerName) won this round!\n\nBetter luck next time!", 
                                    preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Back to Menu", style: .default) { _ in
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
        
        // Failure haptic feedback
        let failureFeedback = UINotificationFeedbackGenerator()
        failureFeedback.notificationOccurred(.error)
    }
    
    func leaveGameRequest() {
        performLeaveGame()
    }
    
    func performLeaveGame() {
        stopGamePolling()
        
        let url = URL(string: "\(baseURL)/game/leave-local")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "roomId": roomId,
            "playerId": playerId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                // Navigate back regardless of response
                self?.dismiss(animated: true)
            }
        }.resume()
    }
}

// Helper extension for class name
extension NSObject {
    var className: String {
        return String(describing: type(of: self))
    }
}