// SPDX-License-Identifier: MIT
/*
 _                        _      _         __                _  _  _____ 
| |__   _   _  _ __ ___  | |__  | |  ___  / _|  ___    ___  | |/ ||___ / 
| '_ \ | | | || '_ ` _ \ | '_ \ | | / _ \| |_  / _ \  / _ \ | || |  |_ \ 
| | | || |_| || | | | | || |_) || ||  __/|  _|| (_) || (_) || || | ___) |
|_| |_| \__,_||_| |_| |_||_.__/ |_| \___||_|   \___/  \___/ |_||_||____/ 
                                                                         
https://t.me/humblefool13    
                                                                  
*/

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./SVGLibrary.sol";
import "./MinHeap.sol";
import "./TokenURILibrary.sol";
import "./DomainUtils.sol";

/**
 * @title NameService
 * @notice Individual TLD contract for the HotDogs Naming Service system
 * @dev Handles domain registrations, NFTs, and domain management for a specific TLD
 * @dev Uses MinHeap for efficient expiration management and domainToIndex for O(1) array removal
 */
contract NameService is ERC721URIStorage, ReentrancyGuard, IERC2981 {
    using Strings for uint256;
    using MinHeap for MinHeap.Heap;
    using TokenURILibrary for string;
    using DomainUtils for string;

    string public tld;
    address public immutable hnsManager;
    address public immutable svgLibrary;
    uint256 private _nextTokenId = 1;

    struct DomainInfo {
        address owner;
        uint96 renewalCount;
        uint256 expiration;
        uint256 registrationDate;
    }

    mapping(string => DomainInfo) public domains;
    mapping(uint256 => string) public tokenToDomain;
    mapping(string => uint256) public domainToToken;
    string[] public allDomains;

    // MinHeap for efficient expiration management
    MinHeap.Heap private expirationHeap;

    // O(1) index lookup for allDomains removal
    mapping(string => uint256) private domainToIndex; // Maps domain to allDomains index (1-based)

    event DomainRegistered(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 expiration
    );
    event DomainRenewed(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 newExpiration
    );
    event DomainTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to
    );
    event DomainExpired(uint256 indexed tokenId, address indexed previousOwner);
    event ExpiredDomainsProcessed(uint256 cleaned);

    error DomainAlreadyRegistered(string name);
    error DomainNotFound(string name);
    error Unauthorized();
    error InvalidName(string name);
    error InvalidRegistrationPeriod();
    error InsufficientPaymentAmount(uint256 required, uint256 provided);
    error DomainIsExpired(string name);
    error TransferFailed();
    error BadTLD();
    error BadMgr();
    error BadSVG();
    error ZeroAddr();
    error BadBatch();
    error NoToken();

    constructor(
        string memory _tld,
        address _hnsManager,
        address _svgLibrary
    )
        ERC721(
            string(abi.encodePacked("HotDogs Naming Service", " - ", _tld)),
            string(abi.encodePacked(TokenURILibrary._toUpper(_tld)))
        )
    {
        _tld = TokenURILibrary._toLower(_tld);
        if (bytes(_tld).length == 0) revert BadTLD();
        if (_hnsManager == address(0)) revert BadMgr();
        if (_svgLibrary == address(0)) revert BadSVG();
        tld = _tld;
        hnsManager = _hnsManager;
        svgLibrary = _svgLibrary;
    }

    function register(
        string calldata name,
        uint256 yearsToRegister
    ) external payable nonReentrant {
        _sweepExpired(2);
        if (!name.isValidDomainName()) revert InvalidName(name);
        if (domains[name].owner != address(0)) {
            if (domains[name].expiration >= block.timestamp)
                revert DomainAlreadyRegistered(name);
            expirationHeap.remove(name);
            _burnExpiredDomain(name);
        }
        if (yearsToRegister == 0 || yearsToRegister > 10)
            revert InvalidRegistrationPeriod();

        uint256 price = _calculatePrice(name, yearsToRegister);
        if (msg.value < price)
            revert InsufficientPaymentAmount(price, msg.value);

        uint256 expiration = block.timestamp + (yearsToRegister * 365 days);

        DomainInfo memory domainInfo = DomainInfo({
            owner: msg.sender,
            renewalCount: 0,
            expiration: expiration,
            registrationDate: block.timestamp
        });

        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        // State updates first
        domains[name] = domainInfo;
        tokenToDomain[tokenId] = name;
        domainToToken[name] = tokenId;

        // Add to allDomains with index tracking
        allDomains.push(name);
        domainToIndex[name] = allDomains.length; // 1-based indexing

        // Add to expiration heap for efficient management
        expirationHeap.insert(name, expiration);

        // External calls after state updates

        string memory svg = SVGLibrary(svgLibrary).generateSVG(name, tld);
        _safeMint(msg.sender, tokenId);
        _setTokenURI(
            tokenId,
            TokenURILibrary.buildTokenURI(
                name,
                tld,
                svg,
                domainInfo.expiration,
                domainInfo.registrationDate,
                domainInfo.renewalCount
            )
        );

        // Add to manager's address mapping
        string memory fullDomain = string(abi.encodePacked(name, ".", tld));
        IHNSManager(hnsManager).addDomainToAddress(msg.sender, fullDomain);

        _distributeFees(msg.value);

        emit DomainRegistered(tokenId, msg.sender, expiration);
    }

    function renew(
        string calldata name,
        uint256 yearsToRenew
    ) external payable nonReentrant {
        _sweepExpired(2);
        if (!name.isValidDomainName()) revert InvalidName(name);
        DomainInfo storage domain = domains[name];
        if (domain.owner == address(0)) revert DomainNotFound(name);
        if (domain.owner != msg.sender || domain.expiration < block.timestamp)
            revert Unauthorized();
        if (yearsToRenew == 0 || yearsToRenew > 10)
            revert InvalidRegistrationPeriod();

        uint256 price = _calculatePrice(name, yearsToRenew);
        if (msg.value < price)
            revert InsufficientPaymentAmount(price, msg.value);

        domain.expiration = domain.expiration + (yearsToRenew * 365 days);
        domain.renewalCount++;

        // Update expiration in heap
        expirationHeap.updateExpiration(name, domain.expiration);

        string memory svg = SVGLibrary(svgLibrary).generateSVG(name, tld);

        uint256 tokenId = domainToToken[name];
        _setTokenURI(
            tokenId,
            TokenURILibrary.buildTokenURI(
                name,
                tld,
                svg,
                domain.expiration,
                domain.registrationDate,
                domain.renewalCount
            )
        );

        _distributeFees(msg.value);

        emit DomainRenewed(tokenId, msg.sender, domain.expiration);
    }

    function transferDomain(
        string calldata name,
        address to
    ) external nonReentrant {
        DomainInfo storage domain = domains[name];
        if (domain.owner == address(0) || domain.expiration < block.timestamp)
            revert DomainNotFound(name);
        if (domain.owner != msg.sender) revert Unauthorized();
        if (to == address(0)) revert ZeroAddr();

        uint256 tokenId = domainToToken[name];

        // Transfer the NFT - this will automatically update all mappings via _transfer
        _transfer(msg.sender, to, tokenId);

        emit DomainTransferred(tokenId, msg.sender, to);
    }

    function isDomainAvailable(
        string calldata name
    ) external view returns (bool) {
        if (!name.isValidDomainName()) return false;
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
     * @notice Pops up to `n` expired entries off the heap top, called as a side effect of register/renew
     */
    function _sweepExpired(uint256 n) internal {
        for (uint256 i = 0; i < n; i++) {
            if (expirationHeap.size() == 0) break;
            (, uint256 expiration) = expirationHeap.getMin();
            if (expiration >= block.timestamp) break;
            (string memory name, ) = expirationHeap.popMin();
            if (domains[name].owner != address(0)) {
                _burnExpiredDomain(name);
            }
        }
    }

    /**
     * @notice Bounded batch cleanup of expired domains to avoid unbounded gas
     * @param maxDomains Maximum number of expired domains to process in this call (capped at 20)
     */
    function cleanupExpiredDomains(uint256 maxDomains) public nonReentrant {
        if (maxDomains == 0 || maxDomains > 20) revert BadBatch();

        uint256 cleaned = 0;
        while (expirationHeap.size() > 0 && cleaned < maxDomains) {
            (string memory name, uint256 expiration) = expirationHeap.getMin();
            if (expiration >= block.timestamp) break;

            (name, ) = expirationHeap.popMin();
            if (domains[name].owner != address(0)) {
                _burnExpiredDomain(name);
                cleaned++;
            }
        }

        emit ExpiredDomainsProcessed(cleaned);
    }

    /**
     * @notice Internal helper to burn and clean up a specific expired domain
     * @param name The domain name to burn
     */
    function _burnExpiredDomain(string memory name) internal {
        DomainInfo storage domain = domains[name];
        // Recheck expiration to prevent race with renewal
        if (domain.expiration >= block.timestamp) {
            return;
        }
        uint256 tokenId = domainToToken[name];
        address previousOwner = domain.owner;

        // Burn the NFT
        _burn(tokenId);

        // Clear domain info
        delete domains[name];
        delete tokenToDomain[tokenId];
        delete domainToToken[name];

        // O(1) removal from allDomains using domainToIndex
        uint256 index = domainToIndex[name];
        if (index > 0) {
            index -= 1; // Convert to 0-based
            allDomains[index] = allDomains[allDomains.length - 1];
            domainToIndex[allDomains[index]] = index + 1;
            allDomains.pop();
            delete domainToIndex[name];
        }

        // Update manager mappings
        string memory fullDomain = string(abi.encodePacked(name, ".", tld));
        IHNSManager(hnsManager).removeDomainFromAddress(
            previousOwner,
            fullDomain
        );

        emit DomainExpired(tokenId, previousOwner);
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
        if (bytes(name).length > 0 && to != address(0)) {
            DomainInfo storage domain = domains[name];
            if (domain.expiration < block.timestamp) {
                revert DomainIsExpired(name);
            }
        }

        // Get the from address before the transfer
        address from = _ownerOf(tokenId);

        // If this is a transfer (not a mint or burn), update domain ownership
        if (from != address(0) && to != address(0) && bytes(name).length > 0) {
            // Update local domain ownership
            domains[name].owner = to;

            // Update manager mappings
            string memory fullDomain = string(abi.encodePacked(name, ".", tld));

            // Remove from old owner and add to new owner
            IHNSManager(hnsManager).removeDomainFromAddress(from, fullDomain);
            IHNSManager(hnsManager).addDomainToAddress(to, fullDomain);
        }

        // Call parent logic (actually performs the transfer/mint/burn)
        address result = super._update(to, tokenId, auth);
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
    ) public pure returns (uint256) {
        uint256 basePrice;
        uint256 length = bytes(name).length;

        if (length == 3) basePrice = 0.0049 ether;
        else if (length == 4) basePrice = 0.0034 ether;
        else if (length == 5) basePrice = 0.0024 ether;
        else basePrice = 0.0015 ether;

        return basePrice * _years;
    }

    function _distributeFees(uint256 amount) internal {
        if (amount > 0) {
            (bool success, ) = payable(hnsManager).call{value: amount}("");
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

    // EIP-2981 Royalty support
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721URIStorage, IERC165) returns (bool) {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        if (_ownerOf(tokenId) == address(0)) revert NoToken();
        return (hnsManager, (salePrice * 250) / 10000);
    }
}

// Interface for the manager contract
interface IHNSManager {
    function addDomainToAddress(address owner, string calldata domain) external;

    function removeDomainFromAddress(
        address owner,
        string calldata domain
    ) external;
}
