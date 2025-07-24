import UIKit
import AudioToolbox

class MainMenuViewController: UIViewController {
    
    // MARK: - Properties
    private let gameStateManager = GameStateManager.shared
    private var gameClient: GameClient!
    
    // MARK: - UI Components
    private let backgroundView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let playerNameCard = UIView()
    private let playerNameLabel = UILabel()
    private let gameModesContainer = UIView()
    private var gameModeButtons: [UIButton] = []
    private let playWithNPCButton = UIButton(type: .system)
    private let statisticsButton = UIButton(type: .system)
    private let editCharacterButton = UIButton(type: .system)
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGameClient()
        setupBindings()
        
        if gameStateManager.isFirstLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.showOnboardingTutorial()
            }
        }
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .systemBackground
        setupBackground()
        setupTitleSection()
        setupPlayerSection()
        setupGameModes()
        setupMainButtons()
        setupConstraints()
        animateEntrance()
    }
    
    private func setupBackground() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        
        // Create gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemBlue.withAlphaComponent(0.8).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.6).cgColor,
            UIColor.systemIndigo.withAlphaComponent(0.8).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        backgroundView.layer.addSublayer(gradientLayer)
        
        // Update gradient frame when view layout changes
        DispatchQueue.main.async {
            gradientLayer.frame = self.backgroundView.bounds
        }
    }
    
    private func setupTitleSection() {
        // Main title
        titleLabel.text = "MindDigits"
        titleLabel.font = UIFont.systemFont(ofSize: 48, weight: .ultraLight)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add shadow effect
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 2, height: 2)
        titleLabel.layer.shadowOpacity = 0.8
        titleLabel.layer.shadowRadius = 4
        
        view.addSubview(titleLabel)
        
        // Subtitle
        subtitleLabel.text = "🧠 Think • Guess • Win"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .light)
        subtitleLabel.textColor = UIColor.systemCyan.withAlphaComponent(0.8)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
    }
    
    private func setupPlayerSection() {
        playerNameCard.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        playerNameCard.layer.cornerRadius = 30
        playerNameCard.layer.borderWidth = 2
        playerNameCard.layer.borderColor = UIColor.systemCyan.withAlphaComponent(0.6).cgColor
        playerNameCard.translatesAutoresizingMaskIntoConstraints = false
        
        let playerAvatar = UserDefaults.standard.string(forKey: "playerAvatar") ?? "👤"
        playerNameLabel.text = "\(playerAvatar) \(gameStateManager.playerName)"
        playerNameLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        playerNameLabel.textColor = .white
        playerNameLabel.textAlignment = .center
        playerNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        playerNameCard.addSubview(playerNameLabel)
        view.addSubview(playerNameCard)
        
        // Add tap gesture to edit player name
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(editPlayerName))
        playerNameCard.addGestureRecognizer(tapGesture)
        playerNameCard.isUserInteractionEnabled = true
    }
    
    private func setupGameModes() {
        gameModesContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gameModesContainer)
        
        // Header
        let headerLabel = UILabel()
        headerLabel.text = "🎮 SELECT\nDIFFICULTY"
        headerLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        headerLabel.textColor = .systemYellow
        headerLabel.textAlignment = .center
        headerLabel.numberOfLines = 0
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        gameModesContainer.addSubview(headerLabel)
        
        // Game mode buttons
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 15
        stackView.translatesAutoresizingMaskIntoConstraints = false
        gameModesContainer.addSubview(stackView)
        
        for mode in GameMode.allCases {
            let button = createGameModeButton(for: mode)
            stackView.addArrangedSubview(button)
            gameModeButtons.append(button)
        }
        
        // Constraints for game modes container
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: gameModesContainer.topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: gameModesContainer.leadingAnchor),
            headerLabel.trailingAnchor.constraint(equalTo: gameModesContainer.trailingAnchor),
            
            stackView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: gameModesContainer.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: gameModesContainer.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: gameModesContainer.bottomAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 100)
        ])
        
        updateSelectedGameMode(gameStateManager.selectedGameMode)
    }
    
    private func createGameModeButton(for mode: GameMode) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(mode.displayName, for: .normal)
        button.backgroundColor = mode.color
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.layer.cornerRadius = 20
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor.white.cgColor
        
        // Add shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 2, height: 2)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 2
        
        button.tag = mode.rawValue
        button.addTarget(self, action: #selector(gameModeSelected(_:)), for: .touchUpInside)
        
        return button
    }
    
    // Add Play Online button
    private let playOnlineButton = UIButton(type: .system)
    
    private func setupMainButtons() {
        let buttons = [playOnlineButton, playWithNPCButton, statisticsButton, editCharacterButton]
        let titles = ["🌐 PLAY\nONLINE", "🤖 PLAY VS\nNPC", "📊 STATISTICS", "✏️ EDIT\nCHARACTER"]
        let colors: [UIColor] = [.systemGreen, .systemTeal, .systemOrange, .systemPurple]
        let actions = [#selector(playOnlineTapped), #selector(playWithNPCTapped), #selector(statisticsTapped), #selector(editCharacterTapped)]
        
        for (index, button) in buttons.enumerated() {
            button.setTitle(titles[index], for: .normal)
            button.backgroundColor = colors[index]
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.textAlignment = .center
            button.layer.cornerRadius = 35
            button.layer.borderWidth = 5
            button.layer.borderColor = UIColor.white.cgColor
            
            // Add shadow
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOffset = CGSize(width: 4, height: 4)
            button.layer.shadowOpacity = 0.4
            button.layer.shadowRadius = 4
            
            button.addTarget(self, action: actions[index], for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(button)
        }
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
            titleLabel.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Player name card
            playerNameCard.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            playerNameCard.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playerNameCard.widthAnchor.constraint(equalToConstant: 280),
            playerNameCard.heightAnchor.constraint(equalToConstant: 60),
            
            playerNameLabel.centerXAnchor.constraint(equalTo: playerNameCard.centerXAnchor),
            playerNameLabel.centerYAnchor.constraint(equalTo: playerNameCard.centerYAnchor),
            
            // Game modes
            gameModesContainer.topAnchor.constraint(equalTo: playerNameCard.bottomAnchor, constant: 40),
            gameModesContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            gameModesContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            gameModesContainer.heightAnchor.constraint(equalToConstant: 140),
            
            // Main buttons
            playOnlineButton.topAnchor.constraint(equalTo: gameModesContainer.bottomAnchor, constant: 40),
            playOnlineButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playOnlineButton.widthAnchor.constraint(equalToConstant: 320),
            playOnlineButton.heightAnchor.constraint(equalToConstant: 80),
            
            playWithNPCButton.topAnchor.constraint(equalTo: playOnlineButton.bottomAnchor, constant: 15),
            playWithNPCButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playWithNPCButton.widthAnchor.constraint(equalToConstant: 320),
            playWithNPCButton.heightAnchor.constraint(equalToConstant: 70),
            
            statisticsButton.topAnchor.constraint(equalTo: playWithNPCButton.bottomAnchor, constant: 15),
            statisticsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statisticsButton.widthAnchor.constraint(equalToConstant: 320),
            statisticsButton.heightAnchor.constraint(equalToConstant: 60),
            
            editCharacterButton.topAnchor.constraint(equalTo: statisticsButton.bottomAnchor, constant: 15),
            editCharacterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            editCharacterButton.widthAnchor.constraint(equalToConstant: 320),
            editCharacterButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    private func setupGameClient() {
        gameClient = GameClient()
        gameClient.delegate = self
        gameClient.connect()
    }
    
    private func setupBindings() {
        gameStateManager.delegate = self
    }
    
    // MARK: - Actions
    @objc private func gameModeSelected(_ sender: UIButton) {
        if let mode = GameMode(rawValue: sender.tag) {
            gameStateManager.selectedGameMode = mode
            updateSelectedGameMode(mode)
            addButtonPressEffect(to: sender)
        }
    }
    
    
    @objc private func statisticsTapped() {
        addMainButtonEffect(to: statisticsButton)
        showStatistics()
    }
    
    @objc private func editPlayerName() {
        navigateToCharacterEdit()
    }
    
    @objc private func editCharacterTapped() {
        addMainButtonEffect(to: editCharacterButton)
        navigateToCharacterCreation()
    }
    
    @objc private func playOnlineTapped() {
        addMainButtonEffect(to: playOnlineButton)
        navigateToOnlineGame()
    }
    
    @objc private func playWithNPCTapped() {
        addMainButtonEffect(to: playWithNPCButton)
        showNPCSelectionDialog()
    }
    
    // MARK: - UI Updates
    private func updateSelectedGameMode(_ mode: GameMode) {
        for button in gameModeButtons {
            if button.tag == mode.rawValue {
                button.layer.borderColor = UIColor.systemYellow.cgColor
                button.layer.borderWidth = 6
                UIView.animate(withDuration: 0.2) {
                    button.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                }
            } else {
                button.layer.borderColor = UIColor.white.cgColor
                button.layer.borderWidth = 3
                UIView.animate(withDuration: 0.2) {
                    button.transform = .identity
                }
            }
        }
        
        // Haptic feedback
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    private func updatePlayerNameDisplay() {
        let playerAvatar = UserDefaults.standard.string(forKey: "playerAvatar") ?? "👤"
        playerNameLabel.text = "\(playerAvatar) \(gameStateManager.playerName)"
        
        UIView.animate(withDuration: 0.2, animations: {
            self.playerNameLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.playerNameLabel.transform = .identity
            }
        }
    }
    
    // MARK: - Animations
    private func animateEntrance() {
        let views = [titleLabel, subtitleLabel, playerNameCard, gameModesContainer, 
                    playOnlineButton, playWithNPCButton, statisticsButton, editCharacterButton]
        
        views.forEach { view in
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 30)
        }
        
        UIView.animateKeyframes(withDuration: 1.5, delay: 0.5, options: [], animations: {
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
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.transform = .identity
            }
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        AudioServicesPlaySystemSound(1104)
    }
    
    private func addMainButtonEffect(to button: UIButton) {
        let originalColor = button.backgroundColor
        
        UIView.animate(withDuration: 0.05, animations: {
            button.backgroundColor = UIColor.white.withAlphaComponent(0.9)
            button.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                button.backgroundColor = originalColor
                button.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    button.transform = .identity
                }
            }
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        AudioServicesPlaySystemSound(1519)
    }
    
    // MARK: - Alert Methods
    
    private func showStatistics() {
        let alert = UIAlertController(title: "📊 Statistics", 
                                    message: "Games Won: 0\nGames Played: 0\nBest Time: --:--\nFavorite Mode: \(gameStateManager.selectedGameMode.displayName)", 
                                    preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showOnboardingTutorial() {
        let alert = UIAlertController(title: "🎯 Welcome to MindDigits!", 
                                    message: "A fun multiplayer number guessing game\n\n• Choose your difficulty level\n• Create or join rooms\n• Challenge friends to guess your secret number!", 
                                    preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Let's Play! 🚀", style: .default) { _ in
            self.gameStateManager.markOnboardingComplete()
        })
        present(alert, animated: true)
    }
    
    private func showNPCSelectionDialog() {
        let alert = UIAlertController(title: "🤖 เลือกคู่ต่อสู้ NPC", message: "เลือก NPC ที่คุณต้องการท้าทาย", preferredStyle: .alert)
        
        for npc in NPCCharacter.characters {
            let action = UIAlertAction(title: "\(npc.avatar) \(npc.name) (\(npc.difficulty.displayName))", style: .default) { _ in
                self.startNPCGame(with: npc)
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "ยกเลิก", style: .cancel))
        present(alert, animated: true)
    }
    
    private func startNPCGame(with npc: NPCCharacter) {
        // Show secret number input dialog
        let alert = UIAlertController(title: "🔢 ตั้งเลขลับของคุณ", 
                                    message: "ใส่เลขลับ \(gameStateManager.selectedGameMode.digits) หลัก\nที่ \(npc.name) จะต้องทาย", 
                                    preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "เลขลับ \(self.gameStateManager.selectedGameMode.digits) หลัก"
            textField.keyboardType = .numberPad
            textField.textAlignment = .center
        }
        
        alert.addAction(UIAlertAction(title: "เริ่มเกม", style: .default) { _ in
            if let secretText = alert.textFields?.first?.text,
               secretText.count == self.gameStateManager.selectedGameMode.digits,
               self.isValidSecretNumber(secretText) {
                self.navigateToNPCGameplay(npc: npc, playerSecret: secretText)
            } else {
                self.showInvalidSecretAlert()
            }
        })
        
        alert.addAction(UIAlertAction(title: "ยกเลิก", style: .cancel))
        present(alert, animated: true)
    }
    
    private func isValidSecretNumber(_ secret: String) -> Bool {
        // Check if all digits are unique
        let digits = Set(secret)
        return digits.count == secret.count && secret.allSatisfy { $0.isNumber }
    }
    
    private func showInvalidSecretAlert() {
        let alert = UIAlertController(title: "เลขลับไม่ถูกต้อง", 
                                    message: "กรุณาใส่เลขลับ \(gameStateManager.selectedGameMode.digits) หลัก\nโดยแต่ละหลักต้องไม่ซ้ำกัน", 
                                    preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ตกลง", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Navigation
    private func navigateToGameplay() {
        let gameplayVC = GameplayViewController()
        gameplayVC.modalPresentationStyle = .fullScreen
        present(gameplayVC, animated: true)
    }
    
    private func navigateToCharacterCreation() {
        // แก้ไขชื่อและ avatar ตรงนี่
        showCharacterEditDialog()
    }
    
    private func navigateToCharacterEdit() {
        showCharacterEditDialog()
    }
    
    private func showCharacterEditDialog() {
        let alert = UIAlertController(title: "✏️ Edit Character", message: "Change your name and avatar", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Player Name"
            textField.text = self.gameStateManager.playerName
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Avatar (emoji)"
            textField.text = UserDefaults.standard.string(forKey: "playerAvatar") ?? "👤"
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            if let name = alert.textFields?[0].text, !name.isEmpty {
                self.gameStateManager.playerName = name
            }
            if let avatar = alert.textFields?[1].text, !avatar.isEmpty {
                UserDefaults.standard.set(avatar, forKey: "playerAvatar")
            }
            self.updatePlayerNameDisplay()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func navigateToNPCGameplay(npc: NPCCharacter, playerSecret: String) {
        let npcGameplayVC = NPCGameplayViewController(npc: npc, gameMode: gameStateManager.selectedGameMode, playerSecret: playerSecret)
        npcGameplayVC.modalPresentationStyle = .fullScreen
        present(npcGameplayVC, animated: true)
    }
    
    private func navigateToOnlineGame() {
        let onlineWaitingVC = OnlineWaitingViewController()
        onlineWaitingVC.modalPresentationStyle = .fullScreen
        present(onlineWaitingVC, animated: true)
    }
}

// MARK: - GameStateManagerDelegate
extension MainMenuViewController: GameStateManagerDelegate {
    func gameStateDidChange(to state: GameState) {
        // Handle state changes if needed
    }
    
    func playersDidUpdate(_ players: [RoomState.Player]) {
        // Handle player updates if needed
    }
    
    func gameHistoryDidUpdate(_ history: [String]) {
        // Handle history updates if needed
    }
    
    func currentTurnDidChange(to player: String) {
        // Handle turn changes if needed
    }
}

// MARK: - GameClientDelegate
extension MainMenuViewController: GameClientDelegate {
    func gameClient(_ client: GameClient, didReceiveRoomState state: RoomState) {}
    func gameClient(_ client: GameClient, didReceiveError error: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: error, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }
    func gameClient(_ client: GameClient, gameDidStart: Bool) {}
    func gameClient(_ client: GameClient, didReceiveMoveResult result: MoveResult) {}
    func gameClient(_ client: GameClient, gameDidEnd winner: String, secret: String) {}
}