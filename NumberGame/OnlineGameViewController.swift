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
    
    // Network
    let baseURL = "http://192.168.1.140:3001/api"
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Setup history after UI is complete with longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setupHistoryDelayed()
        }
        
        // Start polling after everything is set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.startGamePolling()
        }
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
                roomLabel.text = "Room: \(roomId)"
            }
            if let secretLabel = self.secretLabel, secretLabel.superview != nil {
                secretLabel.text = "Your Secret: Set"
            }
        } else if isViewLoaded {
            DispatchQueue.main.async {
                if let roomLabel = self.roomLabel, roomLabel.superview != nil {
                    roomLabel.text = "Room: \(roomId)"
                }
                if let secretLabel = self.secretLabel, secretLabel.superview != nil {
                    secretLabel.text = "Your Secret: Set"
                }
            }
        } else {
            print("⚠️ View not loaded yet in configure(), skipping UI updates")
        }
    }
    
    func updateTurnUI() {
        print("🎯 updateTurnUI called: currentTurn='\(currentTurn)', playerId='\(playerId)', isMyTurn=\(isMyTurn)")
        
        // MUST be called from main thread only - no more nested dispatches
        assert(Thread.isMainThread, "updateTurnUI() must be called from main thread")
        
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
            turnLabel.text = "🎯 Your Turn - Use Keypad"
            turnLabel.textColor = .systemGreen
        } else {
            turnLabel.text = "⏳ Opponent's Turn"
            turnLabel.textColor = .systemOrange
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
    
    private func updateKeypadButtonsState() {
        // MUST be on main thread
        assert(Thread.isMainThread, "updateKeypadButtonsState() must be called from main thread")
        
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
        for button in validButtons {
            button.isEnabled = isMyTurn
            
            // Immediate visual update - no animation to prevent thread issues
            if isMyTurn {
                button.alpha = 1.0
                button.transform = CGAffineTransform.identity
            } else {
                button.alpha = 0.4
                button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        }
        
        print("🎯 Updated \(validButtons.count) keypad buttons for turn: \(isMyTurn)")
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
        // setupHistory() // Temporarily disabled to avoid crash
        setupConstraints()
    }
    
    private func setupBackground() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)
        
        backgroundOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundOverlay)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemOrange.withAlphaComponent(0.8).cgColor,
            UIColor.systemRed.withAlphaComponent(0.6).cgColor,
            UIColor.systemPink.withAlphaComponent(0.8).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        backgroundOverlay.layer.addSublayer(gradientLayer)
        
        DispatchQueue.main.async {
            gradientLayer.frame = self.backgroundOverlay.bounds
        }
    }
    
    private func setupTitleSection() {
        titleLabel.text = "🎮 Online Battle"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 2, height: 2)
        titleLabel.layer.shadowOpacity = 0.8
        titleLabel.layer.shadowRadius = 4
        
        view.addSubview(titleLabel)
        
        loadingSpinner.color = .white
        loadingSpinner.hidesWhenStopped = true
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingSpinner)
    }
    
    private func setupGameInfo() {
        // Initialize UI elements
        roomLabel = UILabel()
        turnLabel = UILabel()
        secretLabel = UILabel()
        
        gameInfoCard.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        gameInfoCard.layer.cornerRadius = 10
        gameInfoCard.layer.borderWidth = 1
        gameInfoCard.layer.borderColor = UIColor.systemCyan.withAlphaComponent(0.6).cgColor
        gameInfoCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gameInfoCard)
        
        roomLabel.text = "Room: ----"
        roomLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        roomLabel.textColor = .systemCyan
        roomLabel.textAlignment = .center
        roomLabel.translatesAutoresizingMaskIntoConstraints = false
        gameInfoCard.addSubview(roomLabel)
        
        turnLabel.text = "⏳ Waiting for turn..."
        turnLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        turnLabel.textColor = .systemOrange
        turnLabel.textAlignment = .center
        turnLabel.translatesAutoresizingMaskIntoConstraints = false
        gameInfoCard.addSubview(turnLabel)
        
        secretLabel.text = "Your Secret: Not Set"
        secretLabel.font = UIFont.systemFont(ofSize: 12)
        secretLabel.textColor = .systemGray
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
        
        gameBoardContainer.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        gameBoardContainer.layer.cornerRadius = 10
        gameBoardContainer.layer.borderWidth = 1
        gameBoardContainer.layer.borderColor = UIColor.systemCyan.withAlphaComponent(0.6).cgColor
        gameBoardContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gameBoardContainer)
        
        guessTextField.placeholder = "Use keypad below to enter guess"
        guessTextField.borderStyle = .roundedRect
        guessTextField.textAlignment = .center
        guessTextField.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        guessTextField.backgroundColor = UIColor.systemGray6
        guessTextField.translatesAutoresizingMaskIntoConstraints = false
        guessTextField.addTarget(self, action: #selector(guessTextChanged), for: .editingChanged)
        
        // Disable direct input - keypad only
        guessTextField.isUserInteractionEnabled = false
        
        // Style as display field
        guessTextField.layer.borderWidth = 2
        guessTextField.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.6).cgColor
        guessTextField.layer.cornerRadius = 8
        gameBoardContainer.addSubview(guessTextField)
        
        submitButton.setTitle("Submit Guess", for: .normal)
        submitButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        submitButton.layer.cornerRadius = 10
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
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.layer.cornerRadius = 15
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.cgColor
        button.tag = number
        button.addTarget(self, action: #selector(keypadNumberTapped(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: 26)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true
        
        return button
    }
    
    private func createClearButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("CLEAR", for: .normal)
        button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        button.layer.cornerRadius = 15
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.cgColor
        button.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: 26)
        heightConstraint.priority = UILayoutPriority(999)
        heightConstraint.isActive = true
        
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
        
        // Create history section card
        let historyCard = UIView()
        historyCard.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        historyCard.layer.cornerRadius = 15
        historyCard.layer.borderWidth = 2
        historyCard.layer.borderColor = UIColor.systemPurple.withAlphaComponent(0.6).cgColor
        historyCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(historyCard)
        
        let historyLabel = UILabel()
        historyLabel.text = "📋 GAME HISTORY"
        historyLabel.font = UIFont.boldSystemFont(ofSize: 18)
        historyLabel.textColor = .white
        historyLabel.textAlignment = .center
        historyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add shadow effect to title
        historyLabel.layer.shadowColor = UIColor.black.cgColor
        historyLabel.layer.shadowOffset = CGSize(width: 1, height: 1)
        historyLabel.layer.shadowOpacity = 0.8
        historyLabel.layer.shadowRadius = 2
        
        historyCard.addSubview(historyLabel)
        
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
            historyLabel.trailingAnchor.constraint(equalTo: historyCard.trailingAnchor, constant: -15),
            
            // Scroll view - Maximum space for content
            scrollView.topAnchor.constraint(equalTo: historyLabel.bottomAnchor, constant: 12),
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
        leaveButton.setTitle("← Leave Game", for: .normal)
        leaveButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
        leaveButton.setTitleColor(.white, for: .normal)
        leaveButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        leaveButton.layer.cornerRadius = 10
        leaveButton.translatesAutoresizingMaskIntoConstraints = false
        leaveButton.addTarget(self, action: #selector(leaveGame), for: .touchUpInside)
        view.addSubview(leaveButton)
        print("✅ setupControlButtons: leaveButton initialized successfully")
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
    
    func createPlaceholderView() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 2
        container.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "🎯 Ready to start! Make your first guess to begin the battle!"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Add glow effect
        label.layer.shadowColor = UIColor.systemBlue.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 0)
        label.layer.shadowOpacity = 0.8
        label.layer.shadowRadius = 4
        
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 50),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }
    
    func createHistoryItemView(playerName: String, guess: String, bulls: Int, cows: Int) -> UIView {
        let container = UIView()
        let isMe = playerName.lowercased().contains("player") && playerName.contains(playerId.suffix(4))
        
        // Enhanced styling based on player and result
        if bulls == digits {
            // Winner styling - bright and celebratory
            container.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
            container.layer.borderColor = UIColor.systemGreen.cgColor
            container.layer.borderWidth = 3
            
            // Add winner glow effect
            container.layer.shadowColor = UIColor.systemGreen.cgColor
            container.layer.shadowOffset = CGSize(width: 0, height: 0)
            container.layer.shadowOpacity = 0.6
            container.layer.shadowRadius = 8
        } else if isMe {
            // Player's own moves - blue theme
            container.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
            container.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.8).cgColor
            container.layer.borderWidth = 2
        } else {
            // Opponent moves - orange theme
            container.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.2)
            container.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.8).cgColor
            container.layer.borderWidth = 2
        }
        
        container.layer.cornerRadius = 15
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Main stack view - Compact but readable
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Player and guess info with enhanced styling - Clear text
        let playerLabel = UILabel()
        playerLabel.text = isMe ? "🎯 You" : "👤 \(playerName)"
        playerLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        
        if isMe {
            playerLabel.textColor = .white
            playerLabel.layer.shadowColor = UIColor.systemBlue.cgColor
        } else {
            playerLabel.textColor = .white
            playerLabel.layer.shadowColor = UIColor.systemOrange.cgColor
        }
        
        // Add text shadow for better visibility
        playerLabel.layer.shadowOffset = CGSize(width: 1, height: 1)
        playerLabel.layer.shadowOpacity = 0.8
        playerLabel.layer.shadowRadius = 2
        
        // Guess with result - enhanced visibility
        let guessLabel = UILabel()
        let bullsEmoji = String(repeating: "🎯", count: bulls)
        let cowsEmoji = String(repeating: "🔥", count: cows) // Changed from cow to fire for better visibility
        
        if bulls == digits {
            // Winner!
            guessLabel.text = "🎉 \(guess) → WINNER! \(bullsEmoji)"
            guessLabel.textColor = .white
            guessLabel.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
            
            // Winner text glow
            guessLabel.layer.shadowColor = UIColor.systemGreen.cgColor
            guessLabel.layer.shadowOffset = CGSize(width: 0, height: 0)
            guessLabel.layer.shadowOpacity = 1.0
            guessLabel.layer.shadowRadius = 4
        } else {
            // Regular guess with improved formatting
            var resultText = "\(guess) → "
            if bulls > 0 {
                resultText += "\(bulls)🎯"
            }
            if cows > 0 {
                if bulls > 0 { resultText += " " }
                resultText += "\(cows)🔥"
            }
            if bulls == 0 && cows == 0 {
                resultText += "❌ No match"
            }
            
            guessLabel.text = resultText
            guessLabel.textColor = .white
            guessLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            
            // Add text shadow for visibility
            guessLabel.layer.shadowColor = UIColor.black.cgColor
            guessLabel.layer.shadowOffset = CGSize(width: 1, height: 1)
            guessLabel.layer.shadowOpacity = 0.8
            guessLabel.layer.shadowRadius = 2
        }
        
        // Explanation for user with better styling
        let explanationLabel = UILabel()
        if bulls == digits {
            explanationLabel.text = "🏆 Perfect guess - all digits correct!"
            explanationLabel.textColor = .white
            explanationLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        } else if bulls > 0 || cows > 0 {
            var explanation = ""
            if bulls > 0 {
                explanation += "\(bulls) correct position\(bulls > 1 ? "s" : "")"
            }
            if cows > 0 {
                if bulls > 0 { explanation += ", " }
                explanation += "\(cows) wrong position\(cows > 1 ? "s" : "")"
            }
            explanationLabel.text = "💫 \(explanation)"
            explanationLabel.textColor = UIColor.white.withAlphaComponent(0.9)
            explanationLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        } else {
            explanationLabel.text = "💭 No digits match the secret number"
            explanationLabel.textColor = UIColor.white.withAlphaComponent(0.9)
            explanationLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
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
        let title = won ? "🎉 Congratulations!" : "💔 Game Over"
        let message = won ? 
            "You correctly guessed the secret number!\n🏆 You are the winner!" : 
            "Better luck next time!"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "🎮 New Game", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "📊 View Results", style: .default) { [weak self] _ in
            // Stay in game to view final history
        })
        
        present(alert, animated: true)
        
        // Stop polling when game ends
        gameTimer?.invalidate()
        gameTimer = nil
        
        // Celebration haptic feedback
        if won {
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
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