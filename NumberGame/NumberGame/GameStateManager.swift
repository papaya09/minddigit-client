import Foundation
import UIKit

enum GameMode: Int, CaseIterable {
    case oneDigit = 1
    case twoDigit = 2  
    case threeDigit = 3
    case fourDigit = 4
    
    var displayName: String {
        switch self {
        case .oneDigit: return "1D 🔥"
        case .twoDigit: return "2D ⭐"
        case .threeDigit: return "3D 💎" 
        case .fourDigit: return "4D 👑"
        }
    }
    
    var color: UIColor {
        switch self {
        case .oneDigit: return .systemRed
        case .twoDigit: return .systemOrange
        case .threeDigit: return .systemBlue
        case .fourDigit: return .systemPurple
        }
    }
}

enum GameState {
    case mainMenu
    case waitingForPlayers
    case settingSecret
    case waitingForGame
    case activeGame
    case gameFinished
    
    var displayName: String {
        switch self {
        case .mainMenu: return "Main Menu"
        case .waitingForPlayers: return "Waiting for Players"
        case .settingSecret: return "Setting Secret"
        case .waitingForGame: return "Waiting for Game"
        case .activeGame: return "Active Game"
        case .gameFinished: return "Game Finished"
        }
    }
}

protocol GameStateManagerDelegate: AnyObject {
    func gameStateDidChange(to state: GameState)
    func playersDidUpdate(_ players: [RoomState.Player])
    func gameHistoryDidUpdate(_ history: [String])
    func currentTurnDidChange(to player: String)
}

class GameStateManager: ObservableObject {
    
    // MARK: - Properties
    static let shared = GameStateManager()
    
    weak var delegate: GameStateManagerDelegate?
    
    @Published var gameState: GameState = .mainMenu {
        didSet {
            delegate?.gameStateDidChange(to: gameState)
        }
    }
    
    @Published var selectedGameMode: GameMode = .fourDigit
    @Published var currentRoomCode: String = ""
    @Published var playerName: String = "Player" {
        didSet {
            UserDefaults.standard.set(playerName, forKey: "PlayerName")
        }
    }
    
    @Published var currentInput: String = ""
    @Published var players: [RoomState.Player] = [] {
        didSet {
            delegate?.playersDidUpdate(players)
        }
    }
    
    @Published var gameHistory: [String] = [] {
        didSet {
            delegate?.gameHistoryDidUpdate(gameHistory)
        }
    }
    
    @Published var currentPlayerTurn: String = "" {
        didSet {
            delegate?.currentTurnDidChange(to: currentPlayerTurn)
        }
    }
    
    @Published var gameStartTime: Date?
    @Published var isFirstLaunch: Bool = false
    
    // MARK: - Initialization
    private init() {
        loadPlayerName()
        checkFirstLaunch()
    }
    
    // MARK: - Public Methods
    func addDigit(_ digit: Int) {
        let maxLength = selectedGameMode.rawValue
        if currentInput.count < maxLength {
            currentInput += "\(digit)"
        }
    }
    
    func clearInput() {
        currentInput = ""
    }
    
    func formatInputDisplay(_ input: String, type: String) -> String {
        let maxLength = selectedGameMode.rawValue
        let paddedInput = input.padding(toLength: maxLength, withPad: "_", startingAt: 0)
        
        let spaced = paddedInput.map { String($0) }.joined(separator: " ")
        
        switch type {
        case "SECRET":
            return "🔒 \(spaced)"
        case "GUESS":
            return "🎯 \(spaced)"
        default:
            return spaced
        }
    }
    
    func isInputValid() -> Bool {
        let requiredLength = selectedGameMode.rawValue
        return currentInput.count == requiredLength && currentInput.allSatisfy({ $0.isNumber })
    }
    
    func updateCurrentTurn(lastPlayer: String) {
        if let lastPlayerIndex = players.firstIndex(where: { $0.name == lastPlayer }) {
            let nextIndex = (lastPlayerIndex + 1) % players.count
            if nextIndex < players.count {
                currentPlayerTurn = players[nextIndex].name
            }
        }
    }
    
    func resetGameData() {
        currentRoomCode = ""
        currentInput = ""
        players = []
        gameHistory = []
        currentPlayerTurn = ""
        gameStartTime = nil
        gameState = .mainMenu
    }
    
    func startNewGame() {
        gameState = .activeGame
        gameStartTime = Date()
        if !players.isEmpty {
            currentPlayerTurn = players[0].name
            let startMessage = "🎮 Game started! \(currentPlayerTurn) goes first."
            gameHistory.append(startMessage)
        }
    }
    
    func addToHistory(_ message: String) {
        gameHistory.append(message)
    }
    
    func getFormattedGameTimer() -> String {
        guard let startTime = gameStartTime else {
            return "Time: --:--"
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return "Time: \(String(format: "%02d:%02d", minutes, seconds))"
    }
    
    func isPlayerTurn() -> Bool {
        return currentPlayerTurn == playerName || currentPlayerTurn.isEmpty
    }
    
    func canSubmitInput() -> Bool {
        switch gameState {
        case .settingSecret:
            return isInputValid()
        case .activeGame:
            return isInputValid() && isPlayerTurn()
        default:
            return false
        }
    }
    
    // MARK: - Private Methods
    private func loadPlayerName() {
        if let savedName = UserDefaults.standard.string(forKey: "PlayerName"), !savedName.isEmpty {
            playerName = savedName
        }
    }
    
    private func checkFirstLaunch() {
        isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    }
    
    func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        isFirstLaunch = false
    }
}

// MARK: - GameClient Integration
extension GameStateManager {
    func handleRoomState(_ state: RoomState) {
        players = state.players
        
        switch state.game.state {
        case "waiting":
            if players.first(where: { $0.name == playerName })?.isReady == false {
                gameState = .settingSecret
            } else {
                gameState = .waitingForGame
            }
        case "active":
            if gameState != .activeGame {
                startNewGame()
            }
        case "finished":
            gameState = .gameFinished
        default:
            gameState = .waitingForPlayers
        }
    }
    
    func handleMoveResult(_ result: MoveResult) {
        let historyEntry = "🎯 \(result.from) → \(result.to): \(result.guess) = \(result.hit) hits"
        addToHistory(historyEntry)
        updateCurrentTurn(lastPlayer: result.from)
    }
    
    func handleGameEnd(winner: String, secret: String) {
        gameState = .gameFinished
        let winMessage = "🏆 Winner: \(winner) (Secret: \(secret))"
        addToHistory(winMessage)
    }
}