import Foundation
import UIKit

// MARK: - NPC Difficulty Levels
enum NPCDifficulty: Int, CaseIterable {
    case easy = 0
    case medium = 1
    case hard = 2
    case expert = 3
    
    var displayName: String {
        switch self {
        case .easy: return "ง่าย"
        case .medium: return "ปานกลาง" 
        case .hard: return "ยาก"
        case .expert: return "เชี่ยวชาญ"
        }
    }
    
    var color: UIColor {
        switch self {
        case .easy: return .systemGreen
        case .medium: return .systemYellow
        case .hard: return .systemOrange
        case .expert: return .systemRed
        }
    }
    
    var thinkingTime: TimeInterval {
        switch self {
        case .easy: return 3.0
        case .medium: return 2.0
        case .hard: return 1.5
        case .expert: return 1.0
        }
    }
    
    var accuracyBonus: Double {
        switch self {
        case .easy: return 0.1
        case .medium: return 0.3
        case .hard: return 0.5
        case .expert: return 0.8
        }
    }
}

// MARK: - NPC Character
struct NPCCharacter {
    let name: String
    let avatar: String
    let personality: String
    let difficulty: NPCDifficulty
    let specialSkills: [String]
    
    static let characters: [NPCCharacter] = [
        NPCCharacter(name: "เอมี่", avatar: "👩‍💻", personality: "วิเคราะห์เป็นระบบ", difficulty: .easy, specialSkills: ["Logic"]),
        NPCCharacter(name: "แม็กซ์", avatar: "🧙‍♂️", personality: "คิดสร้างสรรค์", difficulty: .medium, specialSkills: ["Logic", "Speed"]),
        NPCCharacter(name: "ซาร่า", avatar: "🦸‍♀️", personality: "ท้าทายและแข่งขัน", difficulty: .hard, specialSkills: ["Precision", "Speed"]),
        NPCCharacter(name: "อาจารย์บอท", avatar: "🤖", personality: "เชี่ยวชาญทุกเรื่อง", difficulty: .expert, specialSkills: ["Precision", "Logic", "Speed", "Lucky"])
    ]
}

// MARK: - NPC AI Manager
class NPCManager {
    static let shared = NPCManager()
    private init() {}
    
    private var currentNPC: NPCCharacter?
    private var gameMode: GameMode = .twoDigit
    private var npcSecretNumber: String = ""
    private var playerSecretNumber: String = ""
    private var moveHistory: [(guess: String, result: Int, isPlayer: Bool)] = []
    
    // MARK: - Game Setup
    func startGameWithNPC(_ npc: NPCCharacter, gameMode: GameMode, playerSecret: String) {
        self.currentNPC = npc
        self.gameMode = gameMode
        self.playerSecretNumber = playerSecret
        self.npcSecretNumber = generateNPCSecret()
        self.moveHistory = []
        
        print("🤖 เริ่มเกมกับ \(npc.name) (\(npc.difficulty.displayName))")
        print("🔢 NPC Secret: \(npcSecretNumber)")
    }
    
    private func generateNPCSecret() -> String {
        let digits = gameMode.digits
        var result = ""
        var usedDigits: Set<Int> = []
        
        for _ in 0..<digits {
            var digit: Int
            repeat {
                digit = Int.random(in: 0...9)
            } while usedDigits.contains(digit)
            
            usedDigits.insert(digit)
            result += String(digit)
        }
        
        return result
    }
    
    // MARK: - Player Move Processing
    func processPlayerMove(_ guess: String) -> (hits: Int, isWin: Bool) {
        let hits = calculateHits(guess: guess, secret: npcSecretNumber)
        let isWin = (hits == gameMode.digits)
        
        moveHistory.append((guess: guess, result: hits, isPlayer: true))
        
        return (hits: hits, isWin: isWin)
    }
    
    // MARK: - NPC Move Generation
    func generateNPCMove(completion: @escaping (String, Int, Bool) -> Void) {
        guard let npc = currentNPC else { return }
        
        // Simulate thinking time
        DispatchQueue.main.asyncAfter(deadline: .now() + npc.difficulty.thinkingTime) {
            let npcGuess = self.generateIntelligentGuess()
            let hits = self.calculateHits(guess: npcGuess, secret: self.playerSecretNumber)
            let isWin = (hits == self.gameMode.digits)
            
            self.moveHistory.append((guess: npcGuess, result: hits, isPlayer: false))
            
            completion(npcGuess, hits, isWin)
        }
    }
    
    private func generateIntelligentGuess() -> String {
        guard let npc = currentNPC else { return generateRandomGuess() }
        
        let playerMoves = moveHistory.filter { !$0.isPlayer }
        
        // If it's the first move, generate strategic first guess
        if playerMoves.isEmpty {
            return generateStrategicFirstGuess()
        }
        
        // Use AI strategy based on difficulty
        switch npc.difficulty {
        case .easy:
            return generateEasyGuess()
        case .medium:
            return generateMediumGuess()
        case .hard:
            return generateHardGuess()
        case .expert:
            return generateExpertGuess()
        }
    }
    
    private func generateStrategicFirstGuess() -> String {
        // Strategic first guesses for different game modes
        let strategicGuesses: [GameMode: [String]] = [
            .oneDigit: ["5", "7", "3"],
            .twoDigit: ["12", "34", "56", "78"],
            .threeDigit: ["123", "456", "789", "012"],
            .fourDigit: ["1234", "5678", "9012", "3456"]
        ]
        
        let options = strategicGuesses[gameMode] ?? []
        return options.randomElement() ?? generateRandomGuess()
    }
    
    private func generateEasyGuess() -> String {
        // Easy AI: mostly random with slight pattern awareness
        if Bool.random() && !moveHistory.isEmpty {
            return generatePatternBasedGuess()
        }
        return generateRandomGuess()
    }
    
    private func generateMediumGuess() -> String {
        // Medium AI: uses some logic and eliminates impossible digits
        let possibleDigits = getPossibleDigits()
        return generateGuessFromDigits(possibleDigits)
    }
    
    private func generateHardGuess() -> String {
        // Hard AI: advanced pattern recognition and elimination
        let analysis = analyzePlayerHistory()
        return generateAdvancedGuess(based: analysis)
    }
    
    private func generateExpertGuess() -> String {
        // Expert AI: near-optimal play with sophisticated algorithms  
        let optimalGuess = calculateOptimalGuess()
        return optimalGuess
    }
    
    // MARK: - AI Helper Methods
    private func generateRandomGuess() -> String {
        let digits = gameMode.digits
        var result = ""
        var usedDigits: Set<Int> = []
        
        for _ in 0..<digits {
            var digit: Int
            repeat {
                digit = Int.random(in: 0...9)
            } while usedDigits.contains(digit)
            
            usedDigits.insert(digit)
            result += String(digit)
        }
        
        return result
    }
    
    private func generatePatternBasedGuess() -> String {
        // Analyze player's previous guesses to find patterns
        let playerGuesses = moveHistory.filter { $0.isPlayer }
        
        if let lastGuess = playerGuesses.last {
            // Try variations of the last successful guess
            if lastGuess.result > 0 {
                return generateVariation(of: lastGuess.guess)
            }
        }
        
        return generateRandomGuess()
    }
    
    private func generateVariation(of guess: String) -> String {
        let digits = Array(guess.compactMap { Int(String($0)) })
        var newDigits = digits
        
        // Change 1-2 digits randomly
        let changesToMake = Int.random(in: 1...min(2, digits.count))
        
        for _ in 0..<changesToMake {
            let index = Int.random(in: 0..<newDigits.count)
            var newDigit: Int
            repeat {
                newDigit = Int.random(in: 0...9)
            } while newDigits.contains(newDigit)
            
            newDigits[index] = newDigit
        }
        
        return newDigits.map { String($0) }.joined()
    }
    
    private func getPossibleDigits() -> Set<Int> {
        var possible: Set<Int> = Set(0...9)
        
        // Eliminate digits that led to 0 hits
        for move in moveHistory.filter({ !$0.isPlayer && $0.result == 0 }) {
            for char in move.guess {
                if let digit = Int(String(char)) {
                    possible.remove(digit)
                }
            }
        }
        
        return possible
    }
    
    private func generateGuessFromDigits(_ digits: Set<Int>) -> String {
        let availableDigits = Array(digits)
        let requiredCount = gameMode.digits
        
        guard availableDigits.count >= requiredCount else {
            return generateRandomGuess()
        }
        
        let selectedDigits = availableDigits.shuffled().prefix(requiredCount)
        return selectedDigits.map { String($0) }.joined()
    }
    
    private func analyzePlayerHistory() -> [String: Any] {
        // Advanced analysis of player patterns
        let playerMoves = moveHistory.filter { $0.isPlayer }
        
        var analysis: [String: Any] = [:]
        analysis["totalMoves"] = playerMoves.count
        analysis["averageHits"] = playerMoves.isEmpty ? 0 : Double(playerMoves.map { $0.result }.reduce(0, +)) / Double(playerMoves.count)
        
        // Find most successful digits
        var digitSuccess: [Int: (count: Int, totalHits: Int)] = [:]
        for move in playerMoves {
            for char in move.guess {
                if let digit = Int(String(char)) {
                    let current = digitSuccess[digit] ?? (count: 0, totalHits: 0)
                    digitSuccess[digit] = (count: current.count + 1, totalHits: current.totalHits + move.result)
                }
            }
        }
        
        analysis["digitSuccess"] = digitSuccess
        return analysis
    }
    
    private func generateAdvancedGuess(based analysis: [String: Any]) -> String {
        // Use analysis to make sophisticated guesses
        guard let digitSuccess = analysis["digitSuccess"] as? [Int: (count: Int, totalHits: Int)] else {
            return generateRandomGuess()
        }
        
        // Sort digits by success rate
        let sortedDigits = digitSuccess.sorted { first, second in
            let firstRate = Double(first.value.totalHits) / Double(first.value.count)
            let secondRate = Double(second.value.totalHits) / Double(second.value.count)
            return firstRate > secondRate
        }
        
        let topDigits = sortedDigits.prefix(gameMode.digits).map { $0.key }
        
        if topDigits.count == gameMode.digits {
            return topDigits.shuffled().map { String($0) }.joined()
        }
        
        return generateRandomGuess()
    }
    
    private func calculateOptimalGuess() -> String {
        // Expert-level AI using minimax-like approach
        let allPossibleGuesses = generateAllPossibleGuesses()
        var bestGuess = ""
        var bestScore = -1
        
        for guess in allPossibleGuesses.prefix(100) { // Limit for performance
            let score = evaluateGuessQuality(guess)
            if score > bestScore {
                bestScore = score
                bestGuess = guess
            }
        }
        
        return bestGuess.isEmpty ? generateRandomGuess() : bestGuess
    }
    
    private func generateAllPossibleGuesses() -> [String] {
        // Generate all valid guesses for the current game mode
        let digits = Array(0...9)
        var guesses: [String] = []
        
        func generateCombinations(_ current: [Int], _ remaining: [Int], _ length: Int) {
            if current.count == length {
                guesses.append(current.map { String($0) }.joined())
                return
            }
            
            for (index, digit) in remaining.enumerated() {
                var newCurrent = current
                var newRemaining = remaining
                newCurrent.append(digit)
                newRemaining.remove(at: index)
                generateCombinations(newCurrent, newRemaining, length)
            }
        }
        
        generateCombinations([], digits, gameMode.digits)
        return guesses.shuffled() // Randomize order
    }
    
    private func evaluateGuessQuality(_ guess: String) -> Int {
        // Evaluate how good a guess is based on information gained
        var score = 0
        
        // Bonus for using digits that haven't been tried much
        let digitCounts = getDigitUsageCount()
        for char in guess {
            if let digit = Int(String(char)) {
                let count = digitCounts[digit] ?? 0
                score += max(0, 5 - count) // Bonus for less-used digits
            }
        }
        
        // Bonus for strategic positioning
        score += evaluatePositionalStrategy(guess)
        
        return score
    }
    
    private func getDigitUsageCount() -> [Int: Int] {
        var counts: [Int: Int] = [:]
        
        for move in moveHistory.filter({ !$0.isPlayer }) {
            for char in move.guess {
                if let digit = Int(String(char)) {
                    counts[digit] = (counts[digit] ?? 0) + 1
                }
            }
        }
        
        return counts
    }
    
    private func evaluatePositionalStrategy(_ guess: String) -> Int {
        // Evaluate based on positional information from previous guesses
        // This is a simplified version - a full implementation would be more complex
        return Int.random(in: 0...3) // Placeholder
    }
    
    // MARK: - Utility Methods
    private func calculateHits(guess: String, secret: String) -> Int {
        let guessDigits = Set(guess)
        let secretDigits = Set(secret)
        return guessDigits.intersection(secretDigits).count
    }
    
    // MARK: - Public Interface
    func getCurrentNPC() -> NPCCharacter? {
        return currentNPC
    }
    
    func getNPCSecret() -> String {
        return npcSecretNumber
    }
    
    func getGameHistory() -> [(guess: String, result: Int, isPlayer: Bool)] {
        return moveHistory
    }
    
    func resetGame() {
        currentNPC = nil
        npcSecretNumber = ""
        playerSecretNumber = ""
        moveHistory = []
    }
}