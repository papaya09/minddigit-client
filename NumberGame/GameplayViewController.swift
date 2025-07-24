import UIKit
import AudioToolbox

class GameplayViewController: UIViewController {
    
    // MARK: - Properties
    private let gameStateManager = GameStateManager.shared
    private var gameClient: GameClient!
    private var timer: Timer?
    
    // MARK: - UI Components
    private let backgroundView = UIView()
    private let topStatusView = UIView()
    private let roomCodeLabel = UILabel()
    private let turnLabel = UILabel()
    private let timerLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let exitButton = UIButton(type: .system)
    
    private let inputDisplayView = UIView()
    private let inputLabel = UILabel()
    private let statusLabel = UILabel()
    private let startGameButton = UIButton(type: .system)
    
    private let numberPadContainer = UIView()
    private var numberButtons: [UIButton] = []
    private let clearButton = UIButton(type: .system)
    private let submitButton = UIButton(type: .system)
    private let saveHistoryButton = UIButton(type: .system)
    
    private let playersContainer = UIView()
    private let playersHeaderLabel = UILabel()
    private let playersStackView = UIStackView()
    
    private let historyContainer = UIView()
    private let historyHeaderLabel = UILabel()
    private let historyScrollView = UIScrollView()
    private let historyStackView = UIStackView()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGameClient()
        setupBindings()
        startTimer()
        updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("🎮 GameplayViewController appearing. Current players: \(gameStateManager.players.count)")
        print("🎮 Current room (GameState): \(gameStateManager.currentRoomCode)")
        print("🎮 Current room (GameClient): \(gameClient.roomCode ?? "nil")")
        print("🎮 Current game state: \(gameStateManager.gameState)")
        
        // Sync room code from GameClient to GameStateManager if needed
        if let clientRoomCode = gameClient.roomCode, 
           gameStateManager.currentRoomCode.isEmpty {
            print("🔄 Syncing room code from GameClient to GameStateManager: \(clientRoomCode)")
            gameStateManager.currentRoomCode = clientRoomCode
        }
        
        // Ensure this view controller is the delegate when visible
        gameStateManager.delegate = self
        
        // Start polling for room state updates
        gameClient.startRoomPolling()
        
        // Force update display with current data
        updatePlayersDisplay()
        updateUI()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("🎮 GameplayViewController disappearing")
        
        // Stop polling when leaving
        gameClient.stopRoomPolling()
        stopTimer()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .systemBackground
        setupBackground()
        setupTopStatus()
        setupInputDisplay()
        setupNumberPad()
        setupPlayersSection()
        setupHistorySection()
        setupConstraints()
        animateEntrance()
    }
    
    private func setupBackground() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemIndigo.withAlphaComponent(0.9).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.7).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.9).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        backgroundView.layer.addSublayer(gradientLayer)
        
        DispatchQueue.main.async {
            gradientLayer.frame = self.backgroundView.bounds
        }
    }
    
    private func setupTopStatus() {
        topStatusView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        topStatusView.layer.cornerRadius = 10
        topStatusView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topStatusView)
        
        // Room code (showing room info like NPC version shows "VS NPC")
        roomCodeLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        roomCodeLabel.textColor = .systemYellow
        roomCodeLabel.translatesAutoresizingMaskIntoConstraints = false
        topStatusView.addSubview(roomCodeLabel)
        
        // Turn indicator
        turnLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        turnLabel.textColor = .systemCyan
        turnLabel.translatesAutoresizingMaskIntoConstraints = false
        topStatusView.addSubview(turnLabel)
        
        // Timer
        timerLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        timerLabel.textColor = .white
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        topStatusView.addSubview(timerLabel)
        
        // Back button - integrated into status view with simple text styling
        backButton.setTitle("← Back", for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        backButton.setTitleColor(.white, for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        topStatusView.addSubview(backButton)
        
        // Exit button - integrated into status view with simple text styling
        exitButton.setTitle("✕", for: .normal)
        exitButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        exitButton.setTitleColor(.systemRed, for: .normal)
        exitButton.addTarget(self, action: #selector(exitButtonTapped), for: .touchUpInside)
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        topStatusView.addSubview(exitButton)
    }
    
    private func setupInputDisplay() {
        inputDisplayView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        inputDisplayView.layer.cornerRadius = 15
        inputDisplayView.layer.borderWidth = 2
        inputDisplayView.layer.borderColor = UIColor.systemCyan.withAlphaComponent(0.6).cgColor
        inputDisplayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputDisplayView)
        
        inputLabel.text = "Enter your guess..."
        inputLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        inputLabel.textColor = .white
        inputLabel.textAlignment = .center
        inputLabel.translatesAutoresizingMaskIntoConstraints = false
        inputDisplayView.addSubview(inputLabel)
        
        statusLabel.text = "🎯 Make your guess!"
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = .systemCyan
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        inputDisplayView.addSubview(statusLabel)
        
        // Start Game button
        startGameButton.setTitle("🎮 Start Game", for: .normal)
        startGameButton.setTitleColor(.white, for: .normal)
        startGameButton.backgroundColor = .systemBlue
        startGameButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        startGameButton.layer.cornerRadius = 12
        startGameButton.layer.borderWidth = 2
        startGameButton.layer.borderColor = UIColor.white.cgColor
        startGameButton.addTarget(self, action: #selector(startGameButtonTapped), for: .touchUpInside)
        startGameButton.translatesAutoresizingMaskIntoConstraints = false
        startGameButton.isHidden = true // Initially hidden
        inputDisplayView.addSubview(startGameButton)
        
        // Skip Turn button - for turn-based gameplay
        saveHistoryButton.setTitle("⏭️ Skip Turn", for: .normal)
        saveHistoryButton.setTitleColor(.white, for: .normal)
        saveHistoryButton.backgroundColor = .systemOrange
        saveHistoryButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        saveHistoryButton.layer.cornerRadius = 10
        saveHistoryButton.layer.borderWidth = 2
        saveHistoryButton.layer.borderColor = UIColor.white.cgColor
        saveHistoryButton.addTarget(self, action: #selector(skipTurnButtonTapped), for: .touchUpInside)
        saveHistoryButton.translatesAutoresizingMaskIntoConstraints = false
        saveHistoryButton.isHidden = true // Show only during active game
        inputDisplayView.addSubview(saveHistoryButton)
    }
    
    private func setupNumberPad() {
        numberPadContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(numberPadContainer)
        
        // Create number buttons in phone keypad layout (1-9, then 0)
        for i in 1...9 {
            let button = createNumberButton(number: i)
            numberButtons.append(button)
            numberPadContainer.addSubview(button)
        }
        
        // Add 0 button
        let zeroButton = createNumberButton(number: 0)
        numberButtons.append(zeroButton)
        numberPadContainer.addSubview(zeroButton)
        
        // Control buttons container
        let controlButtonsContainer = UIView()
        controlButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlButtonsContainer)
        
        // Control buttons - compact design with emojis
        clearButton.setTitle("🗑️", for: .normal)
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.backgroundColor = .systemRed
        clearButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        clearButton.layer.cornerRadius = 22
        clearButton.layer.borderWidth = 3
        clearButton.layer.borderColor = UIColor.white.cgColor
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        controlButtonsContainer.addSubview(clearButton)
        
        submitButton.setTitle("▶", for: .normal)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.backgroundColor = .systemGreen
        submitButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        submitButton.layer.cornerRadius = 25
        submitButton.layer.borderWidth = 3
        submitButton.layer.borderColor = UIColor.white.cgColor
        submitButton.addTarget(self, action: #selector(submitButtonTapped), for: .touchUpInside)
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        controlButtonsContainer.addSubview(submitButton)
        
        // Layout control buttons
        NSLayoutConstraint.activate([
            // Control buttons container
            controlButtonsContainer.topAnchor.constraint(equalTo: numberPadContainer.bottomAnchor, constant: 15),
            controlButtonsContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            controlButtonsContainer.widthAnchor.constraint(equalToConstant: 150),
            controlButtonsContainer.heightAnchor.constraint(equalToConstant: 44),
            
            // Clear button
            clearButton.leadingAnchor.constraint(equalTo: controlButtonsContainer.leadingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: controlButtonsContainer.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 44),
            clearButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Submit button - ขยายขนาดให้กดง่ายขึ้น
            submitButton.trailingAnchor.constraint(equalTo: controlButtonsContainer.trailingAnchor),
            submitButton.centerYAnchor.constraint(equalTo: controlButtonsContainer.centerYAnchor),
            submitButton.widthAnchor.constraint(equalToConstant: 50),
            submitButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func createNumberButton(number: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("\(number)", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemIndigo
        button.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        button.layer.cornerRadius = 27.5 // 55/2
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.cgColor
        
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 2, height: 2)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 2
        
        button.tag = number
        button.addTarget(self, action: #selector(numberButtonTapped(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func setupPlayersSection() {
        playersContainer.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        playersContainer.layer.cornerRadius = 15
        playersContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playersContainer)
        
        playersHeaderLabel.text = "👥 PLAYERS"
        playersHeaderLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        playersHeaderLabel.textColor = .systemYellow
        playersHeaderLabel.textAlignment = .center
        playersHeaderLabel.numberOfLines = 0
        playersHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        playersContainer.addSubview(playersHeaderLabel)
        
        playersStackView.axis = .vertical
        playersStackView.spacing = 8
        playersStackView.translatesAutoresizingMaskIntoConstraints = false
        playersContainer.addSubview(playersStackView)
    }
    
    private func setupHistorySection() {
        historyContainer.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        historyContainer.layer.cornerRadius = 15
        historyContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(historyContainer)
        
        historyHeaderLabel.text = "📋 HISTORY"
        historyHeaderLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        historyHeaderLabel.textColor = .systemYellow
        historyHeaderLabel.textAlignment = .center
        historyHeaderLabel.numberOfLines = 0
        historyHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        historyContainer.addSubview(historyHeaderLabel)
        
        historyScrollView.showsVerticalScrollIndicator = false
        historyScrollView.translatesAutoresizingMaskIntoConstraints = false
        historyContainer.addSubview(historyScrollView)
        
        historyStackView.axis = .vertical
        historyStackView.spacing = 5
        historyStackView.translatesAutoresizingMaskIntoConstraints = false
        historyScrollView.addSubview(historyStackView)
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            // Background
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Top status
            topStatusView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 10),
            topStatusView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            topStatusView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            topStatusView.heightAnchor.constraint(equalToConstant: 80),
            
            // Top status content - matching NPC layout
            backButton.leadingAnchor.constraint(equalTo: topStatusView.leadingAnchor, constant: 15),
            backButton.centerYAnchor.constraint(equalTo: topStatusView.centerYAnchor),
            
            roomCodeLabel.centerXAnchor.constraint(equalTo: topStatusView.centerXAnchor),
            roomCodeLabel.topAnchor.constraint(equalTo: topStatusView.topAnchor, constant: 15),
            
            turnLabel.centerXAnchor.constraint(equalTo: topStatusView.centerXAnchor),
            turnLabel.topAnchor.constraint(equalTo: roomCodeLabel.bottomAnchor, constant: 5),
            
            timerLabel.trailingAnchor.constraint(equalTo: topStatusView.trailingAnchor, constant: -15),
            timerLabel.topAnchor.constraint(equalTo: topStatusView.topAnchor, constant: 15),
            
            exitButton.trailingAnchor.constraint(equalTo: topStatusView.trailingAnchor, constant: -15),
            exitButton.bottomAnchor.constraint(equalTo: topStatusView.bottomAnchor, constant: -15),
            
            // Input display
            inputDisplayView.topAnchor.constraint(equalTo: topStatusView.bottomAnchor, constant: 15),
            inputDisplayView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            inputDisplayView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            inputDisplayView.heightAnchor.constraint(equalToConstant: 120),
            
            inputLabel.centerXAnchor.constraint(equalTo: inputDisplayView.centerXAnchor),
            inputLabel.topAnchor.constraint(equalTo: inputDisplayView.topAnchor, constant: 10),
            
            statusLabel.centerXAnchor.constraint(equalTo: inputDisplayView.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: inputLabel.bottomAnchor, constant: 5),
            
            startGameButton.centerXAnchor.constraint(equalTo: inputDisplayView.centerXAnchor),
            startGameButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            startGameButton.widthAnchor.constraint(equalToConstant: 150),
            startGameButton.heightAnchor.constraint(equalToConstant: 40),
            
            saveHistoryButton.trailingAnchor.constraint(equalTo: inputDisplayView.trailingAnchor, constant: -10),
            saveHistoryButton.centerYAnchor.constraint(equalTo: startGameButton.centerYAnchor),
            saveHistoryButton.widthAnchor.constraint(equalToConstant: 120),
            saveHistoryButton.heightAnchor.constraint(equalToConstant: 35),
            
            // Number pad - phone keypad layout
            numberPadContainer.topAnchor.constraint(equalTo: inputDisplayView.bottomAnchor, constant: 15),
            numberPadContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            numberPadContainer.widthAnchor.constraint(equalToConstant: 189), // 3 * 55 + 2 * 12
            numberPadContainer.heightAnchor.constraint(equalToConstant: 256), // 4 * 55 + 3 * 12
            
            // Bottom sections container - use flexible layout (reference control buttons)
            playersContainer.topAnchor.constraint(equalTo: numberPadContainer.bottomAnchor, constant: 75),
            playersContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            playersContainer.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor, constant: -20),
            
            historyContainer.topAnchor.constraint(equalTo: numberPadContainer.bottomAnchor, constant: 75),
            historyContainer.leadingAnchor.constraint(equalTo: playersContainer.trailingAnchor, constant: 15),
            historyContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            historyContainer.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor, constant: -20),
            
            // Equal width for players and history
            playersContainer.widthAnchor.constraint(equalTo: historyContainer.widthAnchor),
            
            // Flexible height for both sections with minimum
            playersContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            historyContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            
            // Players section content
            playersHeaderLabel.topAnchor.constraint(equalTo: playersContainer.topAnchor, constant: 8),
            playersHeaderLabel.leadingAnchor.constraint(equalTo: playersContainer.leadingAnchor, constant: 8),
            playersHeaderLabel.trailingAnchor.constraint(equalTo: playersContainer.trailingAnchor, constant: -8),
            
            playersStackView.topAnchor.constraint(equalTo: playersHeaderLabel.bottomAnchor, constant: 8),
            playersStackView.leadingAnchor.constraint(equalTo: playersContainer.leadingAnchor, constant: 8),
            playersStackView.trailingAnchor.constraint(equalTo: playersContainer.trailingAnchor, constant: -8),
            playersStackView.bottomAnchor.constraint(lessThanOrEqualTo: playersContainer.bottomAnchor, constant: -8),
            
            // History section content
            historyHeaderLabel.topAnchor.constraint(equalTo: historyContainer.topAnchor, constant: 8),
            historyHeaderLabel.leadingAnchor.constraint(equalTo: historyContainer.leadingAnchor, constant: 8),
            historyHeaderLabel.trailingAnchor.constraint(equalTo: historyContainer.trailingAnchor, constant: -8),
            
            historyScrollView.topAnchor.constraint(equalTo: historyHeaderLabel.bottomAnchor, constant: 8),
            historyScrollView.leadingAnchor.constraint(equalTo: historyContainer.leadingAnchor, constant: 8),
            historyScrollView.trailingAnchor.constraint(equalTo: historyContainer.trailingAnchor, constant: -8),
            historyScrollView.bottomAnchor.constraint(equalTo: historyContainer.bottomAnchor, constant: -8),
            
            historyStackView.topAnchor.constraint(equalTo: historyScrollView.topAnchor),
            historyStackView.leadingAnchor.constraint(equalTo: historyScrollView.leadingAnchor),
            historyStackView.trailingAnchor.constraint(equalTo: historyScrollView.trailingAnchor),
            historyStackView.bottomAnchor.constraint(equalTo: historyScrollView.bottomAnchor),
            historyStackView.widthAnchor.constraint(equalTo: historyScrollView.widthAnchor),
            
        ])
        
        setupNumberPadConstraints()
    }
    
    private func setupNumberPadConstraints() {
        let buttonSize: CGFloat = 55
        let spacing: CGFloat = 12
        
        // Phone keypad layout for numbers 1-9
        for i in 0..<9 {
            let button = numberButtons[i]
            let number = i + 1  // buttons 1-9
            let row = (number - 1) / 3
            let col = (number - 1) % 3
            
            let x = CGFloat(col) * (buttonSize + spacing)
            let y = CGFloat(row) * (buttonSize + spacing)
            
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: numberPadContainer.leadingAnchor, constant: x),
                button.topAnchor.constraint(equalTo: numberPadContainer.topAnchor, constant: y),
                button.widthAnchor.constraint(equalToConstant: buttonSize),
                button.heightAnchor.constraint(equalToConstant: buttonSize)
            ])
        }
        
        // 0 button at bottom center (4th row)
        let zeroButton = numberButtons[9]
        NSLayoutConstraint.activate([
            zeroButton.centerXAnchor.constraint(equalTo: numberPadContainer.centerXAnchor),
            zeroButton.topAnchor.constraint(equalTo: numberPadContainer.topAnchor, constant: 3 * (buttonSize + spacing)),
            zeroButton.widthAnchor.constraint(equalToConstant: buttonSize),
            zeroButton.heightAnchor.constraint(equalToConstant: buttonSize)
        ])
    }
    
    private func setupGameClient() {
        gameClient = GameClient()
        gameClient.delegate = self
        gameClient.connect()
        
        // Set room code from GameStateManager
        if !gameStateManager.currentRoomCode.isEmpty {
            gameClient.roomCode = gameStateManager.currentRoomCode
            print("🎮 Set GameClient room code to: \(gameStateManager.currentRoomCode)")
            
            // Set current player info
            let currentPlayerInfo = gameStateManager.players.first { $0.name == gameStateManager.playerName }
            if let playerInfo = currentPlayerInfo {
                // Create RoomState.Player for GameClient
                let gameClientPlayer = RoomState.Player(
                    name: playerInfo.name,
                    avatar: playerInfo.avatar,
                    isReady: playerInfo.isReady,
                    isConnected: playerInfo.isConnected,
                    isAlive: playerInfo.isAlive,
                    turnOrder: playerInfo.turnOrder,
                    stats: playerInfo.stats
                )
                gameClient.player = gameClientPlayer
                print("🎮 Set current player: \(playerInfo.name)")
            }
        }
    }
    
    private func setupBindings() {
        gameStateManager.delegate = self
    }
    
    // MARK: - Timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateTimer()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimer() {
        timerLabel.text = gameStateManager.getFormattedGameTimer()
    }
    
    // MARK: - Actions
    @objc private func numberButtonTapped(_ sender: UIButton) {
        let number = sender.tag
        let numberString = "\(number)"
        
        // Check if number is already in current input (prevent duplicates)
        if gameStateManager.currentInput.contains(numberString) { 
            return 
        }
        
        gameStateManager.addDigit(number)
        updateInputDisplay()
        addButtonPressEffect(to: sender)
    }
    
    @objc private func clearButtonTapped() {
        gameStateManager.clearInput()
        updateInputDisplay()
        addButtonPressEffect(to: clearButton)
    }
    
    @objc private func submitButtonTapped() {
        print("🔴 SUBMIT BUTTON TAPPED! Current input: \(gameStateManager.currentInput)")
        print("🔴 Game state: \(gameStateManager.gameState)")
        print("🔴 Can submit: \(gameStateManager.canSubmitInput())")
        
        // Immediate UI feedback
        addButtonPressEffect(to: submitButton)
        
        guard gameStateManager.canSubmitInput() else {
            let requiredDigits = gameStateManager.selectedGameMode.rawValue
            let currentLength = gameStateManager.currentInput.count
            
            let message: String
            if gameStateManager.hasSetSecret {
                message = "You have already set your secret. Wait for other players."
            } else if currentLength != requiredDigits {
                message = "Please enter exactly \(requiredDigits) digits! You entered \(currentLength) digits. (Game mode: \(gameStateManager.selectedGameMode.displayName))"
            } else {
                message = "Please enter exactly \(requiredDigits) digits!"
            }
            
            showAlert(title: "Invalid Input", message: message)
            return
        }
        
        switch gameStateManager.gameState {
        case .settingSecret:
            let secret = gameStateManager.currentInput
            print("🔐 Setting secret: \(secret)")
            
            // Immediate local update
            gameStateManager.setMySecret(secret)
            gameStateManager.addToHistory("🔐 \(gameStateManager.playerName) set secret: \(secret)")
            gameStateManager.clearInput()
            updateInputDisplay()
            
            // Direct API call
            gameClient.setSecretImmediate(secret)
            
        case .activeGame:
            if !gameStateManager.isPlayerTurn() {
                showAlert(title: "Not Your Turn", message: "Wait for \(gameStateManager.currentPlayerTurn)'s turn!")
                return
            }
            let guess = gameStateManager.currentInput
            print("🎯 Making guess: \(guess)")
            showPlayerSelectionAlert()
            
        default:
            print("⚠️ Submit button tapped in invalid state: \(gameStateManager.gameState)")
            break
        }
    }
    
    @objc private func backButtonTapped() {
        showBackConfirmation()
    }
    
    @objc private func exitButtonTapped() {
        showExitConfirmation()
    }
    
    // MARK: - UI Updates
    private func updateUI() {
        // Enhanced room display with round info
        roomCodeLabel.text = "🏠 Room \(gameStateManager.currentRoomCode)"
        
        // Enhanced turn display with timer info
        if gameStateManager.currentPlayerTurn.isEmpty {
            turnLabel.text = "⏳ Waiting for players..."
        } else {
            let isMyTurn = gameStateManager.isPlayerTurn()
            let turnEmoji = isMyTurn ? "🔥" : "⏳"
            turnLabel.text = "\(turnEmoji) \(gameStateManager.currentPlayerTurn)'s Turn"
        }
        
        updateInputDisplay()
        updateSubmitButton()
        updateNumberPadVisibility()
    }
    
    private func updateInputDisplay() {
        let displayText: String
        let statusText: String
        
        switch gameStateManager.gameState {
        case .settingSecret:
            if gameStateManager.hasSetSecret {
                displayText = "Secret set! ✅"
                inputLabel.textColor = .systemGreen
                statusText = "⏳ Waiting for other players to set their secrets..."
            } else if gameStateManager.currentInput.isEmpty {
                displayText = "Enter your secret..."
                inputLabel.textColor = .lightGray
                statusText = "🔢 Enter your \(gameStateManager.selectedGameMode.rawValue)-digit secret number"
            } else {
                // Format the secret with spaces for better readability
                let formattedSecret = gameStateManager.currentInput.map { String($0) }.joined(separator: " ")
                displayText = formattedSecret
                inputLabel.textColor = .white
                statusText = "🔢 Enter your \(gameStateManager.selectedGameMode.rawValue)-digit secret number"
            }
            startGameButton.isHidden = true
            saveHistoryButton.isHidden = true
            
        case .waitingForGame:
            displayText = "⏳ Waiting for players..."
            inputLabel.textColor = .lightGray
            
            let readyCount = gameStateManager.players.filter { $0.isReady }.count
            let totalCount = gameStateManager.players.count
            
            if totalCount < 2 {
                statusText = "🎮 Waiting for more players to join (\(totalCount)/2 minimum)"
                startGameButton.isHidden = true
            } else if readyCount < totalCount {
                statusText = "🎯 Waiting for all players to set their secrets (\(readyCount)/\(totalCount) ready)"
                startGameButton.isHidden = true
            } else {
                statusText = "🎲 All players ready! Press start to begin"
                startGameButton.isHidden = false
            }
            saveHistoryButton.isHidden = true
            
        case .activeGame:
            if gameStateManager.currentInput.isEmpty {
                displayText = "Enter your guess..."
                inputLabel.textColor = .lightGray
                statusText = gameStateManager.isPlayerTurn() ? "🔥 Your turn! Make your guess!" : "⏳ Waiting for \(gameStateManager.currentPlayerTurn)..."
            } else {
                // Format the guess with spaces for better readability
                let formattedGuess = gameStateManager.currentInput.map { String($0) }.joined(separator: " ")
                displayText = formattedGuess
                inputLabel.textColor = .white
                statusText = gameStateManager.isPlayerTurn() ? "🔥 Your turn! Make your guess!" : "⏳ Waiting for \(gameStateManager.currentPlayerTurn)..."
            }
            startGameButton.isHidden = true
            saveHistoryButton.isHidden = !gameStateManager.isPlayerTurn()
            
        case .gameFinished:
            displayText = "🏆 Game Over"
            statusText = "🎉 Game completed!"
            inputLabel.textColor = .systemYellow
            startGameButton.isHidden = true
            saveHistoryButton.isHidden = true
            
        default:
            displayText = "⏳ Connecting..."
            statusText = "🔄 Connecting to game server..."
            inputLabel.textColor = .lightGray
            startGameButton.isHidden = true
            saveHistoryButton.isHidden = true
        }
        
        inputLabel.text = displayText
        statusLabel.text = statusText
    }
    
    private func updateSubmitButton() {
        let buttonText: String
        
        switch gameStateManager.gameState {
        case .settingSecret:
            buttonText = "🔐"
        case .activeGame:
            buttonText = gameStateManager.isPlayerTurn() ? "🎯" : "⏳"
        default:
            buttonText = "⏳"
        }
        
        submitButton.setTitle(buttonText, for: .normal)
        submitButton.isEnabled = gameStateManager.canSubmitInput()
        submitButton.alpha = submitButton.isEnabled ? 1.0 : 0.6
        
        // เพิ่มการแสดงสถานะที่ชัดเจน
        if !submitButton.isEnabled {
            submitButton.backgroundColor = .systemGray
        } else {
            submitButton.backgroundColor = .systemGreen
        }
    }
    
    private func updateNumberPadVisibility() {
        let shouldShow = (gameStateManager.gameState == .settingSecret || gameStateManager.gameState == .activeGame) && 
                        !gameStateManager.hasSetSecret
        
        UIView.animate(withDuration: 0.3) {
            self.numberPadContainer.alpha = shouldShow ? 1.0 : 0.5
            self.clearButton.alpha = shouldShow ? 1.0 : 0.5
            // ไม่เปลี่ยน alpha ของ submit button ที่นี่
        }
        
        numberPadContainer.isUserInteractionEnabled = shouldShow
        clearButton.isUserInteractionEnabled = shouldShow
        // ปล่อยให้ submitButton.isUserInteractionEnabled = true เสมอ
        submitButton.isUserInteractionEnabled = true
    }
    
    // MARK: - Animations
    private func animateEntrance() {
        let views = [topStatusView, inputDisplayView, playersContainer, historyContainer, numberPadContainer]
        
        views.forEach { view in
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 20)
        }
        
        UIView.animateKeyframes(withDuration: 1.0, delay: 0.3, options: [], animations: {
            for (index, view) in views.enumerated() {
                UIView.addKeyframe(withRelativeStartTime: Double(index) * 0.1, relativeDuration: 0.3) {
                    view.alpha = 1
                    view.transform = .identity
                }
            }
        })
    }
    
    private func addButtonPressEffect(to button: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.transform = .identity
            }
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        AudioServicesPlaySystemSound(1104)
    }
    
    // MARK: - Alerts
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showPlayerSelectionAlert() {
        let alert = UIAlertController(title: "Select Target", message: "Choose which player to guess", preferredStyle: .alert)
        
        for player in gameStateManager.players {
            if player.name != gameStateManager.playerName {
                alert.addAction(UIAlertAction(title: "\(player.avatar) \(player.name)", style: .default) { _ in
                    self.makeGuess(targetPlayer: player.name)
                })
            }
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showBackConfirmation() {
        let message = gameStateManager.gameState == .activeGame ? 
            "Are you sure you want to leave the active game?" : 
            "Are you sure you want to go back to main menu?"
        
        let alert = UIAlertController(title: "Leave Game?", message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Stay", style: .cancel))
        alert.addAction(UIAlertAction(title: "Leave", style: .destructive) { _ in
            self.gameClient.disconnect()
            self.gameStateManager.resetGameData()
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showExitConfirmation() {
        let alert = UIAlertController(title: "Exit Game?", message: "Are you sure you want to exit MindDigits?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Exit", style: .destructive) { _ in
            self.gameClient.disconnect()
            exit(0)
        })
        
        present(alert, animated: true)
    }
    
    private func makeGuess(targetPlayer: String) {
        let guess = gameStateManager.currentInput
        
        // Immediate local update
        gameStateManager.addToHistory("🎯 \(gameStateManager.playerName) → \(targetPlayer): \(guess) (processing...)")
        gameStateManager.clearInput()
        updateInputDisplay()
        
        // Direct API call
        gameClient.makeGuessImmediate(guess, targetPlayer: targetPlayer)
    }
    
    @objc private func startGameButtonTapped() {
        // Immediate UI feedback
        addButtonPressEffect(to: startGameButton)
        startGameButton.isHidden = true
        statusLabel.text = "🎮 Starting game..."
        
        // Direct API call
        gameClient.startGameImmediate()
    }
    
    @objc private func skipTurnButtonTapped() {
        // Add button press effect
        saveHistoryButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        UIView.animate(withDuration: 0.1) {
            self.saveHistoryButton.transform = CGAffineTransform.identity
        }
        
        // Check if it's actually player's turn
        guard gameStateManager.isPlayerTurn() else {
            showAlert(title: "Not Your Turn", message: "You can only skip during your turn!")
            return
        }
        
        // Show confirmation dialog
        let alert = UIAlertController(title: "Skip Turn", message: "Are you sure you want to skip your turn?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Skip Turn", style: .destructive) { _ in
            self.gameClient.skipTurn()
            
            // Add to history
            self.gameStateManager.addToHistory("⏭️ \(self.gameStateManager.playerName) skipped their turn")
            
            // Show feedback
            self.statusLabel.text = "⏭️ Turn skipped! Waiting for next player..."
        })
        
        present(alert, animated: true)
        
        print("⏭️ Skip turn button tapped by \(gameStateManager.playerName)")
    }
}

// MARK: - GameStateManagerDelegate
extension GameplayViewController: GameStateManagerDelegate {
    func gameStateDidChange(to state: GameState) {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    func playersDidUpdate(_ players: [RoomState.Player]) {
        print("🎮 playersDidUpdate called with \(players.count) players")
        DispatchQueue.main.async {
            self.updatePlayersDisplay()
        }
    }
    
    func gameHistoryDidUpdate(_ history: [String]) {
        DispatchQueue.main.async {
            self.updateHistoryDisplay()
        }
    }
    
    func currentTurnDidChange(to player: String) {
        DispatchQueue.main.async {
            self.updateUI()
        }
    }
    
    private func updatePlayersDisplay() {
        playersStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for player in gameStateManager.players {
            let playerCard = createPlayerCard(for: player)
            playersStackView.addArrangedSubview(playerCard)
        }
    }
    
    private func createPlayerCard(for player: RoomState.Player) -> UIView {
        let playerCard = UIView()
        let isCurrentPlayer = (player.name == gameStateManager.playerName)
        let isPlayerTurn = (player.name == gameStateManager.currentPlayerTurn)
        
        // Card styling
        playerCard.backgroundColor = isCurrentPlayer ? 
            UIColor.systemBlue.withAlphaComponent(0.3) : 
            UIColor.systemGray.withAlphaComponent(0.3)
        playerCard.layer.cornerRadius = 8
        playerCard.layer.borderWidth = isPlayerTurn ? 2 : 1
        playerCard.layer.borderColor = isPlayerTurn ? 
            UIColor.systemYellow.cgColor : 
            (isCurrentPlayer ? UIColor.systemBlue.withAlphaComponent(0.7).cgColor : UIColor.systemGray.withAlphaComponent(0.7).cgColor)
        
        // Player name label with secret display
        let nameLabel = UILabel()
        if isCurrentPlayer {
            let secretDisplay = gameStateManager.mySecret.isEmpty ? "" : " (\(gameStateManager.mySecret))"
            nameLabel.text = "👤 \(player.name)\(secretDisplay)"
        } else {
            let secretDisplay = gameStateManager.gameState == .activeGame ? " (???)" : ""
            nameLabel.text = "\(player.avatar) \(player.name)\(secretDisplay)"
        }
        nameLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 0
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        playerCard.addSubview(nameLabel)
        
        // Status label
        let statusLabel = UILabel()
        if isPlayerTurn {
            statusLabel.text = "🔥 Current Turn"
            statusLabel.textColor = .systemYellow
        } else if player.isReady {
            statusLabel.text = "✅ Ready"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.text = "⏳ Waiting"
            statusLabel.textColor = .systemOrange
        }
        statusLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        statusLabel.numberOfLines = 0
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        playerCard.addSubview(statusLabel)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            playerCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 45),
            
            nameLabel.leadingAnchor.constraint(equalTo: playerCard.leadingAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: playerCard.trailingAnchor, constant: -6),
            nameLabel.topAnchor.constraint(equalTo: playerCard.topAnchor, constant: 4),
            
            statusLabel.leadingAnchor.constraint(equalTo: playerCard.leadingAnchor, constant: 6),
            statusLabel.trailingAnchor.constraint(equalTo: playerCard.trailingAnchor, constant: -6),
            statusLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            statusLabel.bottomAnchor.constraint(equalTo: playerCard.bottomAnchor, constant: -4)
        ])
        
        return playerCard
    }
    
    private func updateHistoryDisplay() {
        historyStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let recentHistory = Array(gameStateManager.gameHistory.suffix(8))
        for history in recentHistory {
            let historyItem = UIView()
            historyItem.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            historyItem.layer.cornerRadius = 4
            historyItem.layer.borderWidth = 1
            historyItem.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
            
            let historyLabel = UILabel()
            historyLabel.text = history
            historyLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            historyLabel.textColor = .white
            historyLabel.numberOfLines = 0
            historyLabel.lineBreakMode = .byWordWrapping
            historyLabel.translatesAutoresizingMaskIntoConstraints = false
            
            historyItem.addSubview(historyLabel)
            
            NSLayoutConstraint.activate([
                historyItem.heightAnchor.constraint(greaterThanOrEqualToConstant: 22),
                
                historyLabel.leadingAnchor.constraint(equalTo: historyItem.leadingAnchor, constant: 4),
                historyLabel.trailingAnchor.constraint(equalTo: historyItem.trailingAnchor, constant: -4),
                historyLabel.topAnchor.constraint(equalTo: historyItem.topAnchor, constant: 2),
                historyLabel.bottomAnchor.constraint(equalTo: historyItem.bottomAnchor, constant: -2)
            ])
            
            historyStackView.addArrangedSubview(historyItem)
        }
        
        // Scroll to bottom with better timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if self.historyScrollView.contentSize.height > self.historyScrollView.bounds.height {
                let bottomOffset = CGPoint(x: 0, y: self.historyScrollView.contentSize.height - self.historyScrollView.bounds.height)
                self.historyScrollView.setContentOffset(bottomOffset, animated: true)
            }
        }
    }
}

// MARK: - GameClientDelegate
extension GameplayViewController: GameClientDelegate {
    func gameClient(_ client: GameClient, didReceiveRoomState state: RoomState) {
        // Store old state for comparison
        let oldGameState = gameStateManager.gameState
        let oldPlayersCount = gameStateManager.players.count
        
        gameStateManager.handleRoomState(state)
        
        DispatchQueue.main.async {
            // Log significant changes after handleRoomState
            if oldGameState != self.gameStateManager.gameState || oldPlayersCount != self.gameStateManager.players.count {
                print("🎮 Room \(state.game.code): \(state.game.state), \(state.players.count) players")
            }
            
            self.updateUI()
            self.updatePlayersDisplay()
        }
    }
    
    func gameClient(_ client: GameClient, didReceiveError error: String) {
        DispatchQueue.main.async {
            // Show more user-friendly error messages
            let friendlyMessage: String
            if error.contains("unique digits") || error.contains("no duplicates") {
                let digits = self.gameStateManager.selectedGameMode.rawValue
                if digits <= 2 {
                    friendlyMessage = "For \(digits)-digit games, you can use duplicate numbers. Something else went wrong. Try again!"
                } else {
                    friendlyMessage = "For \(digits)-digit games, each digit must be different (no duplicates). Try again!"
                }
            } else if error.contains("already set") {
                friendlyMessage = "You've already set your secret. Wait for other players."
            } else if error.contains("exactly") && error.contains("digits") {
                friendlyMessage = "Please enter exactly \(self.gameStateManager.selectedGameMode.rawValue) digits."
            } else {
                friendlyMessage = error
            }
            
            self.showAlert(title: "Action Failed", message: friendlyMessage)
            self.updateUI() // Refresh UI after error
        }
    }
    
    func gameClient(_ client: GameClient, gameDidStart: Bool) {
        gameStateManager.startNewGame()
    }
    
    func gameClient(_ client: GameClient, didReceiveMoveResult result: MoveResult) {
        gameStateManager.handleMoveResult(result)
        
        DispatchQueue.main.async {
            self.showResultAnimation(result: result)
            self.updateUI() // Update UI to reflect new state
        }
    }
    
    func gameClient(_ client: GameClient, gameDidEnd winner: String, secret: String) {
        gameStateManager.handleGameEnd(winner: winner, secret: secret)
        
        DispatchQueue.main.async {
            self.showWinnerAnimation(winner: winner, secret: secret)
        }
    }
    
    
    private func showResultAnimation(result: MoveResult) {
        let resultText = "💥 \(result.hit) HITS!"
        let color: UIColor = result.hit > 2 ? .systemGreen : result.hit > 0 ? .systemOrange : .systemRed
        
        let resultLabel = UILabel()
        resultLabel.text = resultText
        resultLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        resultLabel.textColor = color
        resultLabel.textAlignment = .center
        resultLabel.alpha = 0
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(resultLabel)
        NSLayoutConstraint.activate([
            resultLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            resultLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        UIView.animateKeyframes(withDuration: 2.0, delay: 0, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.3) {
                resultLabel.alpha = 1
                resultLabel.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3) {
                resultLabel.alpha = 0
                resultLabel.transform = .identity
            }
        }) { _ in
            resultLabel.removeFromSuperview()
        }
    }
    
    private func showWinnerAnimation(winner: String, secret: String) {
        let alert = UIAlertController(title: "🏆 Game Over!", 
                                    message: "\(winner) wins!\n🔓 Secret was: \(secret)", 
                                    preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Back to Menu", style: .default) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - ScrollView Extension
extension UIScrollView {
    func scrollToBottom() {
        let bottomOffset = CGPoint(x: 0, y: max(0, contentSize.height - bounds.size.height))
        setContentOffset(bottomOffset, animated: true)
    }
}