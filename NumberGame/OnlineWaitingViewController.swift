import UIKit

class OnlineWaitingViewController: UIViewController {
    
    // MARK: - Properties
    var playerName: String = ""
    var roomId: String = ""
    var playerId: String = ""
    var position: Int = 0
    var gameState: String = "WAITING"
    var currentDigits: Int = 4
    
    // Network polling
    var statusTimer: Timer?
    let baseURL = "https://minddigit-server.vercel.app/api"
    
    // MARK: - UI Components
    private let backgroundView = UIView()
    private let titleLabel = UILabel()
    let statusLabel = UILabel()
    private let roomInfoCard = UIView()
    let roomIdLabel = UILabel()
    private let playersContainer = UIView()
    let player1Label = UILabel()
    let player2Label = UILabel()
    private let vsLabel = UILabel()
    let actionButton = UIButton(type: .system)
    private let backButton = UIButton(type: .system)
    let loadingSpinner = UIActivityIndicatorView(style: .large)
    
    // Digit Selection UI
    let digitSelectionContainer = UIView()
    private let digitLabel = UILabel()
    private let digitButtons: [UIButton] = (3...6).map { _ in UIButton(type: .system) }
    
    // Secret Setting UI
    let secretContainer = UIView()
    private let secretLabel = UILabel()
    let secretTextField = UITextField()
    private let secretHintLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupRefreshButton()
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        print("🎮 OnlineWaitingViewController loaded")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Show dialog after view is in hierarchy
        if playerName.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showPlayerNameDialog()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPolling()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .systemBackground
        setupBackground()
        setupTitleSection()
        setupRoomInfo()
        setupPlayersDisplay()
        setupDigitSelection()
        setupSecretSetting()
        setupButtons()
        setupConstraints()
        
        // Initially hide game-specific UI
        digitSelectionContainer.isHidden = true
        secretContainer.isHidden = true
        actionButton.isHidden = true
    }
    
    private func setupBackground() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemGreen.withAlphaComponent(0.8).cgColor,
            UIColor.systemBlue.withAlphaComponent(0.6).cgColor,
            UIColor.systemTeal.withAlphaComponent(0.8).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        backgroundView.layer.addSublayer(gradientLayer)
        
        DispatchQueue.main.async {
            gradientLayer.frame = self.backgroundView.bounds
        }
    }
    
    private func setupTitleSection() {
        titleLabel.text = "🌐 Online Game"
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 2, height: 2)
        titleLabel.layer.shadowOpacity = 0.8
        titleLabel.layer.shadowRadius = 4
        
        view.addSubview(titleLabel)
        
        statusLabel.text = "Connecting..."
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = UIColor.systemYellow
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        loadingSpinner.color = .white
        loadingSpinner.hidesWhenStopped = true
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingSpinner)
    }
    
    private func setupRoomInfo() {
        roomInfoCard.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        roomInfoCard.layer.cornerRadius = 20
        roomInfoCard.layer.borderWidth = 2
        roomInfoCard.layer.borderColor = UIColor.systemCyan.withAlphaComponent(0.6).cgColor
        roomInfoCard.translatesAutoresizingMaskIntoConstraints = false
        
        roomIdLabel.text = "Room: ---"
        roomIdLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        roomIdLabel.textColor = .white
        roomIdLabel.textAlignment = .center
        roomIdLabel.translatesAutoresizingMaskIntoConstraints = false
        
        roomInfoCard.addSubview(roomIdLabel)
        view.addSubview(roomInfoCard)
    }
    
    private func setupPlayersDisplay() {
        playersContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(playersContainer)
        
        player1Label.text = "👤 Waiting..."
        player1Label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        player1Label.textColor = .white
        player1Label.textAlignment = .center
        player1Label.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        player1Label.layer.cornerRadius = 15
        player1Label.layer.masksToBounds = true
        player1Label.translatesAutoresizingMaskIntoConstraints = false
        
        vsLabel.text = "VS"
        vsLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        vsLabel.textColor = UIColor.systemYellow
        vsLabel.textAlignment = .center
        vsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        player2Label.text = "👤 Waiting..."
        player2Label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        player2Label.textColor = .white
        player2Label.textAlignment = .center
        player2Label.backgroundColor = UIColor.systemRed.withAlphaComponent(0.3)
        player2Label.layer.cornerRadius = 15
        player2Label.layer.masksToBounds = true
        player2Label.translatesAutoresizingMaskIntoConstraints = false
        
        playersContainer.addSubview(player1Label)
        playersContainer.addSubview(vsLabel)
        playersContainer.addSubview(player2Label)
    }
    
    private func setupDigitSelection() {
        digitSelectionContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(digitSelectionContainer)
        
        digitLabel.text = "🔢 Select Number of Digits"
        digitLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        digitLabel.textColor = UIColor.systemYellow
        digitLabel.textAlignment = .center
        digitLabel.translatesAutoresizingMaskIntoConstraints = false
        digitSelectionContainer.addSubview(digitLabel)
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 15
        stackView.translatesAutoresizingMaskIntoConstraints = false
        digitSelectionContainer.addSubview(stackView)
        
        for (index, button) in digitButtons.enumerated() {
            let digits = index + 1
            button.setTitle("\(digits)D", for: .normal)
            button.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.7)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            button.layer.cornerRadius = 25
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.white.cgColor
            button.tag = digits
            button.addTarget(self, action: #selector(digitSelected(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
        
        NSLayoutConstraint.activate([
            digitLabel.topAnchor.constraint(equalTo: digitSelectionContainer.topAnchor),
            digitLabel.leadingAnchor.constraint(equalTo: digitSelectionContainer.leadingAnchor),
            digitLabel.trailingAnchor.constraint(equalTo: digitSelectionContainer.trailingAnchor),
            
            stackView.topAnchor.constraint(equalTo: digitLabel.bottomAnchor, constant: 15),
            stackView.leadingAnchor.constraint(equalTo: digitSelectionContainer.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: digitSelectionContainer.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: digitSelectionContainer.bottomAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupSecretSetting() {
        secretContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(secretContainer)
        
        secretLabel.text = "🔐 Set Your Secret Number"
        secretLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        secretLabel.textColor = UIColor.systemYellow
        secretLabel.textAlignment = .center
        secretLabel.translatesAutoresizingMaskIntoConstraints = false
        secretContainer.addSubview(secretLabel)
        
        secretTextField.placeholder = "Enter your secret"
        secretTextField.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        secretTextField.layer.cornerRadius = 10
        secretTextField.textAlignment = .center
        secretTextField.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        secretTextField.keyboardType = .numberPad
        secretTextField.delegate = self
        secretTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Add keyboard toolbar with Done button
        setupKeyboardToolbar()
        
        secretContainer.addSubview(secretTextField)
        
        secretHintLabel.text = "Enter 4 unique digits (e.g., 1234)"
        secretHintLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        secretHintLabel.textColor = UIColor.systemCyan.withAlphaComponent(0.8)
        secretHintLabel.textAlignment = .center
        secretHintLabel.translatesAutoresizingMaskIntoConstraints = false
        secretContainer.addSubview(secretHintLabel)
        
        NSLayoutConstraint.activate([
            secretLabel.topAnchor.constraint(equalTo: secretContainer.topAnchor),
            secretLabel.leadingAnchor.constraint(equalTo: secretContainer.leadingAnchor),
            secretLabel.trailingAnchor.constraint(equalTo: secretContainer.trailingAnchor),
            
            secretTextField.topAnchor.constraint(equalTo: secretLabel.bottomAnchor, constant: 15),
            secretTextField.centerXAnchor.constraint(equalTo: secretContainer.centerXAnchor),
            secretTextField.widthAnchor.constraint(equalToConstant: 200),
            secretTextField.heightAnchor.constraint(equalToConstant: 50),
            
            secretHintLabel.topAnchor.constraint(equalTo: secretTextField.bottomAnchor, constant: 10),
            secretHintLabel.leadingAnchor.constraint(equalTo: secretContainer.leadingAnchor),
            secretHintLabel.trailingAnchor.constraint(equalTo: secretContainer.trailingAnchor),
            secretHintLabel.bottomAnchor.constraint(equalTo: secretContainer.bottomAnchor)
        ])
    }
    
    private func setupKeyboardToolbar() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.barStyle = .default
        toolbar.backgroundColor = UIColor.systemBackground
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(
            title: "✅ Done",
            style: .done,
            target: self,
            action: #selector(dismissKeyboard)
        )
        doneButton.tintColor = UIColor.systemBlue
        
        toolbar.items = [flexSpace, doneButton]
        secretTextField.inputAccessoryView = toolbar
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
        
        // Add haptic feedback
        let impactGenerator = UIImpactFeedbackGenerator(style: .light)
        impactGenerator.impactOccurred()
        
        print("⌨️ Keyboard dismissed")
    }
    
    private func setupButtons() {
        actionButton.setTitle("🎮 Start Game", for: .normal)
        actionButton.backgroundColor = UIColor.systemGreen
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        actionButton.layer.cornerRadius = 25
        actionButton.layer.borderWidth = 3
        actionButton.layer.borderColor = UIColor.white.cgColor
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(actionButton)
        
        backButton.setTitle("← Back", for: .normal)
        backButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.7)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        backButton.layer.cornerRadius = 20
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            // Background
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Status
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Loading spinner
            loadingSpinner.centerXAnchor.constraint(equalTo: statusLabel.centerXAnchor),
            loadingSpinner.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            
            // Room info
            roomInfoCard.topAnchor.constraint(equalTo: loadingSpinner.bottomAnchor, constant: 30),
            roomInfoCard.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            roomInfoCard.widthAnchor.constraint(equalToConstant: 280),
            roomInfoCard.heightAnchor.constraint(equalToConstant: 60),
            
            roomIdLabel.centerXAnchor.constraint(equalTo: roomInfoCard.centerXAnchor),
            roomIdLabel.centerYAnchor.constraint(equalTo: roomInfoCard.centerYAnchor),
            
            // Players
            playersContainer.topAnchor.constraint(equalTo: roomInfoCard.bottomAnchor, constant: 30),
            playersContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            playersContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            playersContainer.heightAnchor.constraint(equalToConstant: 100),
            
            player1Label.leadingAnchor.constraint(equalTo: playersContainer.leadingAnchor),
            player1Label.centerYAnchor.constraint(equalTo: playersContainer.centerYAnchor),
            player1Label.widthAnchor.constraint(equalToConstant: 120),
            player1Label.heightAnchor.constraint(equalToConstant: 60),
            
            vsLabel.centerXAnchor.constraint(equalTo: playersContainer.centerXAnchor),
            vsLabel.centerYAnchor.constraint(equalTo: playersContainer.centerYAnchor),
            
            player2Label.trailingAnchor.constraint(equalTo: playersContainer.trailingAnchor),
            player2Label.centerYAnchor.constraint(equalTo: playersContainer.centerYAnchor),
            player2Label.widthAnchor.constraint(equalToConstant: 120),
            player2Label.heightAnchor.constraint(equalToConstant: 60),
            
            // Digit selection
            digitSelectionContainer.topAnchor.constraint(equalTo: playersContainer.bottomAnchor, constant: 40),
            digitSelectionContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            digitSelectionContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            digitSelectionContainer.heightAnchor.constraint(equalToConstant: 80),
            
            // Secret setting
            secretContainer.topAnchor.constraint(equalTo: playersContainer.bottomAnchor, constant: 40),
            secretContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            secretContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            secretContainer.heightAnchor.constraint(equalToConstant: 120),
            
            // Action button
            actionButton.bottomAnchor.constraint(equalTo: backButton.topAnchor, constant: -20),
            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 250),
            actionButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Back button
            backButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -20),
            backButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 120),
            backButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - Actions
    @objc private func digitSelected(_ sender: UIButton) {
        let selectedDigits = sender.tag
        currentDigits = selectedDigits
        
        // Update UI
        digitButtons.forEach { button in
            if button.tag == selectedDigits {
                button.backgroundColor = UIColor.systemGreen
                button.layer.borderColor = UIColor.systemYellow.cgColor
                button.layer.borderWidth = 3
            } else {
                button.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.7)
                button.layer.borderColor = UIColor.white.cgColor
                button.layer.borderWidth = 2
            }
        }
        
        // Send selection to server
        selectDigits(currentDigits)
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Game Transition
    private func transitionToGameScreen() {
        print("🎮 Transitioning to game screen...")
        
        // Create online game view controller programmatically
        let gameVC = OnlineGameViewController()
        gameVC.configure(roomId: self.roomId, playerId: self.playerId, digits: self.currentDigits)
        gameVC.modalPresentationStyle = .fullScreen
        
        present(gameVC, animated: true)
    }
    
    // MARK: - Action Handlers
    @objc private func actionButtonTapped() {
        switch gameState {
        case "DIGIT_SELECTION":
            confirmDigitSelection()
        case "SECRET_SETTING":
            setSecretNumber()
        case "FINISHED":
            backToMenu()
        default:
            print("🤷‍♂️ No action for state: \(gameState)")
        }
    }
    
    private func confirmDigitSelection() {
        print("🎯 Confirming digit selection: \(currentDigits)")
        selectDigits(currentDigits)
    }
    
    private func setSecretNumber() {
        guard let secretText = secretTextField.text, 
              !secretText.isEmpty else {
            showError("Please enter a secret number")
            return
        }
        
        print("🔐 Setting secret number: \(secretText)")
        // Store the secret for later use
        UserDefaults.standard.set(secretText, forKey: "currentSecret")
        setSecret()
    }
    
    private func backToMenu() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    @objc private func backButtonTapped() {
        stopPolling()
        if !playerId.isEmpty {
            leaveGame()
        }
        dismiss(animated: true)
    }
    
    // MARK: - UI Updates
    func updateUI(for state: String) {
        let oldState = gameState
        gameState = state
        print("🎯 Updating UI: \(oldState ?? "nil") → \(state)")
        
        DispatchQueue.main.async {
            // Hide all containers first
            self.digitSelectionContainer.isHidden = true
            self.secretContainer.isHidden = true
            self.actionButton.isHidden = true
            
            print("🎨 UI containers reset, now showing UI for: \(state)")
            
            switch state {
            case "WAITING":
                self.statusLabel.text = "⏳ Waiting for player 2..."
                self.statusLabel.textColor = .systemYellow
                self.actionButton.isHidden = true
                
            case "DIGIT_SELECTION":
                print("🔢 Showing digit selection UI")
                self.statusLabel.text = "🎯 Choose number of digits"
                self.statusLabel.textColor = .systemOrange
                self.digitSelectionContainer.isHidden = false
                self.actionButton.isHidden = false
                self.actionButton.setTitle("Confirm Digits", for: .normal)
                self.actionButton.backgroundColor = .systemOrange
                
            case "SECRET_SETTING":
                print("🔐 Showing secret setting UI")
                self.statusLabel.text = "🔐 Set your secret number"
                self.statusLabel.textColor = .systemPurple
                self.secretContainer.isHidden = false
                self.actionButton.isHidden = false
                self.actionButton.setTitle("Set Secret", for: .normal)
                self.actionButton.backgroundColor = .systemPurple
                
            case "PLAYING":
                print("🎮 Transitioning to game screen")
                self.statusLabel.text = "🎮 Game started! Make your guesses"
                self.statusLabel.textColor = .systemGreen
                // Transition to game screen
                self.transitionToGameScreen()
                
            case "FINISHED":
                self.statusLabel.text = "🏆 Game completed!"
                self.statusLabel.textColor = .systemBlue
                self.actionButton.isHidden = false
                self.actionButton.setTitle("Back to Menu", for: .normal)
                self.actionButton.backgroundColor = .systemBlue
                
            default:
                self.statusLabel.text = "🔄 \(state)"
                self.statusLabel.textColor = .systemGray
            }
            
            print("✅ UI update completed for state: \(state)")
        }
    }
    
    func updatePlayersDisplay(_ players: [[String: Any]]) {
        DispatchQueue.main.async {
            for (index, playerData) in players.enumerated() {
                let name = playerData["name"] as? String ?? "Unknown"
                let isReady = playerData["isReady"] as? Bool ?? false
                let isHost = playerData["isHost"] as? Bool ?? false
                
                let displayText = "\(isHost ? "👑" : "👤") \(name)\(isReady ? " ✅" : "")"
                
                if index == 0 {
                    self.player1Label.text = displayText
                } else if index == 1 {
                    self.player2Label.text = displayText
                }
            }
            
            // If only one player, show waiting for second
            if players.count == 1 {
                self.player2Label.text = "👤 Waiting..."
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension OnlineWaitingViewController: UITextFieldDelegate {
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Only allow numbers
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        
        if !allowedCharacters.isSuperset(of: characterSet) {
            return false
        }
        
        // Calculate the new text
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        // Limit to currentDigits length
        if updatedText.count > currentDigits {
            return false
        }
        
        // Update hint label based on current digits
        DispatchQueue.main.async {
            if updatedText.count == self.currentDigits {
                // Check for unique digits
                let uniqueDigits = Set(updatedText)
                if uniqueDigits.count == updatedText.count {
                    self.secretHintLabel.text = "✅ Perfect! \(self.currentDigits) unique digits"
                    self.secretHintLabel.textColor = .systemGreen
                    
                    // Auto-submit after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.dismissKeyboard()
                    }
                } else {
                    self.secretHintLabel.text = "❌ All digits must be unique"
                    self.secretHintLabel.textColor = .systemRed
                }
            } else {
                self.secretHintLabel.text = "Enter \(self.currentDigits) unique digits (\(updatedText.count)/\(self.currentDigits))"
                self.secretHintLabel.textColor = UIColor.systemCyan.withAlphaComponent(0.8)
            }
        }
        
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}