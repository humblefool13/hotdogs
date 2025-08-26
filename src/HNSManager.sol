// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./NameService.sol";
import "./SVGLibrary.sol";

/**
 * @title HotDogsNamingService
 * @notice Central manager contract for the HotDogs Naming Service system
 * @dev Manages TLD deployments and provides unified resolution interface
 */
contract HNSManager is Ownable, ReentrancyGuard {
    using Address for address payable;

    /// @notice Mapping of TLD to deployed NameService contract address
    mapping(string => address) public tldContracts;

    /// @notice Array of all registered TLDs
    string[] public registeredTLDs;

    /// @notice SVG library contract address
    address public immutable svgLibrary;

    /// @notice Mapping from address to their main domain (TLD + name)
    mapping(address => string) public mainDomain;

    /// @notice Mapping from address to all their domains across TLDs
    mapping(address => string[]) public addressToDomains;

    /// @notice O(1) authorization mapping for valid NameService contracts
    mapping(address => bool) public validNameServiceContracts;

    /// @notice Event emitted when a new TLD is added
    event TLDAdded(string indexed tld, address indexed contractAddress);

    /// @notice Event emitted when a TLD is removed
    event TLDRemoved(string indexed tld);

    /// @notice Event emitted when funds are withdrawn
    event FundsWithdrawn(address indexed recipient, uint256 amount);

    /// @notice Event emitted when main domain is set
    event MainDomainSet(address indexed owner, string domain);

    /// @notice Error thrown when TLD already exists
    error TLDAlreadyExists(string tld);

    /// @notice Error thrown when TLD does not exist
    error TLDNotFound(string tld);

    /// @notice Error thrown when TLD is invalid
    error InvalidTLD(string tld);

    /// @notice Error thrown when transfer fails
    error TransferFailed();

    /// @notice Error thrown when domain not found
    error DomainNotFound();

    /**
     * @notice Constructor deploys SVG library
     */
    constructor() Ownable(msg.sender) {
        require(msg.sender != address(0), "Invalid owner address");
        // Deploy SVG library
        SVGLibrary svgLib = new SVGLibrary();
        svgLibrary = address(svgLib);
    }

    /**
     * @notice Add a new TLD and deploy its NameService contract
     * @param tld The top-level domain to add
     * @dev Only callable by owner
     */
    function addTLD(string calldata tld) external onlyOwner nonReentrant {
        if (bytes(tld).length == 0) revert InvalidTLD(tld);
        if (tldContracts[tld] != address(0)) revert TLDAlreadyExists(tld);

        // Deploy new NameService contract for this TLD
        NameService nameService = new NameService(
            tld,
            address(this),
            svgLibrary
        );
        tldContracts[tld] = address(nameService);
        registeredTLDs.push(tld);
        validNameServiceContracts[address(nameService)] = true;

        emit TLDAdded(tld, address(nameService));
    }

    /**
     * @notice Remove a TLD and clear its contract mapping
     * @param tld The top-level domain to remove
     * @dev Only callable by owner
     */
    function removeTLD(string calldata tld) external onlyOwner nonReentrant {
        if (tldContracts[tld] == address(0)) revert TLDNotFound(tld);

        // Clear the mapping
        address contractAddress = tldContracts[tld];
        validNameServiceContracts[contractAddress] = false;
        delete tldContracts[tld];

        // Remove from array
        for (uint i = 0; i < registeredTLDs.length; i++) {
            if (keccak256(bytes(registeredTLDs[i])) == keccak256(bytes(tld))) {
                registeredTLDs[i] = registeredTLDs[registeredTLDs.length - 1];
                registeredTLDs.pop();
                break;
            }
        }

        emit TLDRemoved(tld);
    }

    /**
     * @notice Withdraw all accumulated fees from the contract
     * @dev Only callable by owner
     */
    function withdrawFunds() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;
        require(amount > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FundsWithdrawn(owner(), amount);
    }

    /**
     * @notice Set main domain for an address
     * @param domain Full domain (name.tld)
     * @dev Only callable by domain owner
     */
    function setMainDomain(string calldata domain) external nonReentrant {
        // Parse domain to get TLD
        string memory tld = _extractTLD(domain);
        if (tldContracts[tld] == address(0)) revert TLDNotFound(tld);

        // Check if caller owns the domain
        string memory name = _extractName(domain);
        NameService nameService = NameService(tldContracts[tld]);
        if (nameService.getDomainOwner(name) != msg.sender)
            revert DomainNotFound();

        mainDomain[msg.sender] = domain;
        emit MainDomainSet(msg.sender, domain);
    }

    /**
     * @notice Get main domain for an address
     * @param addr Address to lookup
     * @return Main domain string
     */
    function getMainDomain(address addr) external view returns (string memory) {
        return mainDomain[addr];
    }

    /**
     * @notice Get all domains owned by an address across all TLDs
     * @param addr Address to lookup
     * @return Array of all domain names
     */
    function getAllDomainsByOwner(
        address addr
    ) external view returns (string[] memory) {
        return addressToDomains[addr];
    }

    /**
     * @notice Global reverse lookup across all TLDs
     * @param addr Address to lookup
     * @return Main domain if set, otherwise first found domain
     */
    function reverseLookup(address addr) external view returns (string memory) {
        // Return main domain if set
        string memory main = mainDomain[addr];
        if (bytes(main).length > 0) {
            return main;
        }

        // Return first available domain
        string[] memory domains = addressToDomains[addr];
        if (domains.length > 0) {
            return domains[0];
        }

        return "";
    }

    /**
     * @notice Get all registered TLDs
     * @return Array of all registered TLD strings
     */
    function getAllTLDs() external view returns (string[] memory) {
        return registeredTLDs;
    }

    /**
     * @notice Check if a TLD exists
     * @param tld The top-level domain to check
     * @return True if TLD exists, false otherwise
     */
    function tldExists(string calldata tld) external view returns (bool) {
        return tldContracts[tld] != address(0);
    }

    /**
     * @notice Unified resolver function for all TLDs
     * @param name Domain name without TLD
     * @param tld Top-level domain
     * @return owner Domain owner address
     * @return expiration Domain expiration timestamp
     * @return nftAddress Associated NFT contract address
     */
    function resolve(
        string calldata name,
        string calldata tld
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
        address contractAddress = tldContracts[tld];
        if (contractAddress == address(0)) revert TLDNotFound(tld);

        return NameService(contractAddress).resolveDomain(name);
    }

    /**
     * @notice Get domain owner for a specific name and TLD
     * @param name Domain name without TLD
     * @param tld Top-level domain
     * @return Domain owner address
     */
    function getDomainOwner(
        string calldata name,
        string calldata tld
    ) external view returns (address) {
        address contractAddress = tldContracts[tld];
        if (contractAddress == address(0)) revert TLDNotFound(tld);

        return NameService(contractAddress).getDomainOwner(name);
    }

    /**
     * @notice Get domain expiration for a specific name and TLD
     * @param name Domain name without TLD
     * @param tld Top-level domain
     * @return Domain expiration timestamp
     */
    function getDomainExpiration(
        string calldata name,
        string calldata tld
    ) external view returns (uint256) {
        address contractAddress = tldContracts[tld];
        if (contractAddress == address(0)) revert TLDNotFound(tld);

        return NameService(contractAddress).getDomainExpiration(name);
    }

    /**
     * @notice Check if a domain is available for registration
     * @param name Domain name without TLD
     * @param tld Top-level domain
     * @return True if domain is available, false otherwise
     */
    function isDomainAvailable(
        string calldata name,
        string calldata tld
    ) external view returns (bool) {
        address contractAddress = tldContracts[tld];
        if (contractAddress == address(0)) revert TLDNotFound(tld);

        return NameService(contractAddress).isDomainAvailable(name);
    }

    /**
     * @notice Get registration price for a domain
     * @param name Domain name without TLD
     * @param tld Top-level domain
     * @param yearsToRegister Number of years to register
     * @return Total price in wei
     */
    function getRegistrationPrice(
        string calldata name,
        string calldata tld,
        uint256 yearsToRegister
    ) external view returns (uint256) {
        address contractAddress = tldContracts[tld];
        if (contractAddress == address(0)) revert TLDNotFound(tld);

        return
            NameService(contractAddress).getRegistrationPrice(
                name,
                yearsToRegister
            );
    }

    /**
     * @notice Get renewal price for a domain
     * @param name Domain name without TLD
     * @param tld Top-level domain
     * @param yearsToRenew Number of years to renew
     * @return Total price in wei
     */
    function getRenewalPrice(
        string calldata name,
        string calldata tld,
        uint256 yearsToRenew
    ) external view returns (uint256) {
        address contractAddress = tldContracts[tld];
        if (contractAddress == address(0)) revert TLDNotFound(tld);

        return NameService(contractAddress).getRenewalPrice(name, yearsToRenew);
    }

    /**
     * @notice Get total number of registered TLDs
     * @return Count of registered TLDs
     */
    function getTLDCount() external view returns (uint256) {
        return registeredTLDs.length;
    }

    /**
     * @notice Add domain to address mapping (called by NameService contracts)
     * @param owner Domain owner address
     * @param domain Full domain name
     * @dev Internal function called by NameService contracts
     */
    function addDomainToAddress(
        address owner,
        string calldata domain
    ) external nonReentrant {
        require(validNameServiceContracts[msg.sender], "Unauthorized");

        addressToDomains[owner].push(domain);

        // Auto-assign main domain if this is the only domain or first domain
        if (addressToDomains[owner].length == 1) {
            mainDomain[owner] = domain;
            emit MainDomainSet(owner, domain);
        }
    }

    /**
     * @notice Remove domain from address mapping (called by NameService contracts)
     * @param owner Domain owner address
     * @param domain Full domain name
     * @dev Internal function called by NameService contracts
     */
    function removeDomainFromAddress(
        address owner,
        string calldata domain
    ) external nonReentrant {
        require(validNameServiceContracts[msg.sender], "Unauthorized");

        string[] storage domains = addressToDomains[owner];
        uint256 index = type(uint256).max;

        // Gas optimization: Cache keccak256 hash outside the loop
        bytes32 domainHash = keccak256(bytes(domain));

        for (uint i = 0; i < domains.length; i++) {
            if (keccak256(bytes(domains[i])) == domainHash) {
                index = i;
                break;
            }
        }

        if (index < domains.length) {
            domains[index] = domains[domains.length - 1];
            domains.pop();
        }

        // Clear main domain if it was this domain
        if (keccak256(bytes(mainDomain[owner])) == domainHash) {
            delete mainDomain[owner];

            // Auto-assign new main domain if other domains exist
            if (domains.length > 0) {
                mainDomain[owner] = domains[0];
                emit MainDomainSet(owner, domains[0]);
            }
        }
    }

    /**
     * @notice Clear main domain for an address (called by NameService contracts during transfers)
     * @param owner Address whose main domain should be cleared
     * @param domain Domain being transferred away
     * @dev Internal function called by NameService contracts during NFT transfers
     */
    function clearMainDomainIfNeeded(
        address owner,
        string calldata domain
    ) external nonReentrant {
        require(validNameServiceContracts[msg.sender], "Unauthorized");

        // Clear main domain if it was this domain
        // Gas optimization: Cache keccak256 hash
        bytes32 domainHash = keccak256(bytes(domain));
        if (keccak256(bytes(mainDomain[owner])) == domainHash) {
            delete mainDomain[owner];

            // Auto-assign new main domain if other domains exist
            string[] storage domains = addressToDomains[owner];
            if (domains.length > 0) {
                mainDomain[owner] = domains[0];
                emit MainDomainSet(owner, domains[0]);
            }
        }
    }

    /**
     * @notice Extract TLD from full domain
     * @param domain Full domain (name.tld)
     * @return TLD string
     */
    function _extractTLD(
        string memory domain
    ) internal pure returns (string memory) {
        bytes memory domainBytes = bytes(domain);
        for (uint i = domainBytes.length - 1; i > 0; i--) {
            if (domainBytes[i] == 0x2E) {
                // dot character
                bytes memory tld = new bytes(domainBytes.length - i - 1);
                for (uint j = 0; j < tld.length; j++) {
                    tld[j] = domainBytes[i + j + 1];
                }
                return string(tld);
            }
        }
        return "";
    }

    /**
     * @notice Extract name from full domain
     * @param domain Full domain (name.tld)
     * @return Name string
     */
    function _extractName(
        string memory domain
    ) internal pure returns (string memory) {
        bytes memory domainBytes = bytes(domain);
        for (uint i = 0; i < domainBytes.length; i++) {
            if (domainBytes[i] == 0x2E) {
                // dot character
                bytes memory name = new bytes(i);
                for (uint j = 0; j < i; j++) {
                    name[j] = domainBytes[j];
                }
                return string(name);
            }
        }
        return "";
    }
}
