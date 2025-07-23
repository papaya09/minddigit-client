import UIKit
import AudioToolbox

class CharacterCreationViewController: UIViewController {
    
    // MARK: - Properties
    private let gameStateManager = GameStateManager.shared
    private let isEditingMode: Bool
    
    // MARK: - UI Components
    private let backgroundView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // Character Preview Section
    private let characterPreviewCard = UIView()
    private let avatarLabel = UILabel()
    private let characterNamePreview = UILabel()
    
    // Avatar Selection Section
    private let avatarSectionCard = UIView()
    private let avatarSectionTitle = UILabel()
    private var avatarButtons: [UIButton] = []
    
    // Name Input Section
    private let nameSectionCard = UIView()
    private let nameSectionTitle = UILabel()
    private let nameTextField = UITextField()
    
    // Skills Selection Section
    private let skillsSectionCard = UIView()
    private let skillsSectionTitle = UILabel()
    private let skillsStackView = UIStackView()
    
    private let continueButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    // Character data
    private var selectedAvatar = "👤"
    private var selectedSkills: [String] = []
    
    private let availableAvatars = ["👤", "🧑‍💻", "👩‍🚀", "🧙‍♂️", "🦸‍♀️", "🥷", "👑", "🤖"]
    private let availableSkills = [
        ("🎯", "Precision", "ความแม่นยำในการทาย"),
        ("⚡", "Speed", "ความเร็วในการคิด"),
        ("🧠", "Logic", "ความสามารถในการวิเคราะห์"),
        ("🍀", "Lucky", "โชคที่ดีในเกม")
    ]
    
    // MARK: - Initialization
    init(isEditingMode: Bool = false) {
        self.isEditingMode = isEditingMode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadExistingCharacterData()
        updateCharacterPreview()
        setupAnimations()
        setupKeyboardDismissal()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateGradientFrame()
    }
    
    private func setupKeyboardDismissal() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .systemBackground
        setupBackground()
        setupScrollView()
        setupTitleSection()
        setupCharacterPreview()
        setupAvatarSelection()
        setupNameInput()
        setupSkillsSelection()
        setupContinueButton()
        if isEditingMode {
            setupCancelButton()
        }
        setupConstraints()
    }
    
    private func setupBackground() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0).cgColor,
            UIColor(red: 0.2, green: 0.1, blue: 0.4, alpha: 1.0).cgColor,
            UIColor(red: 0.1, green: 0.2, blue: 0.5, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        backgroundView.layer.addSublayer(gradientLayer)
    }
    
    private func updateGradientFrame() {
        if let gradientLayer = backgroundView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = backgroundView.bounds
        }
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .automatic
        view.addSubview(scrollView)
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
    }
    
    private func setupTitleSection() {
        titleLabel.text = isEditingMode ? "แก้ไขตัวละคร" : "สร้างตัวละคร"
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowOpacity = 0.5
        titleLabel.layer.shadowRadius = 4
        
        contentView.addSubview(titleLabel)
        
        subtitleLabel.text = isEditingMode ? "ปรับปรุงข้อมูลตัวละครของคุณ" : "ปรับแต่งตัวละครของคุณ"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
    }
    
    private func setupCharacterPreview() {
        characterPreviewCard.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        characterPreviewCard.layer.cornerRadius = 20
        characterPreviewCard.layer.borderWidth = 1
        characterPreviewCard.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        characterPreviewCard.layer.shadowColor = UIColor.black.cgColor
        characterPreviewCard.layer.shadowOffset = CGSize(width: 0, height: 4)
        characterPreviewCard.layer.shadowOpacity = 0.3
        characterPreviewCard.layer.shadowRadius = 8
        characterPreviewCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(characterPreviewCard)
        
        avatarLabel.text = selectedAvatar
        avatarLabel.font = UIFont.systemFont(ofSize: 64)
        avatarLabel.textAlignment = .center
        avatarLabel.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        avatarLabel.layer.cornerRadius = 40
        avatarLabel.layer.masksToBounds = true
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        characterPreviewCard.addSubview(avatarLabel)
        
        characterNamePreview.text = "ชื่อของคุณ"
        characterNamePreview.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        characterNamePreview.textColor = .white
        characterNamePreview.textAlignment = .center
        characterNamePreview.translatesAutoresizingMaskIntoConstraints = false
        characterPreviewCard.addSubview(characterNamePreview)
    }
    
    private func setupAvatarSelection() {
        avatarSectionCard.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        avatarSectionCard.layer.cornerRadius = 16
        avatarSectionCard.layer.borderWidth = 1
        avatarSectionCard.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        avatarSectionCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatarSectionCard)
        
        avatarSectionTitle.text = "👤 เลือกอวตาร"
        avatarSectionTitle.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        avatarSectionTitle.textColor = .white
        avatarSectionTitle.translatesAutoresizingMaskIntoConstraints = false
        avatarSectionCard.addSubview(avatarSectionTitle)
        
        let avatarStackView = UIStackView()
        avatarStackView.axis = .horizontal
        avatarStackView.distribution = .fillEqually
        avatarStackView.spacing = 8
        avatarStackView.translatesAutoresizingMaskIntoConstraints = false
        avatarSectionCard.addSubview(avatarStackView)
        
        // Create two rows of avatar buttons
        let topRowStack = UIStackView()
        topRowStack.axis = .horizontal
        topRowStack.distribution = .fillEqually
        topRowStack.spacing = 8
        
        let bottomRowStack = UIStackView()
        bottomRowStack.axis = .horizontal
        bottomRowStack.distribution = .fillEqually
        bottomRowStack.spacing = 8
        
        for (index, avatar) in availableAvatars.enumerated() {
            let button = createAvatarButton(avatar: avatar, index: index)
            avatarButtons.append(button)
            
            if index < 4 {
                topRowStack.addArrangedSubview(button)
            } else {
                bottomRowStack.addArrangedSubview(button)
            }
        }
        
        avatarStackView.axis = .vertical
        avatarStackView.spacing = 12
        avatarStackView.addArrangedSubview(topRowStack)
        avatarStackView.addArrangedSubview(bottomRowStack)
        
        NSLayoutConstraint.activate([
            avatarSectionTitle.topAnchor.constraint(equalTo: avatarSectionCard.topAnchor, constant: 16),
            avatarSectionTitle.leadingAnchor.constraint(equalTo: avatarSectionCard.leadingAnchor, constant: 20),
            avatarSectionTitle.trailingAnchor.constraint(equalTo: avatarSectionCard.trailingAnchor, constant: -20),
            
            avatarStackView.topAnchor.constraint(equalTo: avatarSectionTitle.bottomAnchor, constant: 16),
            avatarStackView.leadingAnchor.constraint(equalTo: avatarSectionCard.leadingAnchor, constant: 20),
            avatarStackView.trailingAnchor.constraint(equalTo: avatarSectionCard.trailingAnchor, constant: -20),
            avatarStackView.bottomAnchor.constraint(equalTo: avatarSectionCard.bottomAnchor, constant: -16),
            
            topRowStack.heightAnchor.constraint(equalToConstant: 50),
            bottomRowStack.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        updateSelectedAvatar(0)
    }
    
    private func createAvatarButton(avatar: String, index: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(avatar, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        button.layer.cornerRadius = 25
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        button.tag = index
        button.addTarget(self, action: #selector(avatarSelected(_:)), for: .touchUpInside)
        
        return button
    }
    
    private func setupNameInput() {
        nameSectionCard.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        nameSectionCard.layer.cornerRadius = 16
        nameSectionCard.layer.borderWidth = 1
        nameSectionCard.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        nameSectionCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameSectionCard)
        
        nameSectionTitle.text = "✏️ ชื่อตัวละคร"
        nameSectionTitle.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        nameSectionTitle.textColor = .white
        nameSectionTitle.translatesAutoresizingMaskIntoConstraints = false
        nameSectionCard.addSubview(nameSectionTitle)
        
        nameTextField.placeholder = "ใส่ชื่อของคุณ..."
        nameTextField.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        nameTextField.textColor = .white
        nameTextField.textAlignment = .left
        nameTextField.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        nameTextField.layer.cornerRadius = 12
        nameTextField.layer.borderWidth = 1
        nameTextField.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        nameTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 40))
        nameTextField.leftViewMode = .always
        nameTextField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 40))
        nameTextField.rightViewMode = .always
        nameTextField.attributedPlaceholder = NSAttributedString(
            string: "ใส่ชื่อของคุณ...",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.6)]
        )
        nameTextField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        nameTextField.delegate = self
        nameTextField.returnKeyType = .done
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameSectionCard.addSubview(nameTextField)
        
        NSLayoutConstraint.activate([
            nameSectionTitle.topAnchor.constraint(equalTo: nameSectionCard.topAnchor, constant: 16),
            nameSectionTitle.leadingAnchor.constraint(equalTo: nameSectionCard.leadingAnchor, constant: 20),
            nameSectionTitle.trailingAnchor.constraint(equalTo: nameSectionCard.trailingAnchor, constant: -20),
            
            nameTextField.topAnchor.constraint(equalTo: nameSectionTitle.bottomAnchor, constant: 12),
            nameTextField.leadingAnchor.constraint(equalTo: nameSectionCard.leadingAnchor, constant: 20),
            nameTextField.trailingAnchor.constraint(equalTo: nameSectionCard.trailingAnchor, constant: -20),
            nameTextField.bottomAnchor.constraint(equalTo: nameSectionCard.bottomAnchor, constant: -16),
            nameTextField.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    private func setupSkillsSelection() {
        skillsSectionCard.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        skillsSectionCard.layer.cornerRadius = 16
        skillsSectionCard.layer.borderWidth = 1
        skillsSectionCard.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        skillsSectionCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(skillsSectionCard)
        
        skillsSectionTitle.text = "🎯 เลือกทักษะ\n(สูงสุด 2 ทักษะ)"
        skillsSectionTitle.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        skillsSectionTitle.textColor = .white
        skillsSectionTitle.numberOfLines = 0
        skillsSectionTitle.textAlignment = .center
        skillsSectionTitle.translatesAutoresizingMaskIntoConstraints = false
        skillsSectionCard.addSubview(skillsSectionTitle)
        
        skillsStackView.axis = .vertical
        skillsStackView.spacing = 12
        skillsStackView.translatesAutoresizingMaskIntoConstraints = false
        skillsSectionCard.addSubview(skillsStackView)
        
        for (emoji, name, description) in availableSkills {
            let skillButton = createSkillButton(emoji: emoji, name: name, description: description)
            skillsStackView.addArrangedSubview(skillButton)
        }
        
        NSLayoutConstraint.activate([
            skillsSectionTitle.topAnchor.constraint(equalTo: skillsSectionCard.topAnchor, constant: 16),
            skillsSectionTitle.leadingAnchor.constraint(equalTo: skillsSectionCard.leadingAnchor, constant: 20),
            skillsSectionTitle.trailingAnchor.constraint(equalTo: skillsSectionCard.trailingAnchor, constant: -20),
            
            skillsStackView.topAnchor.constraint(equalTo: skillsSectionTitle.bottomAnchor, constant: 16),
            skillsStackView.leadingAnchor.constraint(equalTo: skillsSectionCard.leadingAnchor, constant: 20),
            skillsStackView.trailingAnchor.constraint(equalTo: skillsSectionCard.trailingAnchor, constant: -20),
            skillsStackView.bottomAnchor.constraint(equalTo: skillsSectionCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func createSkillButton(emoji: String, name: String, description: String) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        
        let titleText = "\(emoji) \(name)"
        let subtitleText = description
        
        let attributedString = NSMutableAttributedString()
        attributedString.append(NSAttributedString(string: titleText, attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: UIColor.white
        ]))
        attributedString.append(NSAttributedString(string: "\n\(subtitleText)", attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(0.8)
        ]))
        
        button.setAttributedTitle(attributedString, for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.addTarget(self, action: #selector(skillSelected(_:)), for: .touchUpInside)
        
        return button
    }
    
    private func setupContinueButton() {
        let buttonTitle = isEditingMode ? "💾 บันทึกการแก้ไข" : "🚀 เริ่มเล่นเกม"
        continueButton.setTitle(buttonTitle, for: .normal)
        continueButton.backgroundColor = UIColor.systemGreen
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        continueButton.layer.cornerRadius = 25
        continueButton.layer.shadowColor = UIColor.black.cgColor
        continueButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        continueButton.layer.shadowOpacity = 0.3
        continueButton.layer.shadowRadius = 8
        
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(continueButton)
    }
    
    private func setupCancelButton() {
        cancelButton.setTitle("❌ ยกเลิก", for: .normal)
        cancelButton.backgroundColor = UIColor.systemRed
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        cancelButton.layer.cornerRadius = 25
        cancelButton.layer.shadowColor = UIColor.black.cgColor
        cancelButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        cancelButton.layer.shadowOpacity = 0.3
        cancelButton.layer.shadowRadius = 8
        
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancelButton)
    }
    
    private func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            // Background
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Character preview card
            characterPreviewCard.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            characterPreviewCard.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            characterPreviewCard.widthAnchor.constraint(equalToConstant: 200),
            characterPreviewCard.heightAnchor.constraint(equalToConstant: 140),
            
            avatarLabel.topAnchor.constraint(equalTo: characterPreviewCard.topAnchor, constant: 20),
            avatarLabel.centerXAnchor.constraint(equalTo: characterPreviewCard.centerXAnchor),
            avatarLabel.widthAnchor.constraint(equalToConstant: 80),
            avatarLabel.heightAnchor.constraint(equalToConstant: 80),
            
            characterNamePreview.topAnchor.constraint(equalTo: avatarLabel.bottomAnchor, constant: 12),
            characterNamePreview.leadingAnchor.constraint(equalTo: characterPreviewCard.leadingAnchor, constant: 12),
            characterNamePreview.trailingAnchor.constraint(equalTo: characterPreviewCard.trailingAnchor, constant: -12),
            
            // Avatar selection
            avatarSectionCard.topAnchor.constraint(equalTo: characterPreviewCard.bottomAnchor, constant: 24),
            avatarSectionCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            avatarSectionCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Name input
            nameSectionCard.topAnchor.constraint(equalTo: avatarSectionCard.bottomAnchor, constant: 20),
            nameSectionCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nameSectionCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Skills card
            skillsSectionCard.topAnchor.constraint(equalTo: nameSectionCard.bottomAnchor, constant: 20),
            skillsSectionCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            skillsSectionCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Continue button
            continueButton.topAnchor.constraint(equalTo: skillsSectionCard.bottomAnchor, constant: 32),
            continueButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor, constant: isEditingMode ? -110 : 0),
            continueButton.widthAnchor.constraint(equalToConstant: isEditingMode ? 200 : 280),
            continueButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Add cancel button constraints if in editing mode
        if isEditingMode {
            NSLayoutConstraint.activate([
                cancelButton.topAnchor.constraint(equalTo: skillsSectionCard.bottomAnchor, constant: 32),
                cancelButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor, constant: 110),
                cancelButton.widthAnchor.constraint(equalToConstant: 200),
                cancelButton.heightAnchor.constraint(equalToConstant: 50),
                cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
            ])
        } else {
            NSLayoutConstraint.activate([
                continueButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
            ])
        }
    }
    
    private func setupAnimations() {
        var views = [titleLabel, subtitleLabel, characterPreviewCard, avatarSectionCard, 
                    nameSectionCard, skillsSectionCard, continueButton]
        if isEditingMode {
            views.append(cancelButton)
        }
        
        views.forEach { view in
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 30)
        }
        
        UIView.animateKeyframes(withDuration: 1.2, delay: 0.2, options: [], animations: {
            for (index, view) in views.enumerated() {
                UIView.addKeyframe(withRelativeStartTime: Double(index) * 0.1, relativeDuration: 0.3) {
                    view.alpha = 1
                    view.transform = .identity
                }
            }
        })
    }
    
    // MARK: - Actions
    @objc private func avatarSelected(_ sender: UIButton) {
        updateSelectedAvatar(sender.tag)
        addButtonPressEffect(to: sender)
    }
    
    @objc private func nameChanged() {
        updateCharacterPreview()
    }
    
    @objc private func skillSelected(_ sender: UIButton) {
        let skillIndex = skillsStackView.arrangedSubviews.firstIndex(of: sender) ?? 0
        let skillName = availableSkills[skillIndex].1
        
        if selectedSkills.contains(skillName) {
            selectedSkills.removeAll { $0 == skillName }
            sender.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            sender.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        } else if selectedSkills.count < 2 {
            selectedSkills.append(skillName)
            sender.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
            sender.layer.borderColor = UIColor.systemBlue.cgColor
        }
        
        addButtonPressEffect(to: sender)
    }
    
    @objc private func continueTapped() {
        guard let playerName = nameTextField.text, !playerName.isEmpty else {
            showAlert(title: "โปรดใส่ชื่อ", message: "กรุณาใส่ชื่อตัวละครของคุณ")
            return
        }
        
        // Save character data
        gameStateManager.playerName = playerName
        UserDefaults.standard.set(selectedAvatar, forKey: "playerAvatar")
        UserDefaults.standard.set(selectedSkills, forKey: "playerSkills")
        UserDefaults.standard.set(true, forKey: "hasCreatedCharacter")
        
        addMainButtonEffect(to: continueButton)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.navigateToMainMenu()
        }
    }
    
    @objc private func cancelTapped() {
        let alert = UIAlertController(title: "ยกเลิกการแก้ไข?", message: "การเปลี่ยนแปลงจะไม่ถูกบันทึก", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "ยกเลิก", style: .cancel))
        alert.addAction(UIAlertAction(title: "ตกลง", style: .destructive) { _ in
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Data Loading Methods
    private func loadExistingCharacterData() {
        guard isEditingMode else { return }
        
        // Load existing player name
        let existingName = gameStateManager.playerName
        if !existingName.isEmpty {
            nameTextField.text = existingName
        }
        
        // Load existing avatar
        let existingAvatar = UserDefaults.standard.string(forKey: "playerAvatar") ?? "👤"
        if let avatarIndex = availableAvatars.firstIndex(of: existingAvatar) {
            selectedAvatar = existingAvatar
            updateSelectedAvatar(avatarIndex)
        }
        
        // Load existing skills
        let existingSkills = UserDefaults.standard.stringArray(forKey: "playerSkills") ?? []
        selectedSkills = existingSkills
        
        // Update skills UI
        for (index, skill) in availableSkills.enumerated() {
            if let skillButton = skillsStackView.arrangedSubviews[index] as? UIButton {
                if selectedSkills.contains(skill.1) {
                    skillButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
                    skillButton.layer.borderColor = UIColor.systemBlue.cgColor
                } else {
                    skillButton.backgroundColor = UIColor.white.withAlphaComponent(0.1)
                    skillButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func updateSelectedAvatar(_ index: Int) {
        selectedAvatar = availableAvatars[index]
        updateCharacterPreview()
        
        for (i, button) in avatarButtons.enumerated() {
            if i == index {
                button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.5)
                button.layer.borderColor = UIColor.systemBlue.cgColor
                button.layer.borderWidth = 3
                
                UIView.animate(withDuration: 0.2) {
                    button.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                }
            } else {
                button.backgroundColor = UIColor.white.withAlphaComponent(0.15)
                button.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
                button.layer.borderWidth = 2
                
                UIView.animate(withDuration: 0.2) {
                    button.transform = .identity
                }
            }
        }
        
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    private func updateCharacterPreview() {
        avatarLabel.text = selectedAvatar
        
        if let name = nameTextField.text, !name.isEmpty {
            characterNamePreview.text = name
        } else {
            characterNamePreview.text = "ชื่อของคุณ"
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            self.characterPreviewCard.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                self.characterPreviewCard.transform = .identity
            }
        }
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
    
    private func addMainButtonEffect(to button: UIButton) {
        let originalColor = button.backgroundColor
        
        UIView.animate(withDuration: 0.05, animations: {
            button.backgroundColor = UIColor.white.withAlphaComponent(0.9)
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
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
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ตกลง", style: .default))
        present(alert, animated: true)
    }
    
    private func navigateToMainMenu() {
        if isEditingMode {
            // If editing, just dismiss back to main menu
            dismiss(animated: true)
        } else {
            // If creating new character, navigate to main menu
            let mainMenuVC = MainMenuViewController()
            mainMenuVC.modalPresentationStyle = .fullScreen
            present(mainMenuVC, animated: true)
        }
    }
}

// MARK: - UITextFieldDelegate
extension CharacterCreationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}