import UIKit
import Combine

protocol UserCellDelegate: AnyObject {
    func didTapLike(in cell: UserCell)
    func didTapPass(in cell: UserCell)
}

class UserCell: UICollectionViewCell {
    static let reuseId = "UserCell"
    
    weak var delegate: UserCellDelegate?
    
    // MARK: - UI Elements
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .secondarySystemBackground
        iv.layer.cornerRadius = 16
        return iv
    }()
    
    private let blurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterial)
        let view = UIVisualEffectView(effect: blur)
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.isHidden = true
        return view
    }()
    
    // Simple Gradient View for legibility
    private class GradientView: UIView {
        override class var layerClass: AnyClass { CAGradientLayer.self }
        var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }
    }
    
    private let bottomGradientView: GradientView = {
        let view = GradientView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        // Gradient from clear (top) to black (bottom)
        view.gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.0).cgColor,
            UIColor.black.withAlphaComponent(0.8).cgColor
        ]
        view.gradientLayer.locations = [0.0, 1.0]
        
        view.layer.cornerRadius = 16
        view.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        view.clipsToBounds = true
        return view
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        label.textAlignment = .left
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowRadius = 4
        label.layer.shadowOpacity = 0.8
        label.layer.shadowOffset = CGSize(width: 0, height: 2)
        return label
    }()
    
    private lazy var likeButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .systemBackground
        config.baseForegroundColor = .systemRed
        config.cornerStyle = .capsule
        config.image = UIImage(systemName: "heart.fill")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .title3)
        
        let btn = UIButton(configuration: config)
        btn.addTarget(self, action: #selector(handleLike), for: .touchUpInside)
        return btn
    }()
    
    private lazy var passButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .systemBackground
        config.baseForegroundColor = .label
        config.cornerStyle = .capsule
        config.image = UIImage(systemName: "xmark")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .title3)
        
        let btn = UIButton(configuration: config)
        btn.addTarget(self, action: #selector(handlePass), for: .touchUpInside)
        return btn
    }()
    
    private let matchBadge: UILabel = {
        let label = UILabel()
        label.text = " Same goals "
        label.font = UIFont.preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()
    
    // Constraints
    private var nameLabelBottomWithButtons: NSLayoutConstraint!
    private var nameLabelBottomWithoutButtons: NSLayoutConstraint!
    
    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(bottomGradientView)
        contentView.addSubview(blurView)
        contentView.addSubview(matchBadge)
        contentView.addSubview(nameLabel)
        contentView.addSubview(passButton)
        contentView.addSubview(likeButton)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        bottomGradientView.translatesAutoresizingMaskIntoConstraints = false
        blurView.translatesAutoresizingMaskIntoConstraints = false
        matchBadge.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        passButton.translatesAutoresizingMaskIntoConstraints = false
        likeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Define constraints that change
        nameLabelBottomWithButtons = nameLabel.bottomAnchor.constraint(equalTo: passButton.topAnchor, constant: -8)
        nameLabelBottomWithoutButtons = nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            bottomGradientView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bottomGradientView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottomGradientView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            bottomGradientView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.5),
            
            blurView.topAnchor.constraint(equalTo: imageView.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            
            passButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            passButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            passButton.widthAnchor.constraint(equalToConstant: 48),
            passButton.heightAnchor.constraint(equalToConstant: 48),
            
            likeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            likeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            likeButton.widthAnchor.constraint(equalToConstant: 48),
            likeButton.heightAnchor.constraint(equalToConstant: 48),
            
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            // Note: Bottom constraint activated dynamically
            
            matchBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            matchBadge.bottomAnchor.constraint(equalTo: nameLabel.topAnchor, constant: -6)
        ])
        
        // Default state
        nameLabelBottomWithButtons.isActive = true
    }
    
    // MARK: - Configuration
    func configure(with viewModel: UserCellViewModel, isBlurred: Bool, buttonsVisible: Bool) {
        nameLabel.text = viewModel.name
        
        // Match badge (Simulated)
        matchBadge.isHidden = isBlurred || Bool.random()
        
        // Async Image Loading
        imageView.image = nil
        if let url = URL(string: viewModel.photoURL) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data = data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self?.imageView.image = image
                }
            }.resume()
        }
        
        // Blur Logic
        blurView.isHidden = !isBlurred
        nameLabel.isHidden = isBlurred
        
        // Button Visibility Logic
        let hideButtons = isBlurred || !buttonsVisible
        passButton.isHidden = hideButtons
        likeButton.isHidden = hideButtons
        matchBadge.isHidden = isBlurred
        
        // Layout Logic
        if hideButtons {
            nameLabelBottomWithButtons.isActive = false
            nameLabelBottomWithoutButtons.isActive = true
        } else {
            nameLabelBottomWithoutButtons.isActive = false
            nameLabelBottomWithButtons.isActive = true
        }
        
        contentView.isUserInteractionEnabled = !isBlurred
    }
    
    // MARK: - Actions
    @objc private func handleLike() {
        delegate?.didTapLike(in: self)
    }
    
    @objc private func handlePass() {
        delegate?.didTapPass(in: self)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        blurView.isHidden = true
    }
}
