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
    
    init(serverURL: String = "https://minddigit-server.vercel.app") {
        manager = SocketManager(socketURL: URL(string: serverURL)!, config: [.log(true)])
        socket = manager.defaultSocket
        setupEventHandlers()
    }
    
    private func setupEventHandlers() {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            print("Connected to server")
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            print("Disconnected from server")
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
        socket.emit("joinRoom", ["code": code, "playerName": playerName, "avatar": avatar])
    }
    
    func setSecret(_ secret: String, for roomCode: String) {
        socket.emit("setSecret", ["code": roomCode, "secret": secret])
    }
    
    func makeGuess(_ guess: String, targetPlayer: String, roomCode: String) {
        socket.emit("makeGuess", ["code": roomCode, "targetPlayer": targetPlayer, "guess": guess])
    }
    
    func requestAvailableRooms() {
        socket.emit("getRoomList")
    }
}