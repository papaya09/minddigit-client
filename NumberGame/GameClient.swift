import Foundation
import UIKit

protocol GameClientDelegate: AnyObject {
    func gameClient(_ client: GameClient, didReceiveRoomState state: RoomState)
    func gameClient(_ client: GameClient, didReceiveError error: String)
    func gameClient(_ client: GameClient, gameDidStart: Bool)
    func gameClient(_ client: GameClient, didReceiveMoveResult result: MoveResult)
    func gameClient(_ client: GameClient, gameDidEnd winner: String, secret: String)
}

struct RoomState: Codable {
    struct Game: Codable {
        let code: String
        let state: String
        let digits: Int
        let winner: String?
        let currentTurn: String?
        let turnTimeRemaining: Int?
        let currentRound: Int?
        let maxRounds: Int?
    }
    
    struct Player: Codable {
        let name: String
        let avatar: String
        let isReady: Bool
        let isConnected: Bool?
        let isAlive: Bool?
        let turnOrder: Int?
        let stats: PlayerStats?
    }
    
    struct PlayerStats: Codable {
        let guessesMade: Int
        let correctGuesses: Int
        let gamesWon: Int
    }
    
    struct RecentMove: Codable {
        let player: String
        let target: String
        let hits: Int
        let timestamp: String
        let turnNumber: Int?
    }
    
    let game: Game
    let players: [Player]
    let turnOrder: [String]?
    let recentMoves: [RecentMove]?
    let nextPollIn: Int?
    let lastModified: String?
}

struct MoveResult: Codable {
    let from: String
    let to: String
    let guess: String
    let hit: Int
}


class GameClient {
    weak var delegate: GameClientDelegate?
    
    private let baseURL = "https://minddigit-server.vercel.app"
    private var currentRoomCode: String?
    private var currentPlayer: RoomState.Player?
    private var sessionId: String
    
    // Retry logic
    private var retryCount: Int = 0
    private let maxRetries: Int = 3
    private var isRetrying: Bool = false
    
    // Polling properties
    private var pollingTimer: Timer?
    private var pollInterval: TimeInterval = 5.0
    
    // Caching properties
    private var lastModified: String?
    private var etag: String?
    
    // Public getter/setter for currentRoomCode
    var roomCode: String? {
        get { return currentRoomCode }
        set { currentRoomCode = newValue }
    }
    
    // Public getter/setter for currentPlayer
    var player: RoomState.Player? {
        get { return currentPlayer }
        set { currentPlayer = newValue }
    }
    
    init() {
        self.sessionId = UUID().uuidString
        print("🔗 GameClient initialized with smart polling for: \(baseURL)")
        print("📱 Session ID: \(sessionId)")
        
        // Setup app lifecycle notifications
        setupAppLifecycleObservers()
    }
    
    deinit {
        removeAppLifecycleObservers()
    }
    
    // MARK: - Connection Management
    
    func connect() {
        print("🔗 Starting HTTP connection...")
        // isConnected = true // This property was removed
        testConnection()
    }
    
    func disconnect() {
        print("⚠️ Disconnecting...")
        currentRoomCode = nil
        // Clear cache
        lastModified = nil
        etag = nil
    }
    
    private func testConnection() {
        guard let url = URL(string: "\(baseURL)/api/health") else { return }
        
        let session = URLSession.shared
        session.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Connection test failed: \(error.localizedDescription)")
                    self?.delegate?.gameClient(self!, didReceiveError: "Connection failed: \(error.localizedDescription)")
                } else {
                    print("✅ Connected to server")
                }
            }
        }.resume()
    }
    
    // MARK: - Room Management
    
    
    
    
    // MARK: - Game Actions
    
    func setSecret(_ secret: String) {
        guard let roomCode = currentRoomCode,
              let player = currentPlayer else { 
            print("❌ Missing room code or player for setSecret")
            return 
        }
        
        print("🔐 Setting secret for player \(player.name) in room \(roomCode)")
        
        // Pause polling while setting secret
        pausePollingForResponse()
        
        let requestBody = [
            "roomCode": roomCode,
            "secret": secret,
            "playerName": player.name
        ]
        
        makeHTTPRequest(
            endpoint: "/api/rooms/secret",
            method: "POST",
            body: requestBody
        ) { [weak self] (result: Result<GenericResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Secret set successfully: \(response.message)")
                    // Immediately get updated room state
                    self?.getRoomStateOnce()
                case .failure(let error):
                    print("❌ Failed to set secret: \(error)")
                    let errorMessage = self?.getErrorMessage(from: error) ?? "Failed to set secret"
                    self?.delegate?.gameClient(self!, didReceiveError: errorMessage)
                }
            }
        }
    }
    
    // New immediate version without delays
    func setSecretImmediate(_ secret: String) {
        guard let roomCode = currentRoomCode,
              let player = currentPlayer else { 
            print("❌ Missing room code or player for setSecret")
            return 
        }
        
        print("🚀 API CALL: Setting secret \(secret) for \(player.name) in room \(roomCode)")
        
        let requestBody = [
            "roomCode": roomCode,
            "secret": secret,
            "playerName": player.name
        ]
        
        makeHTTPRequest(
            endpoint: "/api/rooms/secret",
            method: "POST",
            body: requestBody
        ) { [weak self] (result: Result<GenericResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Secret API success: \(response.message)")
                    self?.getRoomStateOnce()
                case .failure(let error):
                    print("❌ Secret API failed: \(error)")
                    let errorMessage = self?.getErrorMessage(from: error) ?? "Failed to set secret"
                    self?.delegate?.gameClient(self!, didReceiveError: errorMessage)
                }
            }
        }
    }
    
    func makeGuess(_ guess: String, targetPlayer: String? = nil) {
        guard let roomCode = currentRoomCode,
              let player = currentPlayer else { return }
        
        print("🎯 Making guess: \(guess) by \(player.name) targeting \(targetPlayer ?? "auto")")
        
        // Pause polling while making guess to wait for response
        pausePollingForResponse()
        
        var requestBody: [String: String] = [
            "roomCode": roomCode,
            "guess": guess,
            "playerName": player.name
        ]
        
        if let targetPlayer = targetPlayer {
            requestBody["targetPlayer"] = targetPlayer
        }
        
        makeHTTPRequest(
            endpoint: "/api/rooms/guess",
            method: "POST",
            body: requestBody
        ) { [weak self] (result: Result<GuessResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let moveResult = MoveResult(
                        from: player.name,
                        to: response.targetPlayer ?? "opponent",
                        guess: guess,
                        hit: response.hits
                    )
                    self?.delegate?.gameClient(self!, didReceiveMoveResult: moveResult)
                    
                    // Check for game win
                    if response.isWinning == true {
                        print("🎉 Winning guess! You won the game!")
                        self?.delegate?.gameClient(self!, gameDidEnd: player.name, secret: "")
                    }
                    
                    // Get updated room state after guess
                    self?.getRoomStateOnce()
                    
                case .failure(let error):
                    print("❌ Failed to make guess: \(error)")
                    self?.delegate?.gameClient(self!, didReceiveError: "Failed to make guess: \(error.localizedDescription)")
                    // Resume polling even on error
                    self?.resumePollingAfterResponse()
                }
            }
        }
    }
    
    // New immediate version without delays
    func makeGuessImmediate(_ guess: String, targetPlayer: String) {
        guard let roomCode = currentRoomCode,
              let player = currentPlayer else { return }
        
        print("🚀 API CALL: Making guess \(guess) from \(player.name) to \(targetPlayer) in room \(roomCode)")
        
        let requestBody = [
            "roomCode": roomCode,
            "guess": guess,
            "playerName": player.name,
            "targetPlayer": targetPlayer
        ]
        
        makeHTTPRequest(
            endpoint: "/api/rooms/guess",
            method: "POST",
            body: requestBody
        ) { [weak self] (result: Result<GuessResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Guess API success: \(response.hits) hits")
                    let moveResult = MoveResult(
                        from: player.name,
                        to: response.targetPlayer ?? targetPlayer,
                        guess: guess,
                        hit: response.hits
                    )
                    self?.delegate?.gameClient(self!, didReceiveMoveResult: moveResult)
                    
                    if response.isWinning == true {
                        self?.delegate?.gameClient(self!, gameDidEnd: player.name, secret: "")
                    }
                    
                    self?.getRoomStateOnce()
                    
                case .failure(let error):
                    print("❌ Guess API failed: \(error)")
                    let errorMessage = self?.getErrorMessage(from: error) ?? "Failed to make guess"
                    self?.delegate?.gameClient(self!, didReceiveError: errorMessage)
                }
            }
        }
    }
    
    // MARK: - Room State Management
    
    func startRoomPolling() {
        print("🔄 Getting initial room state")
        getRoomStateOnce()
    }
    
    func stopRoomPolling() {
        print("⏹️ No longer polling")
        // No polling to stop
    }
    
    func pollOnce() {
        print("🔍 One-time room state poll")
        getRoomStateOnce()
    }
    
    // Get room state once without polling
    func getRoomStateOnce() {
        guard let roomCode = currentRoomCode else { return }
        
        print("🔍 Getting room state once for: \(roomCode)")
        
        makeHTTPRequest(
            endpoint: "/api/rooms/\(roomCode)/gameplay",
            method: "GET",
            body: nil as String?
        ) { [weak self] (result: Result<RoomState, Error>) in
            switch result {
            case .success(let state):
                print("✅ Room state received: \(state.game.state), players: \(state.players.count)")
                DispatchQueue.main.async {
                    self?.delegate?.gameClient(self!, didReceiveRoomState: state)
                }
            case .failure(let error):
                print("❌ Failed to get room state: \(error)")
            }
        }
    }
    
    func deleteRoom(roomCode: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("🗑️ Deleting room: \(roomCode)")
        
        makeHTTPRequest(
            endpoint: "/api/rooms/\(roomCode)",
            method: "DELETE",
            body: nil as String?
        ) { (result: Result<GenericResponse, Error>) in
            switch result {
            case .success(let response):
                print("✅ Room deleted: \(response.message)")
                completion(.success(response.message))
            case .failure(let error):
                print("❌ Failed to delete room: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    func deleteAllRooms(completion: @escaping (Result<String, Error>) -> Void) {
        print("🗑️ Deleting all rooms")
        
        makeHTTPRequest(
            endpoint: "/api/rooms",
            method: "DELETE",
            body: nil as String?
        ) { (result: Result<DeleteAllRoomsResponse, Error>) in
            switch result {
            case .success(let response):
                print("✅ All rooms deleted: \(response.message)")
                completion(.success(response.message))
            case .failure(let error):
                print("❌ Failed to delete all rooms: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    func startGame() {
        guard let roomCode = currentRoomCode,
              let player = currentPlayer else { 
            print("❌ Missing room code or player for startGame")
            return 
        }
        
        print("🎮 Starting game for room \(roomCode)")
        
        // Pause polling while starting game
        pausePollingForResponse()
        
        let requestBody = [
            "roomCode": roomCode,
            "playerName": player.name
        ]
        
        makeHTTPRequest(
            endpoint: "/api/rooms/start",
            method: "POST",
            body: requestBody
        ) { [weak self] (result: Result<GenericResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Game started: \(response.message)")
                    // Get updated room state after starting game
                    self?.getRoomStateOnce()
                case .failure(let error):
                    print("❌ Failed to start game: \(error)")
                    let errorMessage = self?.getErrorMessage(from: error) ?? "Failed to start game"
                    self?.delegate?.gameClient(self!, didReceiveError: errorMessage)
                    // Resume polling even on error
                    self?.resumePollingAfterResponse()
                }
            }
        }
    }
    
    // New immediate version without delays
    func startGameImmediate() {
        guard let roomCode = currentRoomCode,
              let player = currentPlayer else { 
            print("❌ Missing room code or player for startGame")
            return 
        }
        
        print("🚀 API CALL: Starting game for \(player.name) in room \(roomCode)")
        
        let requestBody = [
            "roomCode": roomCode,
            "playerName": player.name
        ]
        
        makeHTTPRequest(
            endpoint: "/api/rooms/start",
            method: "POST",
            body: requestBody
        ) { [weak self] (result: Result<GenericResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    print("✅ Start game API success: \(response.message)")
                    self?.getRoomStateOnce()
                case .failure(let error):
                    print("❌ Start game API failed: \(error)")
                    let errorMessage = self?.getErrorMessage(from: error) ?? "Failed to start game"
                    self?.delegate?.gameClient(self!, didReceiveError: errorMessage)
                }
            }
        }
    }
    
    func skipTurn() {
        guard let roomCode = currentRoomCode,
              let player = currentPlayer else { 
            print("❌ Missing room code or player for skipTurn")
            return 
        }
        
        print("⏭️ Skipping turn for player \(player.name) in room \(roomCode)")
        
        let requestBody = [
            "playerName": player.name,
            "reason": "voluntary"
        ]
        
        makeHTTPRequest(
            endpoint: "/api/rooms/\(roomCode)/skip-turn",
            method: "POST",
            body: requestBody
        ) { [weak self] (result: Result<SkipTurnResponse, Error>) in
            switch result {
            case .success(let response):
                print("✅ Turn skipped: \(response.message)")
                // Force a polling update to get latest game state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.pollRoomState()
                }
            case .failure(let error):
                print("❌ Failed to skip turn: \(error)")
                let errorMessage = self?.getErrorMessage(from: error) ?? "Failed to skip turn"
                DispatchQueue.main.async {
                    self?.delegate?.gameClient(self!, didReceiveError: errorMessage)
                }
            }
        }
    }
    
    // MARK: - Connection Management (Simplified)
    // No heartbeat needed - using direct API calls
    
    private func startHeartbeat() {
        // Placeholder for heartbeat functionality if needed
    }
    
    private func stopHeartbeat() {
        // Placeholder for heartbeat functionality if needed
    }
    
    // MARK: - Smart Polling for Real-time Updates
    
    private func startPolling() {
        stopPolling() // Stop any existing polling
        
        print("🔄 Setting up smart polling timer (every \(pollInterval) seconds)")
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.pollRoomState()
        }
        
        // Initial poll
        pollRoomState()
    }
    
    // MARK: - Response-based State Updates
    
    func pausePollingForResponse() {
        print("⏸️ Waiting for response")
        // No polling to pause
    }
    
    func resumePollingAfterResponse() {
        guard currentRoomCode != nil else { return }
        print("▶️ Getting updated state after response")
        getRoomStateOnce()
    }
    
    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        print("⏹️ Polling stopped")
    }
    
    private func pollRoomState() {
        guard let roomCode = currentRoomCode else { return }
        
        // Reduce logging noise
        if pollInterval <= 10 {
            print("🔍 Polling \(roomCode)")
        }
        
        makeHTTPRequestWithCaching(
            endpoint: "/api/rooms/\(roomCode)/gameplay",
            method: "GET",
            body: nil as String?
        ) { [weak self] (result: Result<RoomState, Error>) in
            switch result {
            case .success(let state):
                print("✅ Room state received: \(state.game.state), players: \(state.players.count)")
                
                // Update cache from response
                if let lastModified = state.lastModified {
                    self?.lastModified = lastModified
                }
                
                // Adjust polling interval based on game state
                self?.adjustPollingInterval(gameState: state.game.state)
                
                DispatchQueue.main.async {
                    self?.delegate?.gameClient(self!, didReceiveRoomState: state)
                }
                
                // Check for game state changes
                if state.game.state == "active" {
                    print("🎮 Game is now active!")
                    DispatchQueue.main.async {
                        self?.delegate?.gameClient(self!, gameDidStart: true)
                    }
                } else if state.game.state == "finished", let winner = state.game.winner {
                    print("🏆 Game finished! Winner: \(winner)")
                    DispatchQueue.main.async {
                        self?.delegate?.gameClient(self!, gameDidEnd: winner, secret: "")
                    }
                }
            case .failure(let error):
                // Handle 304 Not Modified as success (no changes)
                if let networkError = error as? NetworkError,
                   case .httpError(304) = networkError {
                    print("📄 No changes (304 Not Modified)")
                    return
                }
                
                print("❌ Polling failed: \(error)")
                
                // Handle offline detection
                self?.handleNetworkError(error)
            }
        }
    }
    
    // Dynamic polling intervals based on game state  
    private func adjustPollingInterval(gameState: String) {
        let newInterval: TimeInterval
        
        switch gameState {
        case "active":
            newInterval = 15.0     // Much longer for active games - use events instead
        case "waiting":
            newInterval = 20.0     // Less frequent during setup
        case "finished":
            newInterval = 30.0     // Minimal polling when finished
        default:
            newInterval = 20.0     // Default reduced
        }
        
        if newInterval != pollInterval {
            pollInterval = newInterval
            print("🔄 Polling interval: \(pollInterval)s for \(gameState)")
            
            // Restart polling with new interval
            if pollingTimer != nil {
                startPolling()
            }
        }
    }
    
    // MARK: - Offline Handling & Retry Logic
    
    private func handleNetworkError(_ error: Error) {
        let isOfflineError = isNetworkOfflineError(error)
        
        if isOfflineError && !isRetrying {
            print("📵 Network appears to be offline")
            
            // Notify GameStateManager about offline status
            DispatchQueue.main.async {
                // Assuming we have access to GameStateManager
                // GameStateManager.shared.markOffline()
            }
            
            // Start retry logic
            startRetrySequence()
        }
    }
    
    private func isNetworkOfflineError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    private func startRetrySequence() {
        guard !isRetrying else { return }
        
        isRetrying = true
        retryCount = 0
        
        print("🔄 Starting network retry sequence")
        retryConnection()
    }
    
    private func retryConnection() {
        guard retryCount < maxRetries else {
            print("❌ Max retries reached, giving up")
            isRetrying = false
            return
        }
        
        retryCount += 1
        let delay = TimeInterval(retryCount * 2) // Exponential backoff: 2s, 4s, 6s
        
        print("🔄 Retry attempt \(retryCount)/\(maxRetries) in \(delay)s")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.testConnectionForRetry()
        }
    }
    
    private func testConnectionForRetry() {
        guard let url = URL(string: "\(baseURL)/api/health") else {
            retryConnection()
            return
        }
        
        let session = URLSession.shared
        session.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Retry failed: \(error.localizedDescription)")
                    self?.retryConnection()
                } else {
                    print("✅ Connection restored!")
                    self?.handleConnectionRestored()
                }
            }
        }.resume()
    }
    
    private func handleConnectionRestored() {
        isRetrying = false
        retryCount = 0
        
        // Notify GameStateManager about online status
        DispatchQueue.main.async {
            // GameStateManager.shared.markOnline()
        }
        
        // Resume normal polling
        if currentRoomCode != nil {
            pollRoomState() // Force immediate poll
        }
        
        print("🌐 Network connection restored, resuming normal operation")
    }
    
    // MARK: - App Lifecycle Handling
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    private func removeAppLifecycleObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidEnterBackground() {
        print("📱 App entered background - reducing polling frequency")
        
        // Reduce polling frequency to save battery
        if pollingTimer != nil {
            pollInterval = 10.0 // Poll every 10 seconds in background
            startPolling()
        }
        
        // Stop heartbeat to save battery
        stopHeartbeat()
    }
    
    @objc private func appWillEnterForeground() {
        print("📱 App entering foreground - resuming normal operation")
        
        // Resume normal polling frequency
        if let roomCode = currentRoomCode {
            pollInterval = 2.0 // Back to normal frequency
            startPolling()
            startHeartbeat()
            
            // Force immediate state refresh
            pollRoomState()
        }
    }
    
    // MARK: - HTTP Request Helpers
    
    // HTTP Request with caching support
    private func makeHTTPRequestWithCaching<T: Codable, Body: Codable>(
        endpoint: String,
        method: String,
        body: Body?,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add cache headers for conditional requests
        if let lastModified = lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }
        if let etag = etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        let session = URLSession.shared
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP Status: \(httpResponse.statusCode)")
                    
                    // Handle 304 Not Modified
                    if httpResponse.statusCode == 304 {
                        completion(.failure(NetworkError.httpError(304)))
                        return
                    }
                    
                    // Update cache headers
                    if let lastModified = httpResponse.allHeaderFields["Last-Modified"] as? String {
                        self?.lastModified = lastModified
                    }
                    if let etag = httpResponse.allHeaderFields["ETag"] as? String {
                        self?.etag = etag
                    }
                    
                    if httpResponse.statusCode >= 400 {
                        // Try to parse error JSON
                        if let data = data,
                           let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                            completion(.failure(NetworkError.serverError(errorData.message)))
                        } else {
                            completion(.failure(NetworkError.httpError(httpResponse.statusCode)))
                        }
                        return
                    }
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(result))
                } catch {
                    print("❌ JSON decode error: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Response that failed to decode: \(responseString)")
                    }
                    completion(.failure(NetworkError.jsonDecodeError(error)))
                }
            }
        }.resume()
    }
    
    private func makeHTTPRequest<T: Codable, Body: Codable>(
        endpoint: String,
        method: String,
        body: Body?,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        let session = URLSession.shared
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NetworkError.noData))
                    return
                }
                
                // Check if response is valid JSON
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📡 Server response: \(responseString)")
                    
                    // Check for HTML error pages
                    if responseString.hasPrefix("<!DOCTYPE") || responseString.hasPrefix("<html") {
                        completion(.failure(NetworkError.htmlResponse(responseString)))
                        return
                    }
                }
                
                // Check HTTP status code
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP Status: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode >= 400 {
                        // Try to parse error JSON
                        if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                            completion(.failure(NetworkError.serverError(errorData.message)))
                        } else {
                            completion(.failure(NetworkError.httpError(httpResponse.statusCode)))
                        }
                        return
                    }
                }
                
                do {
                    let result = try JSONDecoder().decode(T.self, from: data)
                    completion(.success(result))
                } catch {
                    print("❌ JSON decode error: \(error)")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Response that failed to decode: \(responseString)")
                    }
                    completion(.failure(NetworkError.jsonDecodeError(error)))
                }
            }
        }.resume()
    }
}

// MARK: - Request Models


// MARK: - Response Models


struct GuessResponse: Codable {
    let hits: Int
    let isWinning: Bool?
    let targetPlayer: String?
    let message: String
}

struct GenericResponse: Codable {
    let message: String
}

struct DeleteAllRoomsResponse: Codable {
    let message: String
    let deletedCount: Int
}

struct SkipTurnResponse: Codable {
    let message: String
    let nextPlayer: String?
    let currentRound: Int?
    let reason: String?
}

// MARK: - Error Types

enum NetworkError: Error {
    case invalidURL
    case noData
    case htmlResponse(String)
    case httpError(Int)
    case serverError(String)
    case jsonDecodeError(Error)
}

struct ErrorResponse: Codable {
    let message: String
}

// MARK: - Error Helper Extension

extension GameClient {
    private func getErrorMessage(from error: Error) -> String {
        switch error {
        case NetworkError.htmlResponse(let html):
            if html.contains("This page does not exist") || html.contains("404") {
                return "API endpoint not found. Please check server deployment."
            } else if html.contains("500") || html.contains("Internal Server Error") {
                return "Server error. Please try again later."
            } else {
                return "Server returned HTML instead of JSON. Check server configuration."
            }
        case NetworkError.httpError(let code):
            if code == 503 {
                return "Database not configured. Please contact app developer."
            }
            return "HTTP Error \(code). Server may be down."
        case NetworkError.serverError(let message):
            return message
        case NetworkError.jsonDecodeError(_):
            return "Invalid response format from server."
        case NetworkError.noData:
            return "No data received from server."
        case NetworkError.invalidURL:
            return "Invalid server URL."
        default:
            return error.localizedDescription
        }
    }
}