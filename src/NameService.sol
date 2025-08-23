// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "./SVGLibrary.sol";

/**
 * @title NameService
 * @notice Individual TLD contract for the HotDogs Naming Service system
 * @dev Handles domain registrations, NFTs, and domain management for a specific TLD
 */
contract NameService is ERC721URIStorage {
    using Strings for uint256;

    uint256 public constant PRICE_3_CHAR = 0.012 ether;
    uint256 public constant PRICE_4_CHAR = 0.01 ether;
    uint256 public constant PRICE_5_CHAR = 0.008 ether;
    uint256 public constant PRICE_6_CHAR = 0.006 ether;
    uint256 public constant PRICE_7_PLUS = 0.004 ether;
    uint256 public constant MAX_REGISTRATION_YEARS = 10;
    uint256 public constant MIN_DOMAIN_LENGTH = 3;
    uint256 public constant MAX_DOMAIN_LENGTH = 20;

    string public tld;
    address public immutable hnsManager;
    address public immutable devFeeRecipient;
    address public immutable svgLibrary;
    uint256 private _nextTokenId = 1;

    struct DomainInfo {
        address owner;
        uint256 expiration;
        uint256 registrationDate;
        uint256 renewalCount;
    }

    mapping(string => DomainInfo) public domains;
    mapping(uint256 => string) public tokenToDomain;
    mapping(string => uint256) public domainToToken;
    string[] public allDomains;

    event DomainRegistered(
        string indexed name,
        address indexed owner,
        uint256 tokenId,
        uint256 expiration
    );
    event DomainRenewed(
        string indexed name,
        address indexed owner,
        uint256 newExpiration
    );
    event DomainTransferred(
        string indexed name,
        address indexed from,
        address indexed to
    );
    event DomainExpired(string indexed name, address indexed previousOwner);

    error DomainAlreadyRegistered(string name);
    error DomainNotFound(string name);
    error Unauthorized();
    error InvalidName(string name);
    error InvalidRegistrationPeriod();
    error InsufficientPayment();
    error DomainIsExpired(string name);
    error TransferFailed();

    constructor(
        string memory _tld,
        address _hnsManager,
        address _svgLibrary
    ) ERC721("HotDogs Naming Service", "HNS") {
        require(bytes(_tld).length > 0, "Invalid TLD");
        require(_hnsManager != address(0), "Invalid manager address");
        require(_svgLibrary != address(0), "Invalid SVG library address");

        tld = _tld;
        hnsManager = _hnsManager;
        svgLibrary = _svgLibrary;
        devFeeRecipient = 0x4E08fF4CE98523F7B1299AAE51F515BA64BAf679;
    }

    function register(
        string calldata name,
        uint256 yearsToRegister
    ) external payable {
        if (!_isValidName(name)) revert InvalidName(name);
        if (domains[name].owner != address(0))
            revert DomainAlreadyRegistered(name);
        if (yearsToRegister == 0 || yearsToRegister > MAX_REGISTRATION_YEARS)
            revert InvalidRegistrationPeriod();

        uint256 price = _calculatePrice(name, yearsToRegister);
        if (msg.value < price) revert InsufficientPayment();

        uint256 expiration = block.timestamp + (yearsToRegister * 365 days);

        DomainInfo memory domainInfo = DomainInfo({
            owner: msg.sender,
            expiration: expiration,
            registrationDate: block.timestamp,
            renewalCount: 0
        });

        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _buildTokenURI(name));

        domains[name] = domainInfo;
        tokenToDomain[tokenId] = name;
        domainToToken[name] = tokenId;
        allDomains.push(name);

        // Add to manager's address mapping
        string memory fullDomain = string(abi.encodePacked(name, ".", tld));
        IHNSManager(hnsManager).addDomainToAddress(msg.sender, fullDomain);

        _distributeFees(msg.value);

        emit DomainRegistered(name, msg.sender, tokenId, expiration);
    }

    function renew(
        string calldata name,
        uint256 yearsToRenew
    ) external payable {
        DomainInfo storage domain = domains[name];
        if (domain.owner == address(0)) revert DomainNotFound(name);
        if (domain.owner != msg.sender) revert Unauthorized();
        if (yearsToRenew == 0 || yearsToRenew > MAX_REGISTRATION_YEARS)
            revert InvalidRegistrationPeriod();

        uint256 price = _calculatePrice(name, yearsToRenew);
        if (msg.value < price) revert InsufficientPayment();

        domain.expiration = domain.expiration + (yearsToRenew * 365 days);
        domain.renewalCount++;

        _distributeFees(msg.value);

        emit DomainRenewed(name, msg.sender, domain.expiration);
    }

    function transferDomain(string calldata name, address to) external {
        DomainInfo storage domain = domains[name];
        if (domain.owner == address(0)) revert DomainNotFound(name);
        if (domain.owner != msg.sender) revert Unauthorized();
        if (domain.expiration < block.timestamp) revert DomainIsExpired(name);
        require(to != address(0), "Invalid recipient");

        uint256 tokenId = domainToToken[name];

        // Transfer the NFT - this will automatically update all mappings via _transfer
        _transfer(msg.sender, to, tokenId);

        emit DomainTransferred(name, msg.sender, to);
    }

    function isDomainAvailable(
        string calldata name
    ) external view returns (bool) {
        if (!_isValidName(name)) return false;
        DomainInfo memory domain = domains[name];
        if (domain.owner == address(0)) return true;
        return domain.expiration < block.timestamp;
    }

    function getDomainOwner(
        string calldata name
    ) external view returns (address) {
        DomainInfo memory domain = domains[name];
        if (domain.owner == address(0)) return address(0);
        if (domain.expiration < block.timestamp) return address(0);
        return domain.owner;
    }

    function getDomainExpiration(
        string calldata name
    ) external view returns (uint256) {
        return domains[name].expiration;
    }

    function getRegistrationPrice(
        string calldata name,
        uint256 yearsToRegister
    ) external pure returns (uint256) {
        if (
            !_isValidName(name) ||
            yearsToRegister == 0 ||
            yearsToRegister > MAX_REGISTRATION_YEARS
        ) {
            return 0;
        }
        return _calculatePrice(name, yearsToRegister);
    }

    function getRenewalPrice(
        string calldata name,
        uint256 yearsToRenew
    ) external view returns (uint256) {
        if (
            domains[name].owner == address(0) ||
            yearsToRenew == 0 ||
            yearsToRenew > MAX_REGISTRATION_YEARS
        ) {
            return 0;
        }
        return _calculatePrice(name, yearsToRenew);
    }

    function getAllDomains() external view returns (string[] memory) {
        return allDomains;
    }

    function getTotalDomainCount() external view returns (uint256) {
        return allDomains.length;
    }

    function resolveDomain(
        string calldata name
    )
        external
        view
        returns (
            address owner,
            uint256 expiration,
            address nftAddress,
            uint256 tokenId
        )
    {
        DomainInfo memory domain = domains[name];
        if (domain.owner == address(0) || domain.expiration < block.timestamp) {
            return (address(0), 0, address(0), 0);
        }
        return (
            domain.owner,
            domain.expiration,
            address(this),
            domainToToken[name]
        );
    }

    /**
     * @notice Check and burn expired domains
     * @dev Can be called by anyone to clean up expired domains
     */
    function checkAndBurnExpiredDomains() external {
        uint256 totalDomains = allDomains.length;
        uint256 i = 0;

        while (i < totalDomains) {
            string memory name = allDomains[i];
            DomainInfo storage domain = domains[name];

            if (
                domain.owner != address(0) &&
                domain.expiration < block.timestamp
            ) {
                // Domain is expired, burn it
                uint256 tokenId = domainToToken[name];
                address previousOwner = domain.owner;

                // Burn the NFT
                _burn(tokenId);

                // Clear domain info
                delete domains[name];
                delete tokenToDomain[tokenId];
                delete domainToToken[name];

                // Remove from allDomains array (swap with last element and pop)
                allDomains[i] = allDomains[totalDomains - 1];
                allDomains.pop();
                totalDomains--;

                // Remove from manager's address mapping
                string memory fullDomain = string(
                    abi.encodePacked(name, ".", tld)
                );
                IHNSManager(hnsManager).removeDomainFromAddress(
                    previousOwner,
                    fullDomain
                );

                emit DomainExpired(name, previousOwner);

                // Don't increment i since we swapped elements
            } else {
                i++;
            }
        }
    }

    /**
     * @notice Override _update to prevent transfers of expired domains and update domain ownership
     * @dev This ensures expired domains cannot be transferred and domain ownership is kept in sync
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal virtual override returns (address) {
        // Check if domain is expired
        string memory name = tokenToDomain[tokenId];
        if (bytes(name).length > 0) {
            DomainInfo storage domain = domains[name];
            if (domain.expiration < block.timestamp) {
                revert DomainIsExpired(name);
            }
        }

        // Get the from address before the transfer
        address from = _ownerOf(tokenId);

        // Call parent logic (actually performs the transfer/mint/burn)
        address result = super._update(to, tokenId, auth);

        // If this is a transfer (not a mint or burn), update domain ownership
        if (from != address(0) && to != address(0) && bytes(name).length > 0) {
            // Update local domain ownership
            domains[name].owner = to;

            // Update manager mappings
            string memory fullDomain = string(abi.encodePacked(name, ".", tld));

            // Clear main domain for old owner if needed
            IHNSManager(hnsManager).clearMainDomainIfNeeded(from, fullDomain);

            // Remove from old owner and add to new owner
            IHNSManager(hnsManager).removeDomainFromAddress(from, fullDomain);
            IHNSManager(hnsManager).addDomainToAddress(to, fullDomain);
        }

        return result;
    }

    /**
     * @notice Override transferFrom for marketplace compatibility
     * @dev Ensures domain ownership is updated when NFTs are transferred
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {
        super.transferFrom(from, to, tokenId);
        // _transfer is already called in super.transferFrom, so no need to call it again
    }

    /**
     * @notice Override safeTransferFrom for marketplace compatibility
     * @dev Ensures domain ownership is updated when NFTs are transferred
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override(ERC721, IERC721) {
        super.safeTransferFrom(from, to, tokenId, data);
        // _transfer is already called in super.safeTransferFrom, so no need to call it again
    }

    function _calculatePrice(
        string memory name,
        uint256 _years
    ) internal pure returns (uint256) {
        uint256 basePrice;
        uint256 length = bytes(name).length;

        if (length == 3) basePrice = PRICE_3_CHAR;
        else if (length == 4) basePrice = PRICE_4_CHAR;
        else if (length == 5) basePrice = PRICE_5_CHAR;
        else if (length == 6) basePrice = PRICE_6_CHAR;
        else basePrice = PRICE_7_PLUS;

        return basePrice * _years;
    }

    function _isValidName(string memory name) internal pure returns (bool) {
        bytes memory nameBytes = bytes(name);
        if (
            nameBytes.length < MIN_DOMAIN_LENGTH ||
            nameBytes.length > MAX_DOMAIN_LENGTH
        ) {
            return false;
        }

        for (uint i = 0; i < nameBytes.length; i++) {
            bytes1 char = nameBytes[i];
            if (i == 0 && char == 0x2D) return false;
            if (i == nameBytes.length - 1 && char == 0x2D) return false;

            if (char == 0x2D) {
                if (i > 0 && nameBytes[i - 1] == 0x2D) return false;
            } else if (
                !(char >= 0x30 && char <= 0x39) &&
                !(char >= 0x41 && char <= 0x5A) &&
                !(char >= 0x61 && char <= 0x7A)
            ) {
                return false;
            }
        }

        return true;
    }

    function _buildTokenURI(
        string memory name
    ) internal view returns (string memory) {
        string memory fullDomain = string(abi.encodePacked(name, ".", tld));

        // Generate SVG using the library
        string memory svg = SVGLibrary(svgLibrary).generateSVG(name, tld);
        string memory imageData = Base64.encode(bytes(svg));

        // Build comprehensive metadata
        DomainInfo memory domain = domains[name];
        string memory expirationDate = domain.expiration.toString();
        string memory registrationDate = domain.registrationDate.toString();
        string memory renewalCount = domain.renewalCount.toString();
        string memory nameLength = bytes(name).length.toString();

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        fullDomain,
                        '",',
                        '"description": "A domain on the HotDogs Naming Service",',
                        '"image": "data:image/svg+xml;base64,',
                        imageData,
                        '",',
                        '"external_url": "https://hotdogs.xyz",',
                        '"attributes": [',
                        '{"trait_type": "TLD", "value": "',
                        tld,
                        '"},',
                        '{"trait_type": "Name Length", "value": "',
                        nameLength,
                        '"},',
                        '{"trait_type": "Registration Date", "value": "',
                        registrationDate,
                        '"},',
                        '{"trait_type": "Expiration Date", "value": "',
                        expirationDate,
                        '"},',
                        '{"trait_type": "Renewal Count", "value": "',
                        renewalCount,
                        '"}',
                        "],",
                        '"properties": {',
                        '"files": [{"uri": "data:image/svg+xml;base64,',
                        imageData,
                        '", "type": "image/svg+xml"}],',
                        '"category": "domain",',
                        '"domain": "',
                        fullDomain,
                        '",',
                        '"tld": "',
                        tld,
                        '",',
                        '"name": "',
                        name,
                        '"',
                        "}",
                        "}"
                    )
                )
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function _distributeFees(uint256 amount) internal {
        uint256 devFeeAmount = (amount * 25) / 100;
        uint256 managerAmount = amount - devFeeAmount;

        if (devFeeAmount > 0) {
            (bool success, ) = payable(devFeeRecipient).call{
                value: devFeeAmount
            }("");
            if (!success) revert TransferFailed();
        }

        if (managerAmount > 0) {
            (bool success, ) = payable(hnsManager).call{value: managerAmount}(
                ""
            );
            if (!success) revert TransferFailed();
        }
    }

    function getDomainInfo(
        string calldata name
    )
        external
        view
        returns (
            address owner,
            uint256 expiration,
            uint256 registrationDate,
            uint256 renewalCount
        )
    {
        DomainInfo memory domain = domains[name];
        return (
            domain.owner,
            domain.expiration,
            domain.registrationDate,
            domain.renewalCount
        );
    }
}

// Interface for the manager contract
interface IHNSManager {
    function addDomainToAddress(address owner, string calldata domain) external;

    function removeDomainFromAddress(
        address owner,
        string calldata domain
    ) external;

    function clearMainDomainIfNeeded(
        address owner,
        string calldata domain
    ) external;
}
