import Foundation
import UIKit

// MARK: - Supporting Types

struct PendingGuess {
    let id: UUID
    let guess: String
    let target: String
    let timestamp: Date
    var status: PendingStatus
    var hits: Int?
    
    enum PendingStatus {
        case pending
        case confirmed
        case failed
    }
}

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
    
    var digits: Int {
        return self.rawValue
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
    
    // Game state tracking
    @Published var hasSetSecret: Bool = false
    @Published var isWaitingForResponse: Bool = false
    @Published var mySecret: String = "" // Store player's own secret for display
    
    // Optimistic updates
    @Published var pendingGuesses: [PendingGuess] = []
    @Published var isOffline: Bool = false
    @Published var lastServerSync: Date?
    
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
        hasSetSecret = false
        isWaitingForResponse = false
        mySecret = ""
        gameState = .mainMenu
    }
    
    func setMySecret(_ secret: String) {
        mySecret = secret
        hasSetSecret = true
        print("🔐 My secret stored: \(secret)")
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
            return isInputValid() && !hasSetSecret
        case .activeGame:
            return isInputValid() && isPlayerTurn()
        default:
            return false
        }
    }
    
    func setWaitingForResponse(_ waiting: Bool) {
        isWaitingForResponse = waiting
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
    
    // MARK: - Optimistic Updates
    
    func addPendingGuess(_ guess: String, target: String) {
        let pending = PendingGuess(
            id: UUID(),
            guess: guess,
            target: target,
            timestamp: Date(),
            status: .pending
        )
        pendingGuesses.append(pending)
        
        // Add optimistic history entry
        let historyEntry = "🎯 \(playerName) → \(target): \(guess) = ? hits (pending...)"
        gameHistory.append(historyEntry)
        
        print("📤 Added pending guess: \(guess) → \(target)")
    }
    
    func confirmGuess(_ guess: String, hits: Int, target: String) {
        // Find and update pending guess
        if let index = pendingGuesses.firstIndex(where: { $0.guess == guess && $0.status == .pending }) {
            pendingGuesses[index].status = .confirmed
            pendingGuesses[index].hits = hits
            
            // Update history entry
            if let historyIndex = gameHistory.lastIndex(where: { $0.contains(guess) && $0.contains("pending") }) {
                gameHistory[historyIndex] = "🎯 \(playerName) → \(target): \(guess) = \(hits) hits"
            }
            
            print("✅ Confirmed guess: \(guess) = \(hits) hits")
        }
        
        // Clean up old confirmed guesses
        cleanupOldGuesses()
    }
    
    func rollbackGuess(_ guess: String) {
        // Find and remove failed guess
        if let index = pendingGuesses.firstIndex(where: { $0.guess == guess && $0.status == .pending }) {
            pendingGuesses.remove(at: index)
            
            // Remove history entry
            if let historyIndex = gameHistory.lastIndex(where: { $0.contains(guess) && $0.contains("pending") }) {
                gameHistory.remove(at: historyIndex)
            }
            
            print("❌ Rolled back guess: \(guess)")
        }
    }
    
    func markOffline() {
        isOffline = true
        print("📶 App marked as offline")
    }
    
    func markOnline() {
        if isOffline {
            isOffline = false
            lastServerSync = Date()
            print("📶 App back online, syncing...")
            
            // Trigger sync of pending actions
            syncPendingActions()
        }
    }
    
    private func cleanupOldGuesses() {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        pendingGuesses.removeAll { $0.status == .confirmed && $0.timestamp < fiveMinutesAgo }
    }
    
    private func syncPendingActions() {
        // In a real implementation, this would retry failed actions
        // For now, just clean up failed guesses
        let failedGuesses = pendingGuesses.filter { $0.status == .failed }
        for failed in failedGuesses {
            rollbackGuess(failed.guess)
        }
    }
    
    // MARK: - Game History Storage
    func saveGameHistory(roomCode: String, gameMode: GameMode, result: String, duration: TimeInterval) {
        let gameRecord = [
            "roomCode": roomCode,
            "gameMode": gameMode.displayName,
            "digits": gameMode.rawValue,
            "result": result,
            "duration": duration,
            "date": Date().timeIntervalSince1970,
            "playerName": playerName
        ] as [String : Any]
        
        var savedGames = UserDefaults.standard.array(forKey: "GameHistory") as? [[String: Any]] ?? []
        savedGames.append(gameRecord)
        
        // Keep only last 100 games
        if savedGames.count > 100 {
            savedGames = Array(savedGames.suffix(100))
        }
        
        UserDefaults.standard.set(savedGames, forKey: "GameHistory")
        print("📝 Game history saved: \(gameRecord)")
    }
    
    func getGameHistory() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: "GameHistory") as? [[String: Any]] ?? []
    }
    
    func clearGameHistory() {
        UserDefaults.standard.removeObject(forKey: "GameHistory")
        print("🗑️ Game history cleared")
    }
}

// MARK: - GameClient Integration
extension GameStateManager {
    func handleRoomState(_ state: RoomState) {
        let oldGameState = gameState
        let oldPlayersCount = players.count
        
        players = state.players
        
        // Update current turn from server
        if let serverCurrentTurn = state.game.currentTurn, !serverCurrentTurn.isEmpty {
            currentPlayerTurn = serverCurrentTurn
            print("🎮 Updated current turn to: \(currentPlayerTurn)")
        }
        
        // Update game history with current game state and recent moves
        if let recentMoves = state.recentMoves {
            // Add game state header if not exists
            let stateHeader = "🎮 Game State: \(state.game.state.uppercased()) | Room: \(state.game.code)"
            if gameHistory.isEmpty || !gameHistory[0].contains("Game State:") {
                gameHistory.insert(stateHeader, at: 0)
            } else {
                gameHistory[0] = stateHeader
            }
            
            // Add player status summary
            let playersReady = players.filter { $0.isReady }.count
            let totalPlayers = players.count
            let statusSummary = "👥 Players Ready: \(playersReady)/\(totalPlayers)"
            
            if gameHistory.count > 1 && gameHistory[1].contains("Players Ready:") {
                gameHistory[1] = statusSummary
            } else {
                gameHistory.insert(statusSummary, at: 1)
            }
            
            // Add separator
            let separator = "--- Recent Moves ---"
            if gameHistory.count > 2 && !gameHistory[2].contains("Recent Moves") {
                gameHistory.insert(separator, at: 2)
            }
            
            // Add recent moves (skip first 3 entries which are headers)
            let moveStartIndex = 3
            
            // Remove old moves while keeping headers
            if gameHistory.count > moveStartIndex {
                gameHistory.removeSubrange(moveStartIndex...)
            }
            
            // Add new moves
            for move in recentMoves {
                let historyEntry = "🎯 \(move.player) → \(move.target): \(move.hits) hits"
                gameHistory.append(historyEntry)
            }
        }
        
        // Manually trigger delegate (in case @Published didSet doesn't work)
        delegate?.playersDidUpdate(players)
        
        // Only log significant changes
        if oldGameState != gameState || oldPlayersCount != players.count {
            print("🎮 State: \(oldGameState) -> \(gameState), Players: \(oldPlayersCount) -> \(players.count)")
        }
        
        switch state.game.state {
        case "waiting":
            let currentPlayer = players.first(where: { $0.name == playerName })
            let readyCount = players.filter { $0.isReady }.count
            let totalCount = players.count
            
            // Update hasSetSecret based on server state
            if let currentPlayer = currentPlayer {
                let previouslySetSecret = hasSetSecret
                hasSetSecret = currentPlayer.isReady
                
                // Log state changes for debugging
                if previouslySetSecret != hasSetSecret {
                    print("🔄 Secret state changed: \(previouslySetSecret) -> \(hasSetSecret) for \(playerName)")
                }
                
                // Add history entry when secret is confirmed by server
                if !previouslySetSecret && hasSetSecret {
                    let secretConfirmMsg = "✅ \(playerName) secret confirmed by server"
                    if !gameHistory.contains(secretConfirmMsg) {
                        gameHistory.append(secretConfirmMsg)
                    }
                }
            }
            
            if totalCount < 2 {
                gameState = .waitingForPlayers
                print("🎮 Not enough players (\(totalCount)/2)")
            } else if currentPlayer?.isReady == false {
                gameState = .settingSecret
                print("🎮 Player needs to set secret")
            } else if readyCount < totalCount {
                gameState = .waitingForGame
                print("🎮 Waiting for other players to set secrets (\(readyCount)/\(totalCount))")
            } else {
                // All players ready - should transition to active soon
                gameState = .waitingForGame
                print("🎮 All players ready, waiting for game to start")
            }
        case "active":
            if gameState != .activeGame {
                startNewGame()
                print("🎮 Game started!")
                
                // Randomize first player if not set
                if currentPlayerTurn.isEmpty && !players.isEmpty {
                    let randomPlayer = players.randomElement()
                    currentPlayerTurn = randomPlayer?.name ?? ""
                    print("🎲 Random first player: \(currentPlayerTurn)")
                }
            }
        case "finished":
            gameState = .gameFinished
            hasSetSecret = false  // Reset for next game
            print("🎮 Game finished")
        default:
            gameState = .waitingForPlayers
            print("🎮 Unknown state: \(state.game.state)")
        }
    }
    
    func handleMoveResult(_ result: MoveResult) {
        // If this was our guess, confirm the optimistic update
        if result.from == playerName {
            confirmGuess(result.guess, hits: result.hit, target: result.to)
        } else {
            // Otherwise, add normally to history
            let historyEntry = "🎯 \(result.from) → \(result.to): \(result.guess) = \(result.hit) hits"
            addToHistory(historyEntry)
        }
        
        updateCurrentTurn(lastPlayer: result.from)
        lastServerSync = Date()
    }
    
    func handleGameEnd(winner: String, secret: String) {
        gameState = .gameFinished
        let winMessage = "🏆 Winner: \(winner) (Secret: \(secret))"
        addToHistory(winMessage)
        
        // Save game history
        if let startTime = gameStartTime {
            let duration = Date().timeIntervalSince(startTime)
            let result = winner == playerName ? "Won" : "Lost"
            saveGameHistory(roomCode: currentRoomCode, gameMode: selectedGameMode, result: result, duration: duration)
        }
    }
}