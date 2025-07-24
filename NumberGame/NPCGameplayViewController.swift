import UIKit
import AudioToolbox

class NPCGameplayViewController: UIViewController {
    
    // MARK: - Properties
    private let npc: NPCCharacter
    private let gameMode: GameMode
    private let playerSecret: String
    private var currentGuess = ""
    private var gameEnded = false
    private var isPlayerTurn = true
    private var timer: Timer?
    private var gameTime: Int = 0
    
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
    
    private let numberPadContainer = UIView()
    private var numberButtons: [UIButton] = []
    private let clearButton = UIButton(type: .system)
    private let submitButton = UIButton(type: .system)
    
    private let playersContainer = UIView()
    private let playersHeaderLabel = UILabel()
    private let playersStackView = UIStackView()
    
    private let historyContainer = UIView()
    private let historyHeaderLabel = UILabel()
    private let historyScrollView = UIScrollView()
    private let historyStackView = UIStackView()
    
    // MARK: - Initialization
    init(npc: NPCCharacter, gameMode: GameMode, playerSecret: String) {
        self.npc = npc
        self.gameMode = gameMode
        self.playerSecret = playerSecret
        super.init(nibName: nil, bundle: nil)
        
        // Start the NPC game
        NPCManager.shared.startGameWithNPC(npc, gameMode: gameMode, playerSecret: playerSecret)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startTimer()
        updateUI()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateGradientFrame()
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
    }
    
    private func updateGradientFrame() {
        if let gradientLayer = backgroundView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = backgroundView.bounds
        }
    }
    
    private func setupTopStatus() {
        topStatusView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        topStatusView.layer.cornerRadius = 10
        topStatusView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topStatusView)
        
        // Room code (showing NPC name instead)
        roomCodeLabel.text = "VS \(npc.name)"
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
        
        // Back button
        backButton.setTitle("← Back", for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        backButton.setTitleColor(.white, for: .normal)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        topStatusView.addSubview(backButton)
        
        // Exit button
        exitButton.setTitle("✕", for: .normal)
        exitButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        exitButton.setTitleColor(.systemRed, for: .normal)
        exitButton.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
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
        
        statusLabel.text = "🎯 Guess \(npc.name)'s secret number!"
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = .systemCyan
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        inputDisplayView.addSubview(statusLabel)
    }
    
    private func setupNumberPad() {
        numberPadContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(numberPadContainer)
        
        // Create number buttons in phone keypad layout (1-9, then 0)
        let buttonSize: CGFloat = 55
        let spacing: CGFloat = 12
        
        // Create buttons 1-9 in phone layout
        for i in 1...9 {
            let button = UIButton(type: .system)
            button.setTitle("\(i)", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .bold)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
            button.layer.cornerRadius = buttonSize / 2
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.white.cgColor
            
            // Add shadow
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOffset = CGSize(width: 2, height: 2)
            button.layer.shadowOpacity = 0.3
            button.layer.shadowRadius = 2
            
            button.tag = i
            button.addTarget(self, action: #selector(numberTapped(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            numberPadContainer.addSubview(button)
            numberButtons.append(button)
            
            // Phone keypad layout: 1,2,3 on top row, 4,5,6 middle, 7,8,9 bottom
            let row = (i - 1) / 3
            let col = (i - 1) % 3
            let x = CGFloat(col) * (buttonSize + spacing)
            let y = CGFloat(row) * (buttonSize + spacing)
            
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: numberPadContainer.leadingAnchor, constant: x),
                button.topAnchor.constraint(equalTo: numberPadContainer.topAnchor, constant: y),
                button.widthAnchor.constraint(equalToConstant: buttonSize),
                button.heightAnchor.constraint(equalToConstant: buttonSize)
            ])
        }
        
        // Create 0 button at bottom center
        let zeroButton = UIButton(type: .system)
        zeroButton.setTitle("0", for: .normal)
        zeroButton.titleLabel?.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        zeroButton.setTitleColor(.white, for: .normal)
        zeroButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        zeroButton.layer.cornerRadius = buttonSize / 2
        zeroButton.layer.borderWidth = 2
        zeroButton.layer.borderColor = UIColor.white.cgColor
        zeroButton.layer.shadowColor = UIColor.black.cgColor
        zeroButton.layer.shadowOffset = CGSize(width: 2, height: 2)
        zeroButton.layer.shadowOpacity = 0.3
        zeroButton.layer.shadowRadius = 2
        zeroButton.tag = 0
        zeroButton.addTarget(self, action: #selector(numberTapped(_:)), for: .touchUpInside)
        zeroButton.translatesAutoresizingMaskIntoConstraints = false
        numberPadContainer.addSubview(zeroButton)
        numberButtons.append(zeroButton)
        
        // Position 0 at bottom center (4th row, middle column)
        NSLayoutConstraint.activate([
            zeroButton.centerXAnchor.constraint(equalTo: numberPadContainer.centerXAnchor),
            zeroButton.topAnchor.constraint(equalTo: numberPadContainer.topAnchor, constant: 3 * (buttonSize + spacing)),
            zeroButton.widthAnchor.constraint(equalToConstant: buttonSize),
            zeroButton.heightAnchor.constraint(equalToConstant: buttonSize)
        ])
        
        // Control buttons container
        let controlButtonsContainer = UIView()
        controlButtonsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlButtonsContainer)
        
        // Clear button - smaller and more compact
        clearButton.setTitle("🗑️", for: .normal)
        clearButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        clearButton.layer.cornerRadius = 22
        clearButton.layer.borderWidth = 2
        clearButton.layer.borderColor = UIColor.white.cgColor
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        controlButtonsContainer.addSubview(clearButton)
        
        // Submit button - more compact
        submitButton.setTitle("✅", for: .normal)
        submitButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        submitButton.layer.cornerRadius = 22
        submitButton.layer.borderWidth = 2
        submitButton.layer.borderColor = UIColor.white.cgColor
        submitButton.alpha = 0.5
        submitButton.isEnabled = false
        submitButton.addTarget(self, action: #selector(submitGuess), for: .touchUpInside)
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        controlButtonsContainer.addSubview(submitButton)
        
        // Layout control buttons
        NSLayoutConstraint.activate([
            // Control buttons container
            controlButtonsContainer.topAnchor.constraint(equalTo: numberPadContainer.bottomAnchor, constant: 15),
            controlButtonsContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            controlButtonsContainer.widthAnchor.constraint(equalToConstant: 140),
            controlButtonsContainer.heightAnchor.constraint(equalToConstant: 44),
            
            // Clear button
            clearButton.leadingAnchor.constraint(equalTo: controlButtonsContainer.leadingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: controlButtonsContainer.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 44),
            clearButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Submit button
            submitButton.trailingAnchor.constraint(equalTo: controlButtonsContainer.trailingAnchor),
            submitButton.centerYAnchor.constraint(equalTo: controlButtonsContainer.centerYAnchor),
            submitButton.widthAnchor.constraint(equalToConstant: 44),
            submitButton.heightAnchor.constraint(equalToConstant: 44)
        ])
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
        
        // Add player cards
        createPlayerCard(name: "You", secret: playerSecret, isPlayer: true)
        createPlayerCard(name: npc.name, secret: "???", isPlayer: false)
    }
    
    private func createPlayerCard(name: String, secret: String, isPlayer: Bool) {
        let playerCard = UIView()
        playerCard.backgroundColor = isPlayer ? 
            UIColor.systemBlue.withAlphaComponent(0.3) : 
            UIColor.systemRed.withAlphaComponent(0.3)
        playerCard.layer.cornerRadius = 8
        playerCard.layer.borderWidth = 1
        playerCard.layer.borderColor = isPlayer ? 
            UIColor.systemBlue.withAlphaComponent(0.7).cgColor : 
            UIColor.systemRed.withAlphaComponent(0.7).cgColor
        
        let nameLabel = UILabel()
        nameLabel.text = isPlayer ? "👤 \(name)" : "\(npc.avatar) \(name)"
        nameLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 0
        nameLabel.lineBreakMode = .byWordWrapping
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        playerCard.addSubview(nameLabel)
        
        let secretLabel = UILabel()
        secretLabel.text = "Secret: \(secret)"
        secretLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        secretLabel.textColor = isPlayer ? .systemBlue : .systemRed
        secretLabel.numberOfLines = 0
        secretLabel.lineBreakMode = .byWordWrapping
        secretLabel.translatesAutoresizingMaskIntoConstraints = false
        playerCard.addSubview(secretLabel)
        
        NSLayoutConstraint.activate([
            playerCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 45),
            
            nameLabel.leadingAnchor.constraint(equalTo: playerCard.leadingAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: playerCard.trailingAnchor, constant: -6),
            nameLabel.topAnchor.constraint(equalTo: playerCard.topAnchor, constant: 4),
            
            secretLabel.leadingAnchor.constraint(equalTo: playerCard.leadingAnchor, constant: 6),
            secretLabel.trailingAnchor.constraint(equalTo: playerCard.trailingAnchor, constant: -6),
            secretLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            secretLabel.bottomAnchor.constraint(equalTo: playerCard.bottomAnchor, constant: -4)
        ])
        
        playersStackView.addArrangedSubview(playerCard)
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
            
            // Top status content
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
            inputDisplayView.heightAnchor.constraint(equalToConstant: 80),
            
            inputLabel.centerXAnchor.constraint(equalTo: inputDisplayView.centerXAnchor),
            inputLabel.topAnchor.constraint(equalTo: inputDisplayView.topAnchor, constant: 10),
            
            statusLabel.centerXAnchor.constraint(equalTo: inputDisplayView.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: inputLabel.bottomAnchor, constant: 5),
            
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
            historyStackView.widthAnchor.constraint(equalTo: historyScrollView.widthAnchor)
        ])
    }
    
    private func animateEntrance() {
        let views = [topStatusView, inputDisplayView, numberPadContainer, playersContainer, historyContainer]
        
        views.forEach { view in
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 30)
        }
        
        UIView.animateKeyframes(withDuration: 1.5, delay: 0.3, options: [], animations: {
            for (index, view) in views.enumerated() {
                UIView.addKeyframe(withRelativeStartTime: Double(index) * 0.1, relativeDuration: 0.3) {
                    view.alpha = 1
                    view.transform = .identity
                }
            }
        })
    }
    
    // MARK: - Timer Methods
    private func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func updateTimer() {
        gameTime += 1
        let minutes = gameTime / 60
        let seconds = gameTime % 60
        timerLabel.text = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Actions
    @objc private func numberTapped(_ sender: UIButton) {
        guard isPlayerTurn && !gameEnded else { return }
        
        let number = sender.tag
        let numberString = "\(number)"
        
        // Check if number is already in guess
        if currentGuess.contains(numberString) { return }
        
        // Check if we have space for more digits
        if currentGuess.count < gameMode.digits {
            currentGuess += numberString
            updateInputDisplay()
            updateSubmitButton()
            
            // Add visual feedback
            addButtonPressEffect(to: sender)
        }
    }
    
    @objc private func clearTapped() {
        guard isPlayerTurn && !gameEnded else { return }
        
        currentGuess = ""
        updateInputDisplay()
        updateSubmitButton()
        
        addButtonPressEffect(to: clearButton)
    }
    
    @objc private func submitGuess() {
        guard isPlayerTurn && !gameEnded && currentGuess.count == gameMode.digits else { return }
        
        // Process player move
        let result = NPCManager.shared.processPlayerMove(currentGuess)
        addToHistory(guess: currentGuess, hits: result.hits, isPlayer: true)
        
        if result.isWin {
            showGameEnd(winner: "You", isPlayerWin: true)
            return
        }
        
        // Clear current guess
        currentGuess = ""
        updateInputDisplay()
        updateSubmitButton()
        
        // Switch to NPC turn
        isPlayerTurn = false
        updateUI()
        
        // Generate NPC move
        NPCManager.shared.generateNPCMove { [weak self] npcGuess, hits, isWin in
            DispatchQueue.main.async {
                self?.addToHistory(guess: npcGuess, hits: hits, isPlayer: false)
                
                if isWin {
                    self?.showGameEnd(winner: self?.npc.name ?? "NPC", isPlayerWin: false)
                } else {
                    // Switch back to player turn
                    self?.isPlayerTurn = true
                    self?.updateUI()
                }
            }
        }
        
        addButtonPressEffect(to: submitButton)
    }
    
    @objc private func backTapped() {
        showExitConfirmation()
    }
    
    @objc private func exitTapped() {
        showExitConfirmation()
    }
    
    // MARK: - Helper Methods
    private func updateInputDisplay() {
        if currentGuess.isEmpty {
            inputLabel.text = "Enter your guess..."
            inputLabel.textColor = .lightGray
        } else {
            // Format the guess with spaces for better readability
            let formattedGuess = currentGuess.map { String($0) }.joined(separator: " ")
            inputLabel.text = formattedGuess
            inputLabel.textColor = .white
        }
    }
    
    private func updateSubmitButton() {
        let isReady = currentGuess.count == gameMode.digits && isPlayerTurn && !gameEnded
        submitButton.isEnabled = isReady
        submitButton.alpha = isReady ? 1.0 : 0.5
    }
    
    private func updateUI() {
        if gameEnded {
            turnLabel.text = "Game Over"
            turnLabel.textColor = .systemYellow
            statusLabel.text = "🏁 Game finished!"
        } else if isPlayerTurn {
            turnLabel.text = "Your Turn"
            turnLabel.textColor = .systemGreen
            statusLabel.text = "🎯 Guess \(npc.name)'s secret number!"
        } else {
            turnLabel.text = "\(npc.name)'s Turn"
            turnLabel.textColor = npc.difficulty.color
            statusLabel.text = "🤖 \(npc.name) is thinking..."
        }
        
        updateSubmitButton()
    }
    
    private func addToHistory(guess: String, hits: Int, isPlayer: Bool) {
        let historyItem = UIView()
        historyItem.backgroundColor = isPlayer ? 
            UIColor.systemBlue.withAlphaComponent(0.2) : 
            UIColor.systemRed.withAlphaComponent(0.2)
        historyItem.layer.cornerRadius = 4
        historyItem.layer.borderWidth = 1
        historyItem.layer.borderColor = isPlayer ? 
            UIColor.systemBlue.withAlphaComponent(0.4).cgColor : 
            UIColor.systemRed.withAlphaComponent(0.4).cgColor
        
        let label = UILabel()
        let playerName = isPlayer ? "You" : npc.name
        let emoji = isPlayer ? "👤" : npc.avatar
        label.text = "\(emoji) \(playerName): \(guess) = \(hits) hits"
        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = .white
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        
        historyItem.addSubview(label)
        
        NSLayoutConstraint.activate([
            historyItem.heightAnchor.constraint(greaterThanOrEqualToConstant: 22),
            
            label.leadingAnchor.constraint(equalTo: historyItem.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: historyItem.trailingAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: historyItem.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: historyItem.bottomAnchor, constant: -2)
        ])
        
        historyStackView.addArrangedSubview(historyItem)
        
        // Scroll to bottom with better timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if self.historyScrollView.contentSize.height > self.historyScrollView.bounds.height {
                let bottomOffset = CGPoint(x: 0, y: self.historyScrollView.contentSize.height - self.historyScrollView.bounds.height)
                self.historyScrollView.setContentOffset(bottomOffset, animated: true)
            }
        }
    }
    
    private func addButtonPressEffect(to button: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.transform = .identity
            }
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func showGameEnd(winner: String, isPlayerWin: Bool) {
        gameEnded = true
        stopTimer()
        updateUI()
        
        let npcSecret = NPCManager.shared.getNPCSecret()
        
        let alert = UIAlertController(
            title: isPlayerWin ? "🎉 You Win!" : "😅 \(npc.name) Wins!",
            message: "\(npc.name)'s secret: \(npcSecret)\n\(winner) guessed correctly first!\nTime: \(timerLabel.text ?? "00:00")",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Play Again", style: .default) { _ in
            self.resetGame()
        })
        
        alert.addAction(UIAlertAction(title: "Back to Menu", style: .default) { _ in
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
        
        // Play sound effect
        if isPlayerWin {
            AudioServicesPlaySystemSound(1519) // Victory sound
        } else {
            AudioServicesPlaySystemSound(1521) // Defeat sound
        }
    }
    
    private func showExitConfirmation() {
        let alert = UIAlertController(title: "Exit Game?", message: "Are you sure you want to leave the game?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Stay", style: .cancel))
        alert.addAction(UIAlertAction(title: "Exit", style: .destructive) { _ in
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func resetGame() {
        // Reset game state
        gameEnded = false
        isPlayerTurn = true
        currentGuess = ""
        gameTime = 0
        
        // Clear history
        historyStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Reset UI
        updateInputDisplay()
        updateUI()
        
        // Start new NPC game
        NPCManager.shared.startGameWithNPC(npc, gameMode: gameMode, playerSecret: playerSecret)
        
        // Restart timer
        startTimer()
    }
}

