import UIKit
import AudioToolbox

protocol RoomListDelegate: AnyObject {
    func roomListDidSelectRoom(_ roomCode: String)
    func roomListDidCancel()
}

class RoomListViewController: UIViewController {
    
    // MARK: - Properties
    weak var delegate: RoomListDelegate?
    private var gameClient: GameClient!
    private var availableRooms: [AvailableRoom] = []
    private var refreshTimer: Timer?
    
    // MARK: - UI Components
    private let backgroundView = UIView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let refreshButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let roomsTableView = UITableView()
    private let emptyStateView = UIView()
    private let emptyStateLabel = UILabel()
    
    // MARK: - Initialization
    init(gameClient: GameClient) {
        self.gameClient = gameClient
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGameClient()
        requestRoomList()
        startAutoRefresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopAutoRefresh()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateGradientFrame()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .systemBackground
        setupBackground()
        setupContentView()
        setupTitleSection()
        setupTableView()
        setupEmptyState()
        setupConstraints()
        animateEntrance()
    }
    
    private func setupBackground() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemBlue.withAlphaComponent(0.8).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.6).cgColor,
            UIColor.systemIndigo.withAlphaComponent(0.8).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        backgroundView.layer.addSublayer(gradientLayer)
    }
    
    private func updateGradientFrame() {
        if let gradientLayer = backgroundView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = backgroundView.bounds
        }
    }
    
    private func setupContentView() {
        contentView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        contentView.layer.cornerRadius = 20
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
    }
    
    private func setupTitleSection() {
        titleLabel.text = "🏠 Available Rooms"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        subtitleLabel.text = "Select a room to join"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
        // Refresh button
        refreshButton.setTitle("🔄 Refresh", for: .normal)
        refreshButton.setTitleColor(.systemCyan, for: .normal)
        refreshButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(refreshButton)
        
        // Cancel button
        cancelButton.setTitle("❌ Cancel", for: .normal)
        cancelButton.setTitleColor(.systemRed, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancelButton)
    }
    
    private func setupTableView() {
        roomsTableView.delegate = self
        roomsTableView.dataSource = self
        roomsTableView.backgroundColor = .clear
        roomsTableView.separatorStyle = .none
        roomsTableView.showsVerticalScrollIndicator = false
        roomsTableView.register(RoomTableViewCell.self, forCellReuseIdentifier: "RoomCell")
        roomsTableView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(roomsTableView)
    }
    
    private func setupEmptyState() {
        emptyStateView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        emptyStateView.layer.cornerRadius = 12
        emptyStateView.isHidden = true
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(emptyStateView)
        
        emptyStateLabel.text = "😔 No rooms available\n\nCreate a new room or try refreshing"
        emptyStateLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        emptyStateLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(emptyStateLabel)
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            // Background
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 40),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -40),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Buttons
            refreshButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            refreshButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            cancelButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            cancelButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Table view
            roomsTableView.topAnchor.constraint(equalTo: refreshButton.bottomAnchor, constant: 20),
            roomsTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            roomsTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            roomsTableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // Empty state
            emptyStateView.centerXAnchor.constraint(equalTo: roomsTableView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: roomsTableView.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalTo: roomsTableView.widthAnchor, multiplier: 0.8),
            emptyStateView.heightAnchor.constraint(equalToConstant: 120),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 16),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -16)
        ])
    }
    
    private func setupGameClient() {
        gameClient.delegate = self
    }
    
    // MARK: - Auto Refresh
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.requestRoomList()
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Actions
    @objc private func refreshTapped() {
        addButtonPressEffect(to: refreshButton)
        requestRoomList()
    }
    
    @objc private func cancelTapped() {
        addButtonPressEffect(to: cancelButton)
        delegate?.roomListDidCancel()
    }
    
    private func requestRoomList() {
        gameClient.requestAvailableRooms()
    }
    
    // MARK: - Helper Methods
    private func updateEmptyState() {
        let isEmpty = availableRooms.isEmpty
        emptyStateView.isHidden = !isEmpty
        roomsTableView.isHidden = isEmpty
    }
    
    private func animateEntrance() {
        contentView.alpha = 0
        contentView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [], animations: {
            self.contentView.alpha = 1
            self.contentView.transform = .identity
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
    }
}

// MARK: - TableView DataSource & Delegate
extension RoomListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableRooms.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RoomCell", for: indexPath) as! RoomTableViewCell
        let room = availableRooms[indexPath.row]
        cell.configure(with: room)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let room = availableRooms[indexPath.row]
        
        // Check if room is full or game started
        if room.isGameStarted {
            showAlert(title: "Game Started", message: "This room's game has already started. Please choose another room.")
            return
        }
        
        if room.playerCount >= room.maxPlayers {
            showAlert(title: "Room Full", message: "This room is full. Please choose another room.")
            return
        }
        
        // Add selection effect
        if let cell = tableView.cellForRow(at: indexPath) as? RoomTableViewCell {
            cell.addSelectionEffect()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.delegate?.roomListDidSelectRoom(room.code)
        }
    }
}

// MARK: - GameClientDelegate
extension RoomListViewController: GameClientDelegate {
    func gameClient(_ client: GameClient, didReceiveRoomList rooms: [AvailableRoom]) {
        self.availableRooms = rooms
        DispatchQueue.main.async {
            self.roomsTableView.reloadData()
            self.updateEmptyState()
        }
    }
    
    func gameClient(_ client: GameClient, didReceiveRoomState state: RoomState) {
        // Not needed for room list
    }
    
    func gameClient(_ client: GameClient, didReceiveError error: String) {
        DispatchQueue.main.async {
            self.showAlert(title: "Error", message: error)
        }
    }
    
    func gameClient(_ client: GameClient, gameDidStart: Bool) {
        // Not needed for room list
    }
    
    func gameClient(_ client: GameClient, didReceiveMoveResult result: MoveResult) {
        // Not needed for room list
    }
    
    func gameClient(_ client: GameClient, gameDidEnd winner: String, secret: String) {
        // Not needed for room list
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}