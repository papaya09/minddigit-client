import UIKit

// MARK: - Network Methods
extension OnlineGameViewController {
    
    // MARK: - Enhanced Network Layer with Ultra-Smooth Gaming
    
    func startGamePolling() {
        retryCount = 0
        isRecovering = false
        setupOptimizedURLSession()
        initializeNetworkHealth()
        startAdaptivePolling()
        
        // Immediate fetch
        fetchGameStateWithSilentRetry()
        print("🎯 Started adaptive smart polling with client cache")
    }
    
    // MARK: - 🎯 Adaptive Smart Polling & Client Cache System
    
    func initializeNetworkHealth() {
        networkHealth = [
            "successRate": 1.0,
            "avgResponseTime": 0.0,
            "consecutiveErrors": 0,
            "totalRequests": 0,
            "successfulRequests": 0
        ]
        
        adaptivePollingConfig = [
            "baseInterval": 0.5,
            "currentInterval": 0.5,
            "minInterval": 0.2,
            "maxInterval": 5.0,
            "errorMultiplier": 1.5,
            "successDivider": 1.2
        ]
        
        print("🎯 Network health tracking initialized")
    }
    
    private func startAdaptivePolling() {
        ultraFastTimer?.invalidate()
        backgroundSyncTimer?.invalidate()
        
        let currentInterval = adaptivePollingConfig["currentInterval"] as? TimeInterval ?? 0.5
        
        ultraFastTimer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
            self?.adaptiveStateCheck()
        }
        
        print("🎯 Adaptive polling started with \(currentInterval)s interval")
    }
    
    private func adaptiveStateCheck() {
        // Use request prioritization
        prioritizeRequest(type: "quickCheck") { [weak self] in
            self?.performAdaptiveCheck()
        }
    }
    
    private func performAdaptiveCheck() {
        // Prevent concurrent requests
        if isQuickCheckInProgress { return }
        
        // Optimize polling frequency based on current conditions
        optimizePollingFrequency()
        
        // Smart cache sync
        smartCacheSync()
        
        // Rate limiting
        let now = Date.timeIntervalSinceReferenceDate
        if now - lastQuickCheckTime < 0.1 { return }
        lastQuickCheckTime = now
        
        isQuickCheckInProgress = true
        
        // Track request
        trackNetworkRequest()
        
        // Use cached data first, then sync with server
        displayCachedDataIfAvailable()
        quickStateCheckWithSilentRetry()
    }
    
    func fetchGameStateWithSilentRetry() {
        // Start with cached data
        displayCachedDataIfAvailable()
        
        // Silent fetch from server
        silentFetchGameState { [weak self] success in
            if success {
                self?.trackNetworkSuccess()
                self?.adjustPollingForSuccess()
            } else {
                self?.trackNetworkError()
                self?.adjustPollingForError()
                self?.scheduleRetry()
            }
        }
    }
    
    private func displayCachedDataIfAvailable() {
        if !cachedGameHistory.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.updateGameHistoryFromCache()
            }
        }
    }
    
    private func updateGameHistoryFromCache() {
        // Update UI with cached history
        if !cachedGameHistory.isEmpty {
            let historySignature = createHistorySignature(cachedGameHistory)
            
            if currentHistorySignature != historySignature {
                currentHistorySignature = historySignature
                updateGameHistory(cachedGameHistory)
            }
        }
    }
    
    // MARK: - Connection Pooling Setup
    private func setupOptimizedURLSession() {
        let config = URLSessionConfiguration.default
        
        // Optimize for gaming
        config.httpMaximumConnectionsPerHost = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 10.0
        
        // Connection pooling for better performance
        config.httpShouldUsePipelining = true
        config.httpShouldSetCookies = false
        
        // Reduce overhead
        config.urlCache = nil
        config.urlCredentialStorage = nil
        
        sharedURLSession = URLSession(configuration: config)
        print("⚡ Optimized URL session configured for gaming")
    }
    
    // MARK: - 🎯 Network Health Tracking
    
    private func trackNetworkRequest() {
        let totalRequests = (networkHealth["totalRequests"] as? Int ?? 0) + 1
        networkHealth["totalRequests"] = totalRequests
    }
    
    private func trackNetworkSuccess() {
        let successfulRequests = (networkHealth["successfulRequests"] as? Int ?? 0) + 1
        let totalRequests = networkHealth["totalRequests"] as? Int ?? 1
        
        networkHealth["successfulRequests"] = successfulRequests
        networkHealth["successRate"] = Double(successfulRequests) / Double(totalRequests)
        networkHealth["consecutiveErrors"] = 0
        
        // Update connection quality indicator
        let successRate = networkHealth["successRate"] as? Double ?? 1.0
        let avgResponseTime = networkHealth["avgResponseTime"] as? Double ?? 200.0
        let consecutiveErrors = networkHealth["consecutiveErrors"] as? Int ?? 0
        
        updateConnectionQuality(successRate: successRate, avgResponseTime: avgResponseTime, consecutiveErrors: consecutiveErrors)
        
        print("🎯 Network success: \(networkHealth["successRate"] ?? 0.0)")
    }
    
    private func trackNetworkError() {
        let consecutiveErrors = (networkHealth["consecutiveErrors"] as? Int ?? 0) + 1
        let totalRequests = networkHealth["totalRequests"] as? Int ?? 1
        let successfulRequests = networkHealth["successfulRequests"] as? Int ?? 0
        
        networkHealth["consecutiveErrors"] = consecutiveErrors
        networkHealth["successRate"] = Double(successfulRequests) / Double(totalRequests)
        
        // Update connection quality indicator
        let successRate = networkHealth["successRate"] as? Double ?? 1.0
        let avgResponseTime = networkHealth["avgResponseTime"] as? Double ?? 1000.0
        
        updateConnectionQuality(successRate: successRate, avgResponseTime: avgResponseTime, consecutiveErrors: consecutiveErrors)
        
        print("🎯 Network error: consecutive=\(consecutiveErrors), rate=\(networkHealth["successRate"] ?? 0.0)")
    }
    
    // MARK: - 🎯 Adaptive Polling Adjustment
    
    private func adjustPollingForSuccess() {
        let currentInterval = adaptivePollingConfig["currentInterval"] as? TimeInterval ?? 0.5
        let successDivider = adaptivePollingConfig["successDivider"] as? Double ?? 1.2
        let minInterval = adaptivePollingConfig["minInterval"] as? TimeInterval ?? 0.2
        
        let newInterval = max(currentInterval / successDivider, minInterval)
        adaptivePollingConfig["currentInterval"] = newInterval
        
        restartAdaptivePolling()
        print("🎯 Polling faster: \(newInterval)s (success)")
    }
    
    private func adjustPollingForError() {
        let currentInterval = adaptivePollingConfig["currentInterval"] as? TimeInterval ?? 0.5
        let errorMultiplier = adaptivePollingConfig["errorMultiplier"] as? Double ?? 1.5
        let maxInterval = adaptivePollingConfig["maxInterval"] as? TimeInterval ?? 5.0
        
        let newInterval = min(currentInterval * errorMultiplier, maxInterval)
        adaptivePollingConfig["currentInterval"] = newInterval
        
        restartAdaptivePolling()
        print("🎯 Polling slower: \(newInterval)s (error)")
    }
    
    private func restartAdaptivePolling() {
        ultraFastTimer?.invalidate()
        let currentInterval = adaptivePollingConfig["currentInterval"] as? TimeInterval ?? 0.5
        
        ultraFastTimer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
            self?.adaptiveStateCheck()
        }
    }
    
    private func scheduleRetry() {
        let retryDelay = silentRetryConfig["retryDelay"] as? TimeInterval ?? 1.0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            self?.fetchGameStateWithSilentRetry()
        }
    }
    
    // MARK: - 🎯 Silent Network Methods
    
    private func quickStateCheckWithSilentRetry() {
        let now = Date.timeIntervalSinceReferenceDate
        let url = "\(baseURL)/room/quick-status"
        let parameters = [
            "roomId": roomId,
            "playerId": playerId,
            "lastUpdate": String(Int(now))
        ]
        
        var urlComponents = URLComponents(string: url)!
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 3.0
        
        let requestStartTime = now
        
        sharedURLSession.dataTask(with: request) { [weak self] data, response, error in
            let responseTime = (Date.timeIntervalSinceReferenceDate - requestStartTime) * 1000 // Response time tracking
            
            defer {
                DispatchQueue.main.async {
                    self?.isQuickCheckInProgress = false
                }
            }
            
            guard let self = self else { return }
            
            // Track response time for adaptive polling
            self.updatePerformanceMetrics(responseTime: responseTime, endpoint: "quick-status")
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["success"] as? Bool == true {
                // Success - update cache and UI
                self.trackNetworkSuccess()
                self.adjustPollingForSuccess()
                self.updateCacheFromQuickResponse(json)
                
                DispatchQueue.main.async {
                    self.processQuickUpdate(json)
                }
            } else {
                // Silent error - just track and continue
                self.trackNetworkError()
                self.adjustPollingForError()
                
                // Only retry if not too many consecutive errors
                let consecutiveErrors = self.networkHealth["consecutiveErrors"] as? Int ?? 0
                let maxErrors = self.silentRetryConfig["maxConsecutiveErrors"] as? Int ?? 10
                
                if consecutiveErrors < maxErrors {
                    print("🎯 Silent retry (\(consecutiveErrors)/\(maxErrors))")
                } else {
                    print("🎯 Max errors reached, backing off")
                }
            }
        }.resume()
    }
    
    private func silentFetchGameState(completion: @escaping (Bool) -> Void) {
        let url = "\(baseURL)/room/status-local"
        let parameters = [
            "roomId": roomId,
            "playerId": playerId
        ]
        
        var urlComponents = URLComponents(string: url)!
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 5.0
        
        sharedURLSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { 
                completion(false)
                return 
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               json["success"] as? Bool == true {
                
                // Update cache
                self.updateCacheFromStateResponse(json)
                
                DispatchQueue.main.async {
                    self.processGameState(json)
                }
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    // MARK: - 🎯 Cache Management
    
    private func updateCacheFromQuickResponse(_ json: [String: Any]) {
        if let room = json["room"] as? [String: Any] {
            historyCache["lastQuickUpdate"] = Date.timeIntervalSinceReferenceDate
            historyCache["gameState"] = room["gameState"]
            historyCache["currentTurn"] = room["currentTurn"]
            historyCache["historyCount"] = room["historyCount"]
        }
    }
    
    private func updateCacheFromStateResponse(_ json: [String: Any]) {
        if let room = json["room"] as? [String: Any] {
            historyCache["lastStateUpdate"] = Date.timeIntervalSinceReferenceDate
            historyCache["room"] = room
            
            // Cache game state
            if let gameState = room["gameState"] as? String {
                historyCache["gameState"] = gameState
            }
            
            if let currentTurn = room["currentTurn"] as? String {
                historyCache["currentTurn"] = currentTurn
            }
        }
    }
    

    
    // MARK: - Background Sync (2s for comprehensive data)
    private func startBackgroundSync() {
        backgroundSyncTimer?.invalidate()
        
        // 🔄 BACKGROUND: 2s comprehensive sync
        backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.backgroundSync()
        }
        
        print("🔄 Background sync started: 2s intervals")
    }
    
    // MARK: - Performance Monitoring & Adaptive Optimization
    
    private func updatePerformanceMetrics(responseTime: Double, endpoint: String) {
        let now = Date.timeIntervalSinceReferenceDate
        
        // Update moving average
        let key = "\(endpoint)_avg"
        let currentAvg = performanceMetrics[key] as? Double ?? 0
        let newAvg = (currentAvg * 0.8) + (responseTime * 0.2) // Weighted average
        performanceMetrics[key] = newAvg
        
        // Track last update
        performanceMetrics["\(endpoint)_last"] = now
        
        // Auto-optimize based on performance
        if adaptivePollingEnabled {
            adaptPollingToPerformance(endpoint: endpoint, responseTime: responseTime, average: newAvg)
        }
    }
    
    private func adaptPollingToPerformance(endpoint: String, responseTime: Double, average: Double) {
        // Adaptive optimization based on performance
        if endpoint == "quick-status" {
            // Adjust ultra-fast polling based on quick-status performance
            if average > 500 { // > 500ms average
                print("⚠️ Slow quick-status (\(Int(average))ms), reducing frequency")
                adjustUltraFastPolling(interval: 0.5) // Slow down to 500ms
            } else if average < 100 { // < 100ms average, very fast
                print("⚡ Fast quick-status (\(Int(average))ms), increasing frequency")
                adjustUltraFastPolling(interval: 0.15) // Speed up to 150ms
            } else if average < 200 { // < 200ms average, good performance
                adjustUltraFastPolling(interval: 0.2) // Standard 200ms
            }
        }
        
        // Monitor overall health
        let totalRequests = (performanceMetrics["total_requests"] as? Int ?? 0) + 1
        performanceMetrics["total_requests"] = totalRequests
        
        if totalRequests % 50 == 0 { // Every 50 requests
            logPerformanceStatus()
        }
    }
    
    private func adjustUltraFastPolling(interval: TimeInterval) {
        ultraFastTimer?.invalidate()
        
        ultraFastTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.quickStateCheck()
        }
        
        print("🔧 Ultra-fast polling adjusted to \(Int(interval * 1000))ms")
    }
    
    private func logPerformanceStatus() {
        let quickAvg = performanceMetrics["quick-status_avg"] as? Double ?? 0
        let statusAvg = performanceMetrics["status-local_avg"] as? Double ?? 0
        let historyAvg = performanceMetrics["history-local_avg"] as? Double ?? 0
        let totalRequests = performanceMetrics["total_requests"] as? Int ?? 0
        
        print("📊 Performance Status:")
        print("   Quick Status: \(Int(quickAvg))ms avg")
        print("   Full Status: \(Int(statusAvg))ms avg") 
        print("   History: \(Int(historyAvg))ms avg")
        print("   Total Requests: \(totalRequests)")
        
        // Show performance feedback to user if needed
        if quickAvg > 1000 || statusAvg > 3000 {
            DispatchQueue.main.async { [weak self] in
                self?.showPerformanceOptimization()
            }
        }
    }
    
    private func showPerformanceOptimization() {
        let optimizationLabel = UILabel()
        optimizationLabel.text = "🚀 Performance optimizing..."
        optimizationLabel.font = UIFont.systemFont(ofSize: 11)
        optimizationLabel.textColor = UIColor.systemTeal
        optimizationLabel.textAlignment = .center
        optimizationLabel.alpha = 0
        optimizationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(optimizationLabel)
        NSLayoutConstraint.activate([
            optimizationLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 90),
            optimizationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        // Fade in and out
        UIView.animate(withDuration: 0.3, animations: {
            optimizationLabel.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 1.5, animations: {
                optimizationLabel.alpha = 0
            }) { _ in
                optimizationLabel.removeFromSuperview()
            }
        }
    }
    
    // Enhanced quick state check with performance monitoring
    private func quickStateCheck() {
        // Prevent duplicate requests
        guard !isRecovering && !isQuickCheckInProgress else { return }
        
        let now = Date.timeIntervalSinceReferenceDate
        
        // Rate limiting: minimum 100ms between requests
        guard now - lastQuickCheckTime >= 0.1 else { return }
        
        isQuickCheckInProgress = true
        lastQuickCheckTime = now
        
        let requestStartTime = now
        
        let url = "\(baseURL)/room/quick-status"
        let parameters = [
            "roomId": roomId,
            "playerId": playerId,
            "lastUpdate": String(Int(now))
        ]
        
        var urlComponents = URLComponents(string: url)!
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = 2.0 // Very short timeout for quick checks
        
        sharedURLSession.dataTask(with: request) { [weak self] data, response, error in
            let responseTime = (Date.timeIntervalSinceReferenceDate - requestStartTime) * 1000 // ms
            
            defer {
                DispatchQueue.main.async {
                    self?.isQuickCheckInProgress = false
                }
            }
            
            guard let self = self else { return }
            
            // Update performance metrics
            self.updatePerformanceMetrics(responseTime: responseTime, endpoint: "quick-status")
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["success"] as? Bool == true else {
                return
            }
            
            DispatchQueue.main.async {
                self.processQuickUpdate(json)
            }
        }.resume()
    }
    
    // Background comprehensive sync
    func backgroundSync() {
        guard !isRecovering && !isBackgroundSyncInProgress else { return }
        
        isBackgroundSyncInProgress = true
        
        // Parallel requests for maximum speed
        let group = DispatchGroup()
        
        group.enter()
        fetchGameState {
            group.leave()
        }
        
        group.enter()
        fetchGameHistory {
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isBackgroundSyncInProgress = false
            print("🔄 Background sync completed")
        }
    }
    
    // Process quick updates (minimal overhead)
    private func processQuickUpdate(_ json: [String: Any]) {
        guard let room = json["room"] as? [String: Any] else { return }
        
        // Check for turn changes (most critical for smooth gameplay)
        if let newTurn = room["currentTurn"] as? String,
           newTurn != currentTurn {
            print("⚡ Quick turn update: \(currentTurn) → \(newTurn)")
            
            currentTurn = newTurn
            isMyTurn = (currentTurn == playerId)
            
            // Immediate UI update
            updateTurnUI()
            updateKeypadButtonsState()
            
            // Haptic feedback for turn change
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        // Check for game state changes
        if let newState = room["gameState"] as? String,
           newState != gameState {
            print("⚡ Quick state update: \(gameState) → \(newState)")
            gameState = newState
        }
        
        // Check for new history entries (count only for quick check)
        if let historyCount = room["historyCount"] as? Int {
            let currentCount = historyStackView.arrangedSubviews.count
            if historyCount > currentCount {
                print("⚡ New history detected: \(currentCount) → \(historyCount)")
                // Trigger background sync for full history
                backgroundSync()
            }
        }
    }
    
    private func scheduleSmartPolling() {
        // Keep ultra-fast polling but adjust background sync
        let gameLength = historyStackView.arrangedSubviews.count
        
        backgroundSyncTimer?.invalidate()
        
        // Adaptive background sync based on game length
        var syncInterval: TimeInterval = 2.0
        if gameLength > 20 {
            syncInterval = 3.0  // Slower for long games
        }
        if gameLength > 40 {
            syncInterval = 5.0  // Even slower for very long games
        }
        
        backgroundSyncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            self?.backgroundSync()
        }
        
        print("⏱️ Adjusted background sync: \(syncInterval)s (gameLength: \(gameLength))")
    }
    
    // Start aggressive polling after player actions
    func startAggressivePolling() {
        print("🚀 Starting aggressive polling for real-time sync")
        aggressivePollingTimer?.invalidate()
        aggressivePollingCount = 0
        
        // 🚨 GAME LENGTH CHECK: Reduce aggressive polling for long games
        let gameLength = historyStackView.arrangedSubviews.count
        if gameLength > 30 {
            print("⚠️ Skipping aggressive polling for long game to prevent server overload")
            scheduleSmartPolling() // Just use smart polling instead
            return
        }
        
        // Show visual feedback that we're syncing aggressively
        DispatchQueue.main.async { [weak self] in
            self?.turnLabel?.text = "🔄 Syncing..."
        }
        
        aggressivePollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.aggressivePollingCount += 1
            print("⚡ Aggressive poll #\(self.aggressivePollingCount)")
            
            self.fetchGameStateWithRetry()
            
            // Stop aggressive polling after max attempts
            if self.aggressivePollingCount >= self.maxAggressivePolls {
                print("✅ Aggressive polling completed, returning to smart polling")
                timer.invalidate()
                self.aggressivePollingTimer = nil
                self.scheduleSmartPolling() // Resume normal polling
                
                // Update UI to reflect normal state
                DispatchQueue.main.async { [weak self] in
                    self?.updateTurnUI()
                }
            }
        }
    }
    
    // MARK: - Immediate Sync Methods
    
    func syncGameStateImmediately(completion: (() -> Void)? = nil) {
        print("🚀 Immediate game state sync triggered")
        
        // Cancel current timer and fetch immediately
        gameTimer?.invalidate()
        
        // Fetch both state and history in parallel for complete sync
        let group = DispatchGroup()
        
        group.enter()
        fetchGameState { [weak self] in
            self?.scheduleSmartPolling() // Restart smart polling
            group.leave()
        }
        
        group.enter()
        fetchGameHistory {
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion?()
            print("✅ Immediate sync completed")
        }
    }
    
    func stopGamePolling() {
        gameTimer?.invalidate()
        gameTimer = nil
        aggressivePollingTimer?.invalidate()
        aggressivePollingTimer = nil
        ultraFastTimer?.invalidate()
        ultraFastTimer = nil
        backgroundSyncTimer?.invalidate()
        backgroundSyncTimer = nil
        retryCount = 0
        isRecovering = false
        aggressivePollingCount = 0
        pendingOptimisticUpdates.removeAll()
        performanceMetrics.removeAll()
        print("⏹️ Stopped all polling and reset recovery state")
    }
    
    private func fetchGameStateWithRetry() {
        // Prevent multiple concurrent requests during recovery
        guard !isRecovering else {
            print("🚧 Skipping fetch - recovery in progress")
            return
        }
        
        fetchGameState { [weak self] in
            // fetchGameState completed successfully
            self?.retryCount = 0
            self?.isRecovering = false
        }
    }
    
    private func handleFetchFailure() {
        retryCount += 1
        print("⚠️ Fetch failed (attempt \(retryCount)/\(maxRetries))")
        
        if retryCount >= maxRetries {
            print("🔄 Starting recovery mode")
            isRecovering = true
            
            // 🚨 ENHANCED: Check for long game issues
            let gameLength = historyStackView.arrangedSubviews.count
            if gameLength > 25 {
                print("🎮 Long game detected (\(gameLength) moves), implementing enhanced recovery")
                
                // For long games, offer user options instead of automatic recovery
                DispatchQueue.main.async { [weak self] in
                    self?.performSilentLongGameRecovery()
                }
                return
            }
            
            // Use last successful response as fallback
            if let lastResponse = lastSuccessfulResponse {
                print("📦 Using cached response for recovery")
                processGameState(lastResponse)
            }
            
            // Show recovery message to user
            DispatchQueue.main.async { [weak self] in
                self?.showRecoveryMessage()
            }
            
            // Reset retry count for next attempt
            retryCount = 0
            
            // 🚨 ENHANCED: Longer recovery delay for games with many moves
            let recoveryDelay: TimeInterval = gameLength > 15 ? 8.0 : 5.0
            print("⏰ Scheduling recovery in \(recoveryDelay)s")
            
            // Schedule recovery attempt
            DispatchQueue.main.asyncAfter(deadline: .now() + recoveryDelay) { [weak self] in
                self?.isRecovering = false
                print("✅ Recovery mode ended, resuming adaptive polling")
                self?.scheduleSmartPolling() // Use adaptive polling
            }
        }
    }
    
    private func performSilentLongGameRecovery() {
        print("🎯 Performing silent recovery for long game")
        
        // Automatic silent recovery strategy
        let gameLength = historyStackView.arrangedSubviews.count
        
        if gameLength > 50 {
            // Very long game - reset to prevent memory issues
            print("🎯 Auto-resetting very long game (\(gameLength) moves)")
            performSilentGameStateReset()
        } else if gameLength > 30 {
            // Long game - manual refresh
            print("🎯 Auto-refreshing long game (\(gameLength) moves)")
            silentManualRefresh()
        } else {
            // Medium game - just continue trying
            print("🎯 Continuing with adaptive polling")
            retryCount = 0
            isRecovering = false
            startAdaptivePolling()
        }
    }
    
    private func performSilentGameStateReset() {
        print("🎯 Silent game state reset")
        
        // Reset counters silently
        retryCount = 0
        isRecovering = false
        
        // Clear cache
        cachedGameHistory.removeAll()
        historyCache.removeAll()
        
        // Restart adaptive polling
        startAdaptivePolling()
        
        // Silent fetch
        fetchGameStateWithSilentRetry()
    }
    
    private func silentManualRefresh() {
        print("🎯 Silent manual refresh")
        
        retryCount = 0
        isRecovering = false
        
        // Display cached data while refreshing
        displayCachedDataIfAvailable()
        
        // Silent fetch fresh data
        fetchGameStateWithSilentRetry()
        // 🎯 HISTORY IS NOW MANUAL ONLY - No auto-refresh to prevent flickering
        // fetchGameHistory() // Disabled - user controls via refresh button
    }
    
    private func performGameStateReset() {
        print("🔄 Performing comprehensive game state reset")
        
        // Reset all network states
        retryCount = 0
        isRecovering = false
        lastSuccessfulResponse = nil
        
        // Stop all timers
        stopGamePolling()
        
        // Show loading state
        DispatchQueue.main.async { [weak self] in
            self?.turnLabel?.text = "🔄 Resetting..."
            self?.loadingSpinner.startAnimating()
        }
        
        // Force comprehensive sync with delay to let server stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.syncGameStateImmediately { [weak self] in
                self?.loadingSpinner.stopAnimating()
                self?.startGamePolling() // Restart polling
                print("✅ Game state reset completed")
            }
        }
    }
    
    private func showRecoveryMessage() {
        // Create a subtle recovery indicator
        let recoveryLabel = UILabel()
        recoveryLabel.text = "🔄 Reconnecting..."
        recoveryLabel.font = UIFont.systemFont(ofSize: 12)
        recoveryLabel.textColor = UIColor.systemOrange
        recoveryLabel.textAlignment = .center
        recoveryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(recoveryLabel)
        NSLayoutConstraint.activate([
            recoveryLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            recoveryLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        // Auto-remove after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            recoveryLabel.removeFromSuperview()
        }
    }
    
    func fetchGameState(completion: (() -> Void)? = nil) {
        let url = "\(baseURL)/room/status-local"
        let parameters = [
            "roomId": roomId,
            "playerId": playerId
        ]
        
        var urlComponents = URLComponents(string: url)!
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        
        // 🚨 VERCEL OPTIMIZATION: Dynamic timeout based on expected cold start
        let expectedColdStart = lastSuccessfulResponse == nil || 
                              (lastSuccessfulResponse?["serverless"] as? [String: Any])?["coldStart"] as? Bool == true
        request.timeoutInterval = expectedColdStart ? 20.0 : 10.0
        
        let requestStartTime = Date.timeIntervalSinceReferenceDate
        
        sharedURLSession.dataTask(with: request) { [weak self] data, response, error in
            let responseTime = (Date.timeIntervalSinceReferenceDate - requestStartTime) * 1000 // ms
            
            defer { completion?() }
            
            guard let self = self else { 
                return 
            }
            
            // Update performance metrics
            self.updatePerformanceMetrics(responseTime: responseTime, endpoint: "status-local")
            
            if let error = error {
                print("❌ Network error (Vercel):", error.localizedDescription)
                self.handleVercelError(error: error, responseTime: responseTime)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                return
            }
            
            // 🚨 VERCEL SPECIFIC: Handle 500 errors (cold start issues)
            if httpResponse.statusCode == 500 {
            guard let data = data,
                      let errorString = String(data: data, encoding: .utf8) else {
                    print("❌ HTTP 500 without error data")
                return
            }
            
                print("❌ Vercel HTTP 500:", errorString)
                self.handleVercelColdStart(responseTime: responseTime)
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("📡 Status response received (Vercel)")
                    
                    // 🚨 VERCEL MONITORING: Track performance metrics
                    self.processVercelMetrics(json: json, responseTime: responseTime)
                    
                    // Cache successful response
                    self.lastSuccessfulResponse = json
                    
                    // Process game state
                    if json["success"] as? Bool == true {
                        self.processGameState(json)
                    } else {
                        print("⚠️ Server reported error:", json["error"] as? String ?? "Unknown")
                        
                        // Check for recovery suggestions
                        if let recovery = json["recovery"] as? [String: Any],
                           let suggestion = recovery["suggestion"] as? String {
                            print("💡 Vercel recovery suggestion:", suggestion)
                        }
                    }
                } else {
                    print("❌ Invalid JSON format")
                }
            } catch {
                print("❌ JSON parsing error:", error)
            }
        }.resume()
    }
    
    // MARK: - History Management
    
    // 🎯 APPEND-ONLY HISTORY UPDATE - No more flickering!
    func fetchGameHistoryForAppend(completion: @escaping () -> Void) {
        guard !roomId.isEmpty, !playerId.isEmpty else { 
            completion()
            return 
        }
        
        let urlString = "\(baseURL)/game/history-local?roomId=\(roomId)&playerId=\(playerId)"
        guard let url = URL(string: urlString) else { 
            completion()
            return 
        }
        
        let requestStartTime = Date.timeIntervalSinceReferenceDate
        
        sharedURLSession.dataTask(with: url) { [weak self] data, response, error in
            let responseTime = (Date.timeIntervalSinceReferenceDate - requestStartTime) * 1000
            
            guard let self = self else { 
                completion()
                return 
            }
            
            // Update performance metrics
            self.updatePerformanceMetrics(responseTime: responseTime, endpoint: "history-append")
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let newHistory = json["history"] as? [[String: Any]] {
                
                DispatchQueue.main.async {
                    self.appendNewHistoryEntries(newHistory: newHistory)
                    
                    // Silent win/lose handling (no disruptive dialogs)
                    if let winner = json["winner"] as? [String: Any],
                       let winnerPlayerId = winner["playerId"] as? String {
                        self.handleGameEndSilently(winnerId: winnerPlayerId, winnerName: winner["playerName"] as? String)
                    }
                    
                    completion()
                }
            } else {
                print("🎯 History append fetch failed silently")
                completion()
            }
        }.resume()
    }
    
    // 🎯 SMART APPEND: Only add new entries, keep existing ones
    private func appendNewHistoryEntries(newHistory: [[String: Any]]) {
        guard let historyContainer = self.historyContainer else {
            print("⚠️ History container not initialized")
            return
        }
        
        // Find new entries by comparing with what's already displayed
        let newEntries = findNewHistoryEntries(current: displayedHistoryEntries, new: newHistory)
        
        if newEntries.isEmpty {
            print("📜 No new history entries to append")
            return
        }
        
        print("📜 Appending \(newEntries.count) new history entries")
        
        // Remove placeholder if it exists
        if displayedHistoryEntries.isEmpty {
            for subview in historyContainer.arrangedSubviews {
                if subview.accessibilityIdentifier == "history-placeholder" {
                    historyContainer.removeArrangedSubview(subview)
                    subview.removeFromSuperview()
                    break
                }
            }
        }
        
        // Append only new entries with smooth animation
        for (index, entry) in newEntries.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                let historyItemView = self.createHistoryItemView(
                    playerName: entry["playerName"] as? String ?? "?",
                    guess: entry["guess"] as? String ?? "?",
                    bulls: entry["bulls"] as? Int ?? 0,
                    cows: entry["cows"] as? Int ?? 0
                )
                
                // Smooth fade-in animation
                historyItemView.alpha = 0.0
                historyItemView.transform = CGAffineTransform(translationX: 0, y: 20)
                self.historyContainer.addArrangedSubview(historyItemView)
                
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                    historyItemView.alpha = 1.0
                    historyItemView.transform = CGAffineTransform.identity
                }
                
                print("📜 Appended: \(entry["guess"] as? String ?? "?") by \(entry["playerName"] as? String ?? "?")")
            }
        }
        
        // Update our tracking of displayed entries
        displayedHistoryEntries = newHistory
        
        // Auto-scroll to show new entries
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let scrollView = historyContainer.superview as? UIScrollView {
                let bottomOffset = CGPoint(x: 0, y: max(0, scrollView.contentSize.height - scrollView.bounds.height))
                scrollView.setContentOffset(bottomOffset, animated: true)
            }
        }
    }
    
    // 🎯 SMART DIFF: Find which entries are new
    private func findNewHistoryEntries(current: [[String: Any]], new: [[String: Any]]) -> [[String: Any]] {
        // If we have no current entries, all new entries are... new!
        if current.isEmpty {
            return new
        }
        
        // Compare based on content to find truly new entries
        var newEntries: [[String: Any]] = []
        
        for newEntry in new {
            let isExisting = current.contains { existingEntry in
                return isSameHistoryEntry(existingEntry, newEntry)
            }
            
            if !isExisting {
                newEntries.append(newEntry)
            }
        }
        
        return newEntries
    }
    
    // 🎯 ENTRY COMPARISON: Check if two history entries are the same
    private func isSameHistoryEntry(_ entry1: [String: Any], _ entry2: [String: Any]) -> Bool {
        let player1 = entry1["playerName"] as? String ?? ""
        let player2 = entry2["playerName"] as? String ?? ""
        let guess1 = entry1["guess"] as? String ?? ""
        let guess2 = entry2["guess"] as? String ?? ""
        let timestamp1 = entry1["timestamp"] as? String ?? ""
        let timestamp2 = entry2["timestamp"] as? String ?? ""
        
        return player1 == player2 && guess1 == guess2 && timestamp1 == timestamp2
    }
    
    func fetchGameHistory(completion: (() -> Void)? = nil) {
        // 🎯 First, show cached data immediately
        displayCachedDataIfAvailable()
        
        // Then silently fetch fresh data
        fetchGameHistoryWithSilentRetry { [weak self] success in
            if success {
                self?.trackNetworkSuccess()
            } else {
                self?.trackNetworkError()
            }
            completion?()
        }
    }
    
    private func fetchGameHistoryWithSilentRetry(completion: @escaping (Bool) -> Void) {
        guard !roomId.isEmpty, !playerId.isEmpty else { 
            completion(false)
            return 
        }
        
        let urlString = "\(baseURL)/game/history-local?roomId=\(roomId)&playerId=\(playerId)"
        guard let url = URL(string: urlString) else { 
            completion(false)
            return 
        }
        
        let requestStartTime = Date.timeIntervalSinceReferenceDate
        
        sharedURLSession.dataTask(with: url) { [weak self] data, response, error in
            let responseTime = (Date.timeIntervalSinceReferenceDate - requestStartTime) * 1000
            
            guard let self = self else { 
                completion(false)
                return
            }
            
            // Update performance metrics
            self.updatePerformanceMetrics(responseTime: responseTime, endpoint: "history-local")
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success,
               let history = json["history"] as? [[String: Any]] {
                
                // 🎯 Update cache
                self.cachedGameHistory = history
                self.lastHistorySync = Date.timeIntervalSinceReferenceDate
            
            DispatchQueue.main.async {
                    self.updateGameHistory(history)
                
                    // Silent win/lose handling (no disruptive dialogs)
                if let winner = json["winner"] as? [String: Any],
                   let winnerPlayerId = winner["playerId"] as? String {
                        self.handleGameEndSilently(winnerId: winnerPlayerId, winnerName: winner["playerName"] as? String)
                    }
                }
                completion(true)
            } else {
                // Silent failure - don't disrupt user experience
                print("🎯 History fetch failed silently")
                completion(false)
            }
        }.resume()
    }
    
    private func handleGameEndSilently(winnerId: String, winnerName: String?) {
        // Subtle game end handling without disruptive dialogs
        if winnerId == self.playerId {
            print("🎉 Game won silently")
            // Could add subtle celebration animation here
        } else {
            print("😔 Game lost silently")
            // Could add subtle feedback here
        }
        
        // Show subtle notification instead of modal dialog
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showSubtleGameEndNotification(winnerId: winnerId, winnerName: winnerName)
        }
    }
    
    private func showSubtleGameEndNotification(winnerId: String, winnerName: String?) {
        let isWin = winnerId == self.playerId
        let message = isWin ? "🎉 You won!" : "😔 \(winnerName ?? "Opponent") won"
        
        // Show as a temporary label instead of modal dialog
        let notificationLabel = UILabel()
        notificationLabel.text = message
        notificationLabel.textAlignment = .center
        notificationLabel.backgroundColor = isWin ? UIColor.systemGreen.withAlphaComponent(0.9) : UIColor.systemOrange.withAlphaComponent(0.9)
        notificationLabel.textColor = .white
        notificationLabel.font = UIFont.boldSystemFont(ofSize: 18)
        notificationLabel.layer.cornerRadius = 10
        notificationLabel.clipsToBounds = true
        
        view.addSubview(notificationLabel)
        notificationLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            notificationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            notificationLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            notificationLabel.heightAnchor.constraint(equalToConstant: 50),
            notificationLabel.widthAnchor.constraint(equalToConstant: 200)
        ])
        
        // Animate in and out
        notificationLabel.alpha = 0
        UIView.animate(withDuration: 0.3, animations: {
            notificationLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 3.0, animations: {
                notificationLabel.alpha = 0
            }) { _ in
                notificationLabel.removeFromSuperview()
            }
        }
    }
    
    private func processGameState(_ json: [String: Any]) {
        // Process room data from status-local endpoint with enhanced error handling
        guard let room = json["room"] as? [String: Any] else {
            print("❌ No room data in response")
            return
        }
        
        // Check for server-side validation issues
        if let validation = json["validation"] as? [String: Any],
           let isValid = validation["valid"] as? Bool, !isValid {
            let reason = validation["reason"] as? String ?? "Unknown validation error"
            print("⚠️ Server validation failed: \(reason)")
            
            // Show validation error to user but continue processing for recovery
            DispatchQueue.main.async { [weak self] in
                self?.showValidationError(reason)
            }
        }
        
        // Check for recovery suggestions
        if let suggestion = json["suggestion"] as? String {
            print("💡 Server suggestion: \(suggestion)")
        }
        
        // Check for next action guidance
        if let nextAction = json["nextAction"] as? String {
            print("➡️ Next action: \(nextAction)")
        }
        
        // Collect data without UI access first
        var shouldUpdateUI = false
        var shouldUpdateTurn = false
        var secretText = ""
        
        // Update game state with validation
        if let serverGameState = room["gameState"] as? String {
            if serverGameState != gameState {
                let oldState = gameState
                gameState = serverGameState
                shouldUpdateUI = true
                print("🎮 Game state changed: \(oldState) → \(serverGameState)")
                
                // Add state-specific feedback
                switch serverGameState {
                case "PLAYING":
                    print("🎯 Game is now active - ready for guesses!")
                case "WAITING":
                    print("⏳ Waiting for players to join")
                case "DIGIT_SELECTION":
                    print("🔢 Time to select number of digits")
                case "SECRET_SETTING":
                    print("🔐 Time to set secret numbers")
                case "FINISHED":
                    print("🏁 Game has ended")
                default:
                    break
                }
            }
        }
        
        // Update player info with better error handling
        if let players = room["players"] as? [[String: Any]] {
            for player in players {
                if let playerId = player["id"] as? String, playerId == self.playerId {
                    // Update digits
                    if let selectedDigits = player["selectedDigits"] as? Int, selectedDigits != self.digits {
                        self.digits = selectedDigits
                        shouldUpdateUI = true
                        print("🔢 Updated digits to: \(selectedDigits)")
                    }
                    
                    // Update secret (but protect player-set secrets)
                    if let secret = player["secret"] as? String, !secret.isEmpty {
                        // Only update if we don't have a secret yet, or if it's clearly player-set
                        if self.yourSecret.isEmpty {
                            // No secret yet, accept from server
                        self.yourSecret = secret
                        secretText = secret
                            shouldUpdateUI = true
                            print("🔐 Received secret from server: \(secret)")
                        } else if self.yourSecret != secret {
                            // We have a different secret - check if server one looks auto-generated
                            if isAutoGeneratedSecret(secret) {
                                print("⚠️ Ignoring auto-generated secret from server: \(secret), keeping player secret: \(self.yourSecret)")
                            } else if isValidPlayerSecret(secret, digits: self.digits) {
                                // Server secret looks valid and player-set, update it
                                print("🔄 Updating to new player secret: \(self.yourSecret) → \(secret)")
                                self.yourSecret = secret
                                secretText = secret
                                shouldUpdateUI = true
                            } else {
                                print("❌ Rejecting invalid secret from server: \(secret)")
                            }
                        }
                    }
                    break
                }
            }
        }
        
        // Enhanced turn management with validation
        if let serverCurrentTurn = room["currentTurn"] as? String {
            if serverCurrentTurn != currentTurn {
                let oldTurn = currentTurn
                print("🔄 Turn changed: '\(oldTurn)' → '\(serverCurrentTurn)'")
                currentTurn = serverCurrentTurn
                isMyTurn = (currentTurn == playerId)
                shouldUpdateTurn = true
                shouldUpdateUI = true
                
                // Add turn feedback
                if isMyTurn {
                    print("✅ It's YOUR turn!")
        } else {
                    print("⏳ Waiting for opponent's turn")
                }
            }
        }
        
        // Process any additional metadata
        if let serverTime = json["serverTime"] as? TimeInterval {
            let localTime = Date().timeIntervalSince1970 * 1000
            let timeDiff = abs(localTime - serverTime)
            if timeDiff > 5000 { // 5 seconds
                print("⏰ Time drift detected: \(timeDiff)ms")
            }
        }
        
        // Apply all UI updates in a single batch on main thread
        if shouldUpdateUI || shouldUpdateTurn {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if shouldUpdateUI {
                    // Update secret label if we have secret text
            if !secretText.isEmpty {
                        self.secretLabel.text = "🔐 SECURITY CODE: \(secretText)"
                    }
                }
                
            if shouldUpdateTurn {
                self.updateTurnUI()
                    // Reschedule polling with new turn-aware interval
                    self.scheduleSmartPolling()
                }
                
                // Update keypad state
                self.updateKeypadButtonsState()
            }
        }
        
        // Fetch history if we're in playing state for real-time updates
        if gameState == "PLAYING" {
            // 🎯 HISTORY IS NOW MANUAL ONLY - No auto-refresh to prevent flickering
            // fetchGameHistory() // Disabled - user controls via refresh button
        }
    }
    
    private func updateGameHistory(_ history: [[String: Any]]) {
        // More sensitive comparison using actual content
        let historySignature = createHistorySignature(history)
        
        // Only update UI if history actually changed
        guard historySignature != lastHistoryHash else {
            print("📜 History unchanged, skipping UI update")
            return
        }
        
        print("📜 History changed: \(lastHistoryHash) → \(historySignature)")
        lastHistoryHash = historySignature
        
        // Safely update history on main thread
        DispatchQueue.main.async {
            guard let historyContainer = self.historyContainer else {
                print("⚠️ History container not initialized")
                return
            }
            
            // Always rebuild for reliability (optimize later if needed)
            self.rebuildHistoryView(with: history, container: historyContainer)
        }
    }
    
    private func createHistorySignature(_ history: [[String: Any]]) -> Int {
        // Create more detailed signature including content and order
        var signature = ""
        
        for (index, entry) in history.enumerated() {
            signature += "\(index):"
            signature += (entry["playerName"] as? String ?? "") + "|"
            signature += (entry["guess"] as? String ?? "") + "|"
            signature += "\(entry["bulls"] as? Int ?? 0)" + "|"
            signature += "\(entry["cows"] as? Int ?? 0)" + "|"
            signature += (entry["timestamp"] as? String ?? "") + ";"
        }
        
        return signature.hashValue
    }
    
    private func rebuildHistoryView(with history: [[String: Any]], container: UIStackView) {
                // Remove existing views safely
        for subview in container.arrangedSubviews {
            container.removeArrangedSubview(subview)
                    subview.removeFromSuperview()
                }
                
                if history.isEmpty {
                    // Add placeholder if no history
                    let placeholderView = self.createPlaceholderView()
            container.addArrangedSubview(placeholderView)
            print("📜 Added placeholder - no game history yet")
                } else {
            // Add new entries in order
            for (index, entry) in history.enumerated() {
                        self.addHistoryEntry(entry)
                print("📜 Added history entry \(index + 1): \(entry["guess"] as? String ?? "?") by \(entry["playerName"] as? String ?? "?")")
            }
        }
        
        print("📜 History view rebuilt with \(history.count) entries")
        
        // Auto-scroll to bottom to show latest moves
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let scrollView = container.superview as? UIScrollView {
                let bottomOffset = CGPoint(x: 0, y: max(0, scrollView.contentSize.height - scrollView.bounds.height))
                scrollView.setContentOffset(bottomOffset, animated: true)
            }
        }
    }
    
    // Note: showLoseDialogNetwork replaced with silent handling in handleGameEndSilently
    
    // MARK: - Secret Protection Helpers
    private func isAutoGeneratedSecret(_ secret: String) -> Bool {
        // Auto-generated secrets from server tend to have certain patterns
        // 1. Often start with higher digits (due to hash + 1000)
        // 2. May have patterns that are unlikely for humans to choose
        
        guard secret.count >= 3 else { return false }
        
        // Check if secret starts with high digits (common in auto-generation)
        if secret.hasPrefix("1") || secret.hasPrefix("2") || secret.hasPrefix("3") {
            // Further check for patterns typical of hash-based generation
            let digits = secret.compactMap { Int(String($0)) }
            
            // Auto-generated often have large jumps between consecutive digits
            for i in 0..<digits.count-1 {
                let diff = abs(digits[i] - digits[i+1])
                if diff >= 5 { // Large jump suggests auto-generation
                    return true
                }
            }
        }
        
        // Check for specific patterns that our generateDeterministicSecret creates
        // (4-digit numbers starting from 1000-9999 range)
        if secret.count == 4, let number = Int(secret) {
            return number >= 1000 && number <= 9999
        }
        
        return false
    }
    
    private func isValidPlayerSecret(_ secret: String, digits: Int) -> Bool {
        // Check if secret looks like something a player would set
        guard secret.count == digits else { return false }
        guard secret.allSatisfy({ $0.isNumber }) else { return false }
        
        // Check for unique digits
        let uniqueDigits = Set(secret)
        guard uniqueDigits.count == secret.count else { return false }
        
        // Player-set secrets often have simpler patterns
        // Like: 1234, 5678, 1357, etc.
        return true
    }
    
    private func showValidationError(_ reason: String) {
        // Show a subtle, non-blocking error indicator
        let errorView = UIView()
        errorView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        errorView.layer.cornerRadius = 8
        errorView.translatesAutoresizingMaskIntoConstraints = false
        
        let errorLabel = UILabel()
        errorLabel.text = "⚠️ \(reason)"
        errorLabel.font = UIFont.systemFont(ofSize: 12)
        errorLabel.textColor = UIColor.systemRed
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        errorView.addSubview(errorLabel)
        view.addSubview(errorView)
        
        NSLayoutConstraint.activate([
            errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            errorView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            errorView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            
            errorLabel.topAnchor.constraint(equalTo: errorView.topAnchor, constant: 8),
            errorLabel.bottomAnchor.constraint(equalTo: errorView.bottomAnchor, constant: -8),
            errorLabel.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 12),
            errorLabel.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -12)
        ])
        
        // Auto-remove after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            errorView.removeFromSuperview()
        }
    }
    
    // MARK: - Vercel Serverless Specific Handlers
    
    private func processVercelMetrics(json: [String: Any], responseTime: Double) {
        // Extract Vercel-specific metrics
        if let room = json["room"] as? [String: Any],
           let serverless = room["serverless"] as? [String: Any] {
            
            let platform = serverless["platform"] as? String ?? "unknown"
            let coldStart = serverless["coldStart"] as? Bool ?? false
            let region = serverless["region"] as? String ?? "unknown"
            
            print("📊 Vercel Metrics - Platform: \(platform), Cold Start: \(coldStart), Region: \(region), Response: \(Int(responseTime))ms")
            
            // Adjust polling based on performance
            if coldStart || responseTime > 5000 {
                print("⚡ Vercel cold start detected, adjusting polling strategy")
                DispatchQueue.main.async { [weak self] in
                    self?.adjustPollingForColdStart()
                }
            }
            
            // Check for performance warnings
            if let performance = json["performance"] as? [String: Any],
               let warning = performance["warning"] as? String {
                print("⚠️ Vercel performance warning:", warning)
                
                DispatchQueue.main.async { [weak self] in
                    self?.handlePerformanceWarning(warning)
                }
            }
        }
        
        // Check for serverless recovery indicators
        if let recovery = json["recovery"] as? [String: Any],
           let detected = recovery["detected"] as? Bool, detected {
            print("🔄 Vercel serverless recovery detected")
            
            DispatchQueue.main.async { [weak self] in
                self?.showServerlessRecoveryMessage()
            }
        }
    }
    
    private func handleVercelError(error: Error, responseTime: Double) {
        // Check for timeout errors (common with cold starts)
        if (error as NSError).code == NSURLErrorTimedOut {
            print("⏰ Vercel timeout detected (likely cold start)")
            handleVercelColdStart(responseTime: responseTime)
            } else {
            print("❌ Vercel network error:", error.localizedDescription)
        }
    }
    
    private func handleVercelColdStart(responseTime: Double) {
        print("🥶 Handling Vercel cold start (response: \(Int(responseTime))ms)")
        
        // Increase retry delay for cold starts
        retryCount += 1
        
        if retryCount >= maxRetries {
            print("🔥 Warming Vercel functions")
            
            // Try to warm up the function
            warmVercelFunctions { [weak self] in
                self?.retryCount = 0
                self?.scheduleSmartPolling()
            }
        }
    }
    
    private func adjustPollingForColdStart() {
        // Temporarily slow down polling to let Vercel functions warm up
        gameTimer?.invalidate()
        
        let baseInterval: TimeInterval = isMyTurn ? 5.0 : 2.0  // Slower for cold starts
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: baseInterval, repeats: true) { [weak self] _ in
            self?.fetchGameStateWithRetry()
        }
        
        print("❄️ Adjusted polling for Vercel cold start: \(baseInterval)s")
        
        // Return to normal polling after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            self?.scheduleSmartPolling()
            print("🔥 Resumed normal polling after Vercel warm-up")
        }
    }
    
    private func warmVercelFunctions(completion: @escaping () -> Void) {
        print("🔥 Warming Vercel functions...")
        
        guard let url = URL(string: "\(baseURL)/health?warm=true") else {
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30.0 // Long timeout for warming
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Function warming failed:", error.localizedDescription)
            } else {
                print("✅ Vercel functions warmed")
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }.resume()
    }
    
    private func handlePerformanceWarning(_ warning: String) {
        // Show subtle warning to user
        let warningLabel = UILabel()
        warningLabel.text = "⚡ Optimizing connection..."
        warningLabel.font = UIFont.systemFont(ofSize: 11)
        warningLabel.textColor = UIColor.systemYellow
        warningLabel.textAlignment = .center
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(warningLabel)
        NSLayoutConstraint.activate([
            warningLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            warningLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        // Auto-remove after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            warningLabel.removeFromSuperview()
        }
    }
    
    private func showServerlessRecoveryMessage() {
        let recoveryLabel = UILabel()
        recoveryLabel.text = "🔄 Game state recovered"
        recoveryLabel.font = UIFont.systemFont(ofSize: 11)
        recoveryLabel.textColor = UIColor.systemGreen
        recoveryLabel.textAlignment = .center
        recoveryLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(recoveryLabel)
        NSLayoutConstraint.activate([
            recoveryLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 70),
            recoveryLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        // Auto-remove after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            recoveryLabel.removeFromSuperview()
        }
    }
    
    // MARK: - 🎯 Request Prioritization
    
    func prioritizeRequest(type: String, completion: @escaping () -> Void) {
        // High priority requests (user actions)
        let highPriorityTypes = ["guess", "setSecret", "selectDigit", "manualRefresh"]
        
        if highPriorityTypes.contains(type) {
            isProcessingHighPriority = true
            
            // Execute immediately
            completion()
            
            // Reset high priority flag after completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isProcessingHighPriority = false
            }
        } else {
            // Low priority requests (polling)
            if !isProcessingHighPriority {
                completion()
            } else {
                // Queue the request
                requestQueue.append(type)
                print("🎯 Queued \(type) request (high priority in progress)")
                
                // Process queue after high priority completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.processRequestQueue()
                }
            }
        }
    }
    
    private func processRequestQueue() {
        guard !isProcessingHighPriority && !requestQueue.isEmpty else { return }
        
        let nextRequest = requestQueue.removeFirst()
        print("🎯 Processing queued request: \(nextRequest)")
        
        switch nextRequest {
        case "quickCheck":
            quickStateCheckWithSilentRetry()
        case "gameState":
            fetchGameStateWithSilentRetry()
        case "history":
            // 🎯 HISTORY IS NOW MANUAL ONLY - No auto-refresh to prevent flickering
            // fetchGameHistory() // Disabled - user controls via refresh button
            print("🎯 History request skipped - manual only")
        default:
            print("🎯 Unknown queued request type: \(nextRequest)")
        }
    }
    
    // MARK: - 🎯 Enhanced Cache Management
    
    private func validateCache() -> Bool {
        let now = Date.timeIntervalSinceReferenceDate
        let lastUpdate = lastHistorySync
        let cacheAgeLimit: TimeInterval = 30.0 // 30 seconds
        
        let isValid = (now - lastUpdate) < cacheAgeLimit && !cachedGameHistory.isEmpty
        
        if !isValid {
            print("🎯 Cache invalid: age=\(Int(now - lastUpdate))s, empty=\(cachedGameHistory.isEmpty)")
        }
        
        return isValid
    }
    
    private func smartCacheSync() {
        // Only sync if cache is getting stale
        if !validateCache() {
            print("🎯 Performing smart cache sync")
            fetchGameHistoryWithSilentRetry { [weak self] success in
                if success {
                    print("🎯 Cache refreshed successfully")
                } else {
                    print("🎯 Cache refresh failed, using stale data")
                }
            }
        } else {
            print("🎯 Cache still fresh, skipping sync")
        }
    }
    
    private func optimizePollingFrequency() {
        let successRate = networkHealth["successRate"] as? Double ?? 1.0
        let consecutiveErrors = networkHealth["consecutiveErrors"] as? Int ?? 0
        let gameLength = historyStackView.arrangedSubviews.count
        
        var newInterval: TimeInterval = 0.5
        
        // Base interval on success rate
        if successRate > 0.9 {
            newInterval = 0.3 // Very responsive when connection is excellent
        } else if successRate > 0.7 {
            newInterval = 0.8 // Moderate when connection is good
        } else {
            newInterval = 2.0 // Conservative when connection is poor
        }
        
        // Adjust for consecutive errors
        if consecutiveErrors > 3 {
            newInterval *= 2.0
        }
        
        // Adjust for game length (longer games need less frequent polling)
        if gameLength > 20 {
            newInterval *= 1.5
        }
        if gameLength > 40 {
            newInterval *= 2.0
        }
        
        // Apply limits
        newInterval = max(0.2, min(5.0, newInterval))
        
        adaptivePollingConfig["currentInterval"] = newInterval
        print("🎯 Optimized polling frequency: \(newInterval)s (success: \(successRate), errors: \(consecutiveErrors), length: \(gameLength))")
    }
}
