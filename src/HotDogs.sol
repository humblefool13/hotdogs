// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./libraries/DomainUtils.sol";
import "./libraries/SVGBuilder.sol";
import "./libraries/MetadataBuilder.sol";
import "./libraries/DomainPricing.sol";

/**
 * @title HotDogsRegistry
 * @dev Decentralized domain name service with NFT-based ownership on Abstract Chain
 * @notice Each domain is represented as an NFT where ownership determines domain control
 * @author humblefool13
 *
 * This contract implements a complete domain name service where:
 * - Domains are minted as ERC721 NFTs with configurable expiration periods
 * - Pricing is tiered based on domain name length (3-6+ characters)
 * - Grace periods allow for domain renewal after expiration
 * - Admin controls for TLD management and system configuration
 * - Full ownership transfer capabilities with automatic domain updates
 */
contract HotDogsRegistry is
    ERC721Enumerable,
    Ownable,
    ReentrancyGuard,
    Pausable
{
    using Strings for uint256;
    using DomainUtils for string;
    using DomainPricing for string;

    /// @notice Standard domain registration period - domains expire after 1 year
    uint256 public constant EXPIRATION_TIME = 365 days;

    /// @notice Domain registration limits and constraints
    uint256 public constant MIN_DOMAIN_LENGTH = DomainUtils.MIN_DOMAIN_LENGTH;
    uint256 public constant MAX_DOMAIN_LENGTH = DomainUtils.MAX_DOMAIN_LENGTH;

    /// @notice Grace period for domain renewal after expiration - prevents immediate loss
    uint256 public constant GRACE_PERIOD = 7 days;

    /// @notice Token ID counter for NFT minting - starts at 0 for OpenZeppelin compatibility
    uint256 private _tokenIdCounter = 0;

    /// @notice Flag to allow burning during cleanup operations - prevents unauthorized burns
    bool private _allowBurning = false;

    /// @notice Domain ownership mapping (normalized to lowercase)
    mapping(string => address) public domainOwners;
    /// @notice Domain expiration timestamps
    mapping(string => uint256) public domainExpirations;
    /// @notice Domain to token ID mapping
    mapping(string => uint256) public domainToTokenId;

    /// @notice Token ID to domain mapping
    mapping(uint256 => string) public tokenIdToDomain;
    /// @notice User's primary domain selection
    mapping(address => string) public primaryDomain;

    /// @notice Allowed top-level domains (normalized to lowercase)
    mapping(string => bool) public allowedTLDs;
    /// @notice Admin addresses with TLD management rights
    mapping(address => bool) public admins;

    // Core domain lifecycle events
    event DomainRegistered(
        string indexed domain,
        address indexed owner,
        uint256 indexed tokenId,
        uint256 price,
        uint256 _years
    );
    event DomainRenewed(
        string indexed domain,
        uint256 newExpiration,
        uint256 price,
        uint256 _years
    );
    event TLDAdded(string indexed tld);
    event TLDRemoved(string indexed tld);
    event AdminAdded(address indexed admin);
    event AdminRemoved(address indexed admin);
    event PrimaryDomainSet(address indexed owner, string indexed domain);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event RegistryOwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // Custom errors for gas efficiency and clear error handling
    error EmptyDomain(); // Domain name cannot be empty
    error InvalidRegistrationPeriod(); // Registration period must be 1-10 years
    error InvalidDomainFormat(); // Domain must have exactly one dot separator
    error TLDNotAllowed(); // Top-level domain not in allowed list
    error DomainAlreadyRegistered(); // Domain is already owned by another user
    error InsufficientPayment(); // Payment amount is less than required
    error NotDomainOwner(); // Caller is not the domain owner
    error DomainExpired(); // Domain has expired and cannot be used
    error NotAuthorized(); // Caller lacks required permissions
    error NoFundsToWithdraw(); // Contract has no ETH balance
    error TokenDoesNotExist(); // NFT token ID does not exist
    error DomainNameTooShort(); // Domain name is below minimum length
    error DomainNameTooLong(); // Domain name exceeds maximum length
    error InvalidCharacters(); // Domain contains invalid characters
    error InvalidAdminAddress(); // Admin address cannot be zero
    error EmptyTLD(); // Top-level domain cannot be empty
    error TLDAlreadyExists(); // Top-level domain already configured
    error TLDDoesNotExist(); // Top-level domain not found
    error RefundFailed(); // ETH refund transfer failed
    error TransferToZeroAddress(); // Cannot transfer to zero address
    error WithdrawalFailed(); // ETH withdrawal transfer failed
    error DirectPaymentsNotAccepted(); // Contract rejects direct ETH transfers
    error FunctionNotFound(); // Function selector not recognized
    error GracePeriodNotExpired(); // Domain still within renewal grace period
    error NoPrimaryDomain(); // User has no primary domain set
    error TokenIdOverflow(); // Token ID counter overflow
    error InvalidDomainStructure(); // Domain structure is malformed
    error DomainNotActive(); // Domain is not in active state

    constructor() ERC721("HotDogs Domains", "HOTDOGS") Ownable(msg.sender) {
        allowedTLDs["hotdogs"] = true;
        admins[msg.sender] = true;
    }

    // ============= ACCESS CONTROL & VALIDATION MODIFIERS =============

    modifier onlyAdmin() {
        if (!admins[msg.sender] && owner() != msg.sender) {
            revert NotAuthorized();
        }
        _;
    }

    modifier validDomain(string memory _fullDomain) {
        if (bytes(_fullDomain).length == 0) revert EmptyDomain();

        // Validate domain format and structure
        if (!DomainUtils.validateDomainFormat(_fullDomain))
            revert InvalidDomainFormat();

        string[] memory parts = DomainUtils.splitDomain(_fullDomain);
        if (!isValidTLD(parts[1])) revert TLDNotAllowed();
        _;
    }

    modifier domainActive(string memory _fullDomain) {
        if (bytes(_fullDomain).length == 0) revert EmptyDomain();
        if (domainOwners[DomainUtils.toLowerCase(_fullDomain)] == address(0))
            revert TokenDoesNotExist();
        if (
            block.timestamp >
            domainExpirations[DomainUtils.toLowerCase(_fullDomain)] +
                GRACE_PERIOD
        ) revert DomainExpired();
        _;
    }

    // ============= ADMINISTRATIVE FUNCTIONS =============
    // Emergency controls and system configuration management

    /// @notice Pauses all domain operations - emergency stop mechanism
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resumes domain operations after pause
    function unpause() external onlyOwner {
        _unpause();
    }

    function addAdmin(address _admin) external onlyOwner {
        if (_admin == address(0)) revert InvalidAdminAddress();
        admins[_admin] = true;
        emit AdminAdded(_admin);
    }

    function removeAdmin(address _admin) external onlyOwner {
        if (_admin == address(0)) revert InvalidAdminAddress();
        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }

    function addTLD(string memory _tld) external onlyAdmin {
        if (bytes(_tld).length == 0) revert EmptyTLD();
        string memory normalizedTLD = DomainUtils.toLowerCase(_tld);
        if (allowedTLDs[normalizedTLD]) revert TLDAlreadyExists();
        allowedTLDs[normalizedTLD] = true;
        emit TLDAdded(normalizedTLD);
    }

    function removeTLD(string memory _tld) external onlyAdmin {
        if (bytes(_tld).length == 0) revert EmptyTLD();
        string memory normalizedTLD = DomainUtils.toLowerCase(_tld);
        if (!allowedTLDs[normalizedTLD]) revert TLDDoesNotExist();
        allowedTLDs[normalizedTLD] = false;
        emit TLDRemoved(normalizedTLD);
    }

    // ============= QUERY FUNCTIONS =============

    function resolveDomain(
        string memory _fullDomain
    ) external view returns (address) {
        if (bytes(_fullDomain).length == 0) revert EmptyDomain();
        string memory normalizedDomain = DomainUtils.toLowerCase(_fullDomain);
        if (domainOwners[normalizedDomain] == address(0)) {
            return address(0);
        }
        if (
            block.timestamp > domainExpirations[normalizedDomain] + GRACE_PERIOD
        ) {
            return address(0);
        }
        return domainOwners[normalizedDomain];
    }

    function resolveAddress(
        address _address
    ) external view returns (string memory) {
        if (_address == address(0)) revert InvalidAdminAddress();
        string memory domain = primaryDomain[_address];
        if (bytes(domain).length == 0) {
            revert NoPrimaryDomain();
        }
        if (block.timestamp > domainExpirations[domain] + GRACE_PERIOD) {
            revert DomainExpired();
        }
        return domain;
    }

    function isValidTLD(string memory _tld) public view returns (bool) {
        return allowedTLDs[DomainUtils.toLowerCase(_tld)];
    }

    function getDomainPrice(
        string memory _fullDomain
    ) public pure returns (uint256) {
        return DomainPricing.getDomainPrice(_fullDomain);
    }

    function calculateTotalPrice(
        string memory _fullDomain,
        uint256 _years
    ) public pure returns (uint256) {
        return DomainPricing.calculateTotalPrice(_fullDomain, _years);
    }

    function isDomainAvailable(
        string memory _fullDomain
    ) external view returns (bool) {
        if (bytes(_fullDomain).length == 0) return false;
        string memory normalizedDomain = DomainUtils.toLowerCase(_fullDomain);
        return
            domainOwners[normalizedDomain] == address(0) ||
            block.timestamp >
            domainExpirations[normalizedDomain] + GRACE_PERIOD;
    }

    function getDomainInfo(
        string memory _fullDomain
    )
        external
        view
        returns (
            address owner,
            uint256 expiration,
            uint256 tokenId,
            bool isExpired
        )
    {
        if (bytes(_fullDomain).length == 0) revert EmptyDomain();
        string memory normalizedDomain = DomainUtils.toLowerCase(_fullDomain);
        return (
            domainOwners[normalizedDomain],
            domainExpirations[normalizedDomain],
            domainToTokenId[normalizedDomain],
            block.timestamp > domainExpirations[normalizedDomain]
        );
    }

    function getDomainsByOwner(
        address _owner
    )
        external
        view
        returns (string[] memory domains, uint256[] memory expirations)
    {
        if (_owner == address(0)) revert InvalidAdminAddress();
        uint256 balance = balanceOf(_owner);
        domains = new string[](balance);
        expirations = new uint256[](balance);

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(_owner, i);
            string memory domain = tokenIdToDomain[tokenId];
            domains[i] = domain;
            expirations[i] = domainExpirations[domain];
        }

        return (domains, expirations);
    }

    // ============= DOMAIN REGISTRATION FUNCTIONS =============

    function registerDomain(
        string memory _fullDomain,
        uint256 _years
    ) external payable nonReentrant whenNotPaused validDomain(_fullDomain) {
        if (_years == 0 || _years > DomainPricing.MAX_REGISTRATION_YEARS) {
            revert InvalidRegistrationPeriod();
        }

        string memory normalizedDomain = DomainUtils.toLowerCase(_fullDomain);

        if (domainOwners[normalizedDomain] != address(0)) {
            if (
                block.timestamp <=
                domainExpirations[normalizedDomain] + GRACE_PERIOD
            ) {
                revert DomainAlreadyRegistered();
            }
            // Force cleanup of expired domain before re-registration
            uint256 tokenId = domainToTokenId[normalizedDomain];
            _burnAndCleanup(tokenId);
        }

        uint256 totalPrice = DomainPricing.calculateTotalPrice(
            _fullDomain,
            _years
        );
        if (msg.value < totalPrice) revert InsufficientPayment();

        // Check for token ID overflow
        if (_tokenIdCounter == type(uint256).max) revert TokenIdOverflow();
        uint256 newTokenId = _tokenIdCounter + 1; // Get next token ID without incrementing yet
        _tokenIdCounter = newTokenId; // Now increment the counter

        domainOwners[normalizedDomain] = msg.sender;
        domainExpirations[normalizedDomain] =
            block.timestamp +
            (EXPIRATION_TIME * _years);
        domainToTokenId[normalizedDomain] = newTokenId;
        tokenIdToDomain[newTokenId] = normalizedDomain;

        if (bytes(primaryDomain[msg.sender]).length == 0) {
            primaryDomain[msg.sender] = normalizedDomain;
            emit PrimaryDomainSet(msg.sender, normalizedDomain);
        }

        _safeMint(msg.sender, newTokenId);

        if (msg.value > totalPrice) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - totalPrice
            }("");
            if (!success) revert RefundFailed();
        }

        emit DomainRegistered(
            normalizedDomain,
            msg.sender,
            newTokenId,
            totalPrice,
            _years
        );
    }

    function renewDomain(
        string memory _fullDomain,
        uint256 _years
    ) external payable nonReentrant whenNotPaused domainActive(_fullDomain) {
        string memory normalizedDomain = DomainUtils.toLowerCase(_fullDomain);
        if (domainOwners[normalizedDomain] != msg.sender)
            revert NotDomainOwner();

        if (_years == 0 || _years > DomainPricing.MAX_REGISTRATION_YEARS) {
            revert InvalidRegistrationPeriod();
        }

        uint256 totalPrice = DomainPricing.calculateTotalPrice(
            _fullDomain,
            _years
        );
        if (msg.value < totalPrice) revert InsufficientPayment();

        // Extend expiration from current expiration time or current time (whichever is later)
        uint256 baseTime = domainExpirations[normalizedDomain] > block.timestamp
            ? domainExpirations[normalizedDomain]
            : block.timestamp;
        domainExpirations[normalizedDomain] =
            baseTime +
            (EXPIRATION_TIME * _years);

        // Refund excess payment
        if (msg.value > totalPrice) {
            (bool success, ) = payable(msg.sender).call{
                value: msg.value - totalPrice
            }("");
            if (!success) revert RefundFailed();
        }

        emit DomainRenewed(
            normalizedDomain,
            domainExpirations[normalizedDomain],
            totalPrice,
            _years
        );
    }

    function setPrimaryDomain(
        string memory _fullDomain
    ) external whenNotPaused domainActive(_fullDomain) {
        string memory normalizedDomain = DomainUtils.toLowerCase(_fullDomain);
        if (domainOwners[normalizedDomain] != msg.sender)
            revert NotDomainOwner();

        primaryDomain[msg.sender] = normalizedDomain;
        emit PrimaryDomainSet(msg.sender, normalizedDomain);
    }

    /// @notice Clean up expired domains that are past grace period
    function cleanupExpiredDomain(
        string memory _fullDomain
    ) external whenNotPaused {
        if (bytes(_fullDomain).length == 0) revert EmptyDomain();
        string memory normalizedDomain = DomainUtils.toLowerCase(_fullDomain);
        uint256 tokenId = domainToTokenId[normalizedDomain];
        if (tokenId == 0) revert TokenDoesNotExist();

        if (
            block.timestamp <=
            domainExpirations[normalizedDomain] + GRACE_PERIOD
        ) {
            revert GracePeriodNotExpired();
        }

        _cleanupDomainData(normalizedDomain, tokenId);
        _burnAndCleanup(tokenId);
    }

    // ============= OWNERSHIP TRANSFER =============

    function transferRegistryOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert InvalidAdminAddress();
        address oldOwner = owner();
        transferOwnership(newOwner);
        emit RegistryOwnershipTransferred(oldOwner, newOwner);
    }

    // ============= NFT TRANSFER FUNCTIONS =============

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721, IERC721) whenNotPaused {
        if (to == address(0)) revert TransferToZeroAddress();
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override(ERC721, IERC721) whenNotPaused {
        if (to == address(0)) revert TransferToZeroAddress();
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /// @notice Custom function to clean up expired domain data
    function _cleanupDomainData(
        string memory _fullDomain,
        uint256 tokenId
    ) private {
        address currentOwner = domainOwners[_fullDomain];

        // Clear domain data
        delete domainOwners[_fullDomain];
        delete domainExpirations[_fullDomain];
        delete domainToTokenId[_fullDomain];
        delete tokenIdToDomain[tokenId];

        // Clear primary domain if needed
        if (
            keccak256(bytes(primaryDomain[currentOwner])) ==
            keccak256(bytes(_fullDomain))
        ) {
            delete primaryDomain[currentOwner];
        }
    }

    // ============= TOKEN URI =============

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        string memory domain = tokenIdToDomain[tokenId];
        if (bytes(domain).length == 0) revert TokenDoesNotExist();

        uint256 expiration = domainExpirations[domain];

        bool isExpired = block.timestamp > expiration;
        bool inGracePeriod = isExpired &&
            block.timestamp <= expiration + GRACE_PERIOD;

        string memory statusText = isExpired
            ? (inGracePeriod ? "GRACE PERIOD" : "EXPIRED")
            : "ACTIVE";

        string memory svg = SVGBuilder.buildSVG(domain);
        string memory metadata = MetadataBuilder.buildMetadata(
            domain,
            statusText,
            expiration,
            svg
        );

        return
            string(abi.encodePacked("data:application/json;base64,", metadata));
    }

    // ============= UTILITY FUNCTIONS =============

    function isDomainExpired(
        string memory _fullDomain
    ) public view returns (bool) {
        if (bytes(_fullDomain).length == 0) return true;
        string memory normalizedDomain = DomainUtils.toLowerCase(_fullDomain);
        return block.timestamp > domainExpirations[normalizedDomain];
    }

    function isDomainInGracePeriod(
        string memory _fullDomain
    ) public view returns (bool) {
        if (bytes(_fullDomain).length == 0) return false;
        string memory normalizedDomain = DomainUtils.toLowerCase(_fullDomain);
        uint256 expiration = domainExpirations[normalizedDomain];
        return
            block.timestamp > expiration &&
            block.timestamp <= expiration + GRACE_PERIOD;
    }

    // ============= TREASURY MANAGEMENT =============

    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFundsToWithdraw();

        (bool success, ) = payable(owner()).call{value: balance}("");
        if (!success) revert WithdrawalFailed();

        emit FundsWithdrawn(owner(), balance);
    }

    // ============= INTERFACE SUPPORT =============

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Prevents direct ETH transfers to contract
    receive() external payable {
        revert DirectPaymentsNotAccepted();
    }

    /// @notice Prevents calls to non-existent functions
    fallback() external payable {
        revert FunctionNotFound();
    }

    /// @notice Handles domain ownership updates when NFT is transferred
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override whenNotPaused returns (address) {
        address from = super._update(to, tokenId, auth);

        // Handle domain ownership updates for all transfers
        if (from != address(0) && to != address(0)) {
            // Regular transfer between users
            _updateDomainOwnership(from, to, tokenId);
        } else if (to == address(0) && _allowBurning) {
            // Burning is allowed during cleanup operations
            // Domain data cleanup is handled in _burnAndCleanup
        } else if (to == address(0)) {
            // Burning not allowed
            revert TransferToZeroAddress();
        }

        return from;
    }

    /// @notice Custom function to burn tokens and clean up domain data
    function _burnAndCleanup(uint256 tokenId) private {
        string memory domain = tokenIdToDomain[tokenId];
        if (bytes(domain).length > 0) {
            _cleanupDomainData(domain, tokenId);
        }

        // Set flag to allow burning
        _allowBurning = true;

        // Use the standard _burn function
        _burn(tokenId);

        // Reset flag
        _allowBurning = false;
    }

    function _updateDomainOwnership(
        address from,
        address to,
        uint256 tokenId
    ) private {
        string memory domain = tokenIdToDomain[tokenId];

        if (block.timestamp > domainExpirations[domain] + GRACE_PERIOD) {
            revert DomainExpired();
        }

        domainOwners[domain] = to;

        if (keccak256(bytes(primaryDomain[from])) == keccak256(bytes(domain))) {
            delete primaryDomain[from];
        }

        if (bytes(primaryDomain[to]).length == 0) {
            primaryDomain[to] = domain;
            emit PrimaryDomainSet(to, domain);
        }
    }
}
