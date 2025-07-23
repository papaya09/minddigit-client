import UIKit

class RoomTableViewCell: UITableViewCell {
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let roomCodeLabel = UILabel()
    private let hostInfoLabel = UILabel()
    private let gameModeLabel = UILabel()
    private let playerCountLabel = UILabel()
    private let statusLabel = UILabel()
    private let joinIndicatorView = UIView()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        setupContainerView()
        setupLabels()
        setupConstraints()
    }
    
    private func setupContainerView() {
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        containerView.layer.cornerRadius = 12
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Join indicator
        joinIndicatorView.backgroundColor = UIColor.systemGreen
        joinIndicatorView.layer.cornerRadius = 3
        joinIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(joinIndicatorView)
    }
    
    private func setupLabels() {
        // Room code
        roomCodeLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        roomCodeLabel.textColor = .systemYellow
        roomCodeLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(roomCodeLabel)
        
        // Host info
        hostInfoLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        hostInfoLabel.textColor = .white
        hostInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostInfoLabel)
        
        // Game mode
        gameModeLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        gameModeLabel.textColor = .systemCyan
        gameModeLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(gameModeLabel)
        
        // Player count
        playerCountLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        playerCountLabel.textColor = .systemOrange
        playerCountLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(playerCountLabel)
        
        // Status
        statusLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = .systemGreen
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(statusLabel)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            // Join indicator
            joinIndicatorView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            joinIndicatorView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            joinIndicatorView.widthAnchor.constraint(equalToConstant: 6),
            joinIndicatorView.heightAnchor.constraint(equalToConstant: 6),
            
            // Room code
            roomCodeLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            roomCodeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            
            // Host info
            hostInfoLabel.topAnchor.constraint(equalTo: roomCodeLabel.bottomAnchor, constant: 4),
            hostInfoLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            hostInfoLabel.trailingAnchor.constraint(equalTo: joinIndicatorView.leadingAnchor, constant: -8),
            
            // Game mode
            gameModeLabel.topAnchor.constraint(equalTo: hostInfoLabel.bottomAnchor, constant: 4),
            gameModeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            
            // Player count
            playerCountLabel.topAnchor.constraint(equalTo: hostInfoLabel.bottomAnchor, constant: 4),
            playerCountLabel.leadingAnchor.constraint(equalTo: gameModeLabel.trailingAnchor, constant: 12),
            
            // Status
            statusLabel.topAnchor.constraint(equalTo: hostInfoLabel.bottomAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8)
        ])
    }
    
    // MARK: - Configuration
    func configure(with room: AvailableRoom) {
        roomCodeLabel.text = "🏠 Room: \(room.code)"
        hostInfoLabel.text = "\(room.hostAvatar) Host: \(room.hostName)"
        gameModeLabel.text = "🎮 \(room.gameMode)"
        playerCountLabel.text = "👥 \(room.playerCount)/\(room.maxPlayers)"
        
        // Update status and appearance based on room state
        if room.isGameStarted {
            statusLabel.text = "🎯 Playing"
            statusLabel.textColor = .systemRed
            joinIndicatorView.backgroundColor = .systemRed
            containerView.alpha = 0.7
        } else if room.playerCount >= room.maxPlayers {
            statusLabel.text = "🚫 Full"
            statusLabel.textColor = .systemOrange
            joinIndicatorView.backgroundColor = .systemOrange
            containerView.alpha = 0.8
        } else {
            statusLabel.text = "✅ Join"
            statusLabel.textColor = .systemGreen
            joinIndicatorView.backgroundColor = .systemGreen
            containerView.alpha = 1.0
        }
    }
    
    // MARK: - Animation
    func addSelectionEffect() {
        UIView.animate(withDuration: 0.1, animations: {
            self.containerView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            self.containerView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.containerView.transform = .identity
            }
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        containerView.alpha = 1.0
    }
}