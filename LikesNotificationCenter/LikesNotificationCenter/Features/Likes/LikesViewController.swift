import UIKit
import Combine

class LikesViewController: UIViewController {
    
    // MARK: - Properties
    private let viewModel: LikesViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // Data Source
    private typealias DataSource = UICollectionViewDiffableDataSource<String, String>
    private var dataSource: DataSource!
    
    // MARK: - UI Elements
    private lazy var collectionView: UICollectionView = {
        let layout = createLayout()
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .systemBackground
        cv.register(UserCell.self, forCellWithReuseIdentifier: UserCell.reuseId)
        cv.delegate = self
        return cv
    }()
    
    private let segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Liked you", "Mutuals"])
        sc.selectedSegmentIndex = 0
        return sc
    }()
    
    private let unblurButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .label
        config.baseForegroundColor = .systemBackground
        config.title = "Unblur All"
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
        
        let btn = UIButton(configuration: config)
        btn.isHidden = true
        return btn
    }()
    
    private let timerLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        label.textAlignment = .center
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()
    
    // MARK: - Init
    init(viewModel: LikesViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDataSource()
        setupBindings()
        
        viewModel.send(.viewDidLoad)
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Likes"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground
        
        view.addSubview(segmentedControl)
        view.addSubview(collectionView)
        view.addSubview(unblurButton)
        view.addSubview(timerLabel)
        
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        unblurButton.translatesAutoresizingMaskIntoConstraints = false
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            collectionView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            unblurButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            unblurButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            timerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            timerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            timerLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            timerLabel.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        segmentedControl.addTarget(self, action: #selector(handleSegmentChange), for: .valueChanged)
        unblurButton.addTarget(self, action: #selector(handleUnblurTap), for: .touchUpInside)
        
        // Refresh Control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5),
                                              heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .fractionalWidth(0.75))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    private func setupDataSource() {
        dataSource = DataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, id in
            guard let self = self,
                  let cell = collectionView.dequeueReusableCell(withReuseIdentifier: UserCell.reuseId, for: indexPath) as? UserCell,
                  let itemViewModel = self.viewModel.viewModel(for: id) else {
                return UICollectionViewCell()
            }
            
            cell.configure(
                with: itemViewModel,
                isBlurred: viewModel.areProfilesBlurred,
                buttonsVisible: viewModel.areButtonsVisible
            )
            cell.delegate = self
            
            return cell
        }
    }
    
    private func setupBindings() {
        // Observe Items (Data)
        viewModel.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                self?.applySnapshot(with: items)
            }
            .store(in: &cancellables)
            
        // Observe Unblur State
        viewModel.$isUnblurActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                guard let self = self else { return }
                self.unblurButton.isHidden = isActive
                self.timerLabel.isHidden = !isActive
                
                // Refresh visible cells to toggle blur state
                var snapshot = self.dataSource.snapshot()
                snapshot.reloadItems(snapshot.itemIdentifiers)
                self.dataSource.apply(snapshot, animatingDifferences: true)
                
                self.collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 90, right: 0)
            }
            .store(in: &cancellables)
            
        // Observe Timer
        viewModel.$unblurTimeRemaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timeString in
                if let time = timeString {
                    self?.timerLabel.text = "Everyone unblurred for \(time)"
                }
            }
            .store(in: &cancellables)
            
        // Observe Loading
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if !isLoading {
                    self?.collectionView.refreshControl?.endRefreshing()
                }
            }
            .store(in: &cancellables)
            
        // Error Handling
        viewModel.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                let alert = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
            .store(in: &cancellables)
    }
    
    private func applySnapshot(with items: [UserCellViewModel]) {
        var snapshot = NSDiffableDataSourceSnapshot<String, String>()
        snapshot.appendSections(["section"])
        snapshot.appendItems(items.map { $0.id })
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    
    // MARK: - Actions
    @objc private func handleRefresh() {
        viewModel.send(.pullToRefresh)
    }
    
    @objc private func handleUnblurTap() {
        viewModel.send(.unblurAllTapped)
    }
    
    @objc private func handleSegmentChange(_ sender: UISegmentedControl) {
        viewModel.send(.segmentChanged(sender.selectedSegmentIndex))
    }
}

// MARK: - UserCellDelegate
extension LikesViewController: UserCellDelegate {
    func didTapLike(in cell: UserCell) {
        guard let indexPath = collectionView.indexPath(for: cell),
              let id = dataSource.itemIdentifier(for: indexPath) else { return }
        
        viewModel.send(.like(id))
    }
    
    func didTapPass(in cell: UserCell) {
        guard let indexPath = collectionView.indexPath(for: cell),
              let id = dataSource.itemIdentifier(for: indexPath) else { return }
        
        viewModel.send(.pass(id))
    }
}

// MARK: - UICollectionViewDelegate
extension LikesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.item == (dataSource.snapshot().numberOfItems - 1) {
            viewModel.send(.loadMore)
        }
    }
}
