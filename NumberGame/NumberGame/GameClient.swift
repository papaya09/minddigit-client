import Foundation
import SocketIO

protocol GameClientDelegate: AnyObject {
    func gameClient(_ client: GameClient, didReceiveRoomState state: RoomState)
    func gameClient(_ client: GameClient, didReceiveError error: String)
    func gameClient(_ client: GameClient, gameDidStart: Bool)
    func gameClient(_ client: GameClient, didReceiveMoveResult result: MoveResult)
    func gameClient(_ client: GameClient, gameDidEnd winner: String, secret: String)
    func gameClient(_ client: GameClient, didReceiveRoomList rooms: [AvailableRoom])
}

struct RoomState: Codable {
    struct Game: Codable {
        let code: String
        let state: String
        let digits: Int
    }
    
    struct Player: Codable {
        let name: String
        let avatar: String
        let isReady: Bool
    }
    
    let game: Game
    let players: [Player]
}

struct MoveResult: Codable {
    let from: String
    let to: String
    let guess: String
    let hit: Int
}

struct AvailableRoom: Codable {
    let code: String
    let hostName: String
    let hostAvatar: String
    let gameMode: String
    let playerCount: Int
    let maxPlayers: Int
    let isGameStarted: Bool
}

class GameClient {
    weak var delegate: GameClientDelegate?
    private var manager: SocketManager!
    private var socket: SocketIOClient!
    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
    init(serverURL: String = "https://minddigit-server.vercel.app") {
        // Improved Socket.IO configuration for Vercel deployment
        manager = SocketManager(socketURL: URL(string: serverURL)!, config: [
            .log(false), // Disable detailed logging for production
            .forcePolling(false), // Allow WebSocket upgrade
            .forceWebsockets(false), // Allow fallback to polling
            .reconnects(true),
            .reconnectAttempts(5),
            .reconnectWait(2),
            .randomizationFactor(0.5),
            .connectParams(["transport": "polling"])
        ])
        socket = manager.defaultSocket
        setupEventHandlers()
    }
    
    private func setupEventHandlers() {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            print("✅ Connected to server")
            self?.isConnected = true
            self?.reconnectAttempts = 0
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            print("⚠️ Disconnected from server")
            self?.isConnected = false
        }
        
        socket.on(clientEvent: .error) { [weak self] data, _ in
            print("❌ Socket error: \(data)")
            self?.isConnected = false
        }
        
        socket.on(clientEvent: .reconnect) { [weak self] data, _ in
            print("🔄 Reconnected to server")
            self?.isConnected = true
            self?.reconnectAttempts = 0
        }
        
        socket.on(clientEvent: .reconnectAttempt) { [weak self] data, _ in
            guard let self = self else { return }
            self.reconnectAttempts += 1
            print("🔄 Reconnect attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts)")
            
            if self.reconnectAttempts >= self.maxReconnectAttempts {
                print("❌ Max reconnect attempts reached")
                DispatchQueue.main.async {
                    self.delegate?.gameClient(self, didReceiveError: "Connection lost. Please check your internet and try again.")
                }
            }
        }
        
        socket.on("roomState") { [weak self] data, _ in
            guard let self = self,
                  let jsonData = try? JSONSerialization.data(withJSONObject: data[0]),
                  let roomState = try? JSONDecoder().decode(RoomState.self, from: jsonData) else {
                return
            }
            
            DispatchQueue.main.async {
                self.delegate?.gameClient(self, didReceiveRoomState: roomState)
            }
        }
        
        socket.on("error") { [weak self] data, _ in
            guard let self = self,
                  let errorDict = data[0] as? [String: Any],
                  let message = errorDict["message"] as? String else {
                return
            }
            
            DispatchQueue.main.async {
                self.delegate?.gameClient(self, didReceiveError: message)
            }
        }
        
        socket.on("gameStart") { [weak self] data, _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.delegate?.gameClient(self, gameDidStart: true)
            }
        }
        
        socket.on("moveResult") { [weak self] data, _ in
            guard let self = self,
                  let jsonData = try? JSONSerialization.data(withJSONObject: data[0]),
                  let moveResult = try? JSONDecoder().decode(MoveResult.self, from: jsonData) else {
                return
            }
            
            DispatchQueue.main.async {
                self.delegate?.gameClient(self, didReceiveMoveResult: moveResult)
            }
        }
        
        socket.on("gameEnd") { [weak self] data, _ in
            guard let self = self,
                  let gameEndDict = data[0] as? [String: Any],
                  let winner = gameEndDict["winner"] as? String,
                  let secret = gameEndDict["secret"] as? String else {
                return
            }
            
            DispatchQueue.main.async {
                self.delegate?.gameClient(self, gameDidEnd: winner, secret: secret)
            }
        }
        
        socket.on("roomList") { [weak self] data, _ in
            guard let self = self,
                  let jsonData = try? JSONSerialization.data(withJSONObject: data[0]),
                  let roomList = try? JSONDecoder().decode([AvailableRoom].self, from: jsonData) else {
                return
            }
            
            DispatchQueue.main.async {
                self.delegate?.gameClient(self, didReceiveRoomList: roomList)
            }
        }
    }
    
    func connect() {
        socket.connect()
    }
    
    func disconnect() {
        socket.disconnect()
    }
    
    func joinRoom(code: String, playerName: String, avatar: String = "🎯") {
        guard isConnected else {
            delegate?.gameClient(self, didReceiveError: "Not connected to server. Please try again.")
            return
        }
        socket.emit("joinRoom", ["code": code, "playerName": playerName, "avatar": avatar])
    }
    
    func setSecret(_ secret: String, for roomCode: String) {
        guard isConnected else {
            delegate?.gameClient(self, didReceiveError: "Not connected to server. Please try again.")
            return
        }
        socket.emit("setSecret", ["code": roomCode, "secret": secret])
    }
    
    func makeGuess(_ guess: String, targetPlayer: String, roomCode: String) {
        guard isConnected else {
            delegate?.gameClient(self, didReceiveError: "Not connected to server. Please try again.")
            return
        }
        socket.emit("makeGuess", ["code": roomCode, "targetPlayer": targetPlayer, "guess": guess])
    }
    
    func requestAvailableRooms() {
        guard isConnected else {
            delegate?.gameClient(self, didReceiveError: "Not connected to server. Please try again.")
            return
        }
        socket.emit("getRoomList")
    }
    
    // Create new room via API
    func createRoom(digits: Int, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://minddigit-server.vercel.app/api/rooms") else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["digits": digits]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool,
                   success,
                   let gameData = json["game"] as? [String: Any],
                   let roomCode = gameData["code"] as? String {
                    
                    DispatchQueue.main.async {
                        completion(.success(roomCode))
                    }
                } else {
                    let errorMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "Failed to create room"
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: errorMessage, code: 0, userInfo: nil)))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}