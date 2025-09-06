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

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./NameService.sol";
import "./SVGLibrary.sol";
import "./DomainUtils.sol";

/**
 * @title HotDogsNamingService
 * @notice Central manager for the HotDogs Naming Service system
 * @dev Manages TLD deployments and provides unified resolution interface
 */
contract HNSManager is Ownable, ReentrancyGuard {
    using Address for address payable;
    using DomainUtils for string;

    /// @notice TLD to deployed NameService contract mapping
    mapping(string => address) public tldContracts;

    /// @notice All registered TLDs
    string[] public registeredTLDs;

    /// @notice SVG library contract address
    address public immutable svgLibrary;

    /// @notice Address to main domain mapping
    mapping(address => string) public mainDomain;

    /// @notice Address to all domains mapping
    mapping(address => string[]) public addressToDomains;

    /// @notice Address to all domains mapping
    mapping(address => mapping(string => uint256)) private domainToIndex;

    /// @notice Valid NameService contract addresses
    mapping(address => bool) public validNSAddress;

    /// @notice Emitted when a new TLD is added
    event TLDAdded(string indexed tld, address indexed tldContract);

    /// @notice Emitted when funds are withdrawn
    event FundsWithdrawn(address indexed recipient, uint256 amount);

    /// @notice Error when TLD already exists
    error TLDExists();

    /// @notice Error when TLD is invalid/does not exist
    error InvalidTLD();

    /// @notice Error when transfer fails
    error TransferFailed();

    /// @notice Error when domain not found
    error NoDomain();

    /// @notice Error when no funds available
    error NoFunds();

    /// @notice Error when caller is unauthorized
    error UnAuth();

    modifier onlyNS() {
        _onlyNS();
        _;
    }

    function _onlyNS() internal view {
        if (!validNSAddress[msg.sender]) revert UnAuth();
    }

    /**
     * @notice Constructor deploys SVG library
     */
    constructor() Ownable(msg.sender) {
        SVGLibrary svgLib = new SVGLibrary();
        svgLibrary = address(svgLib);
    }

    /**
     * @notice Adds a new TLD and deploys its NameService contract
     * @param tld The top-level domain to add
     * @dev Only callable by owner
     */
    function addTLD(string calldata tld) external onlyOwner nonReentrant {
        // Validate TLD format (3-10 lowercase letters only)
        if (!tld.isValidTLD()) revert InvalidTLD();
        if (tldContracts[tld] != address(0)) revert TLDExists();

        // Deploy new NameService contract for this TLD
        NameService nameService = new NameService(
            tld,
            address(this),
            svgLibrary
        );
        tldContracts[tld] = address(nameService);
        registeredTLDs.push(tld);
        validNSAddress[address(nameService)] = true;

        emit TLDAdded(tld, address(nameService));
    }

    /**
     * @notice Withdraws all accumulated fees from the contract
     * @dev Only callable by owner
     */
    function withdrawFunds() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NoFunds();

        (bool success, ) = payable(owner()).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit FundsWithdrawn(owner(), amount);
    }

    /**
     * @notice Sets main domain for an address
     * @param name Name of the domain
     * @param tld TLD of the domain
     * @dev Only callable by domain owner
     */
    function setMainDomain(
        string calldata name,
        string calldata tld
    ) external nonReentrant {
        // Validate TLD and name
        if (!tld.isValidTLD()) revert InvalidTLD();
        if (!name.isValidDomainName()) revert InvalidTLD();
        if (tldContracts[tld] == address(0)) revert InvalidTLD();

        // Check if caller owns the domain
        NameService nameService = NameService(tldContracts[tld]);
        if (nameService.getDomainOwner(name) != msg.sender) revert NoDomain();

        mainDomain[msg.sender] = string(abi.encodePacked(name, ".", tld));
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

        // Return first available domain otherwise
        string[] memory domains = addressToDomains[addr];
        if (domains.length > 0) {
            return domains[0];
        }

        return "";
    }

    /**
     * @notice Unified resolver function for all TLDs
     * @param name Domain name without TLD
     * @param tld Top-level domain
     * @return owner Domain owner address
     * @return expiration Domain expiration timestamp
     * @return nftAddress Associated NFT contract address
     * @return tokenId Associated token ID
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
        if (contractAddress == address(0)) revert InvalidTLD();

        return NameService(contractAddress).resolveDomain(name);
    }

    /**
     * @notice Adds domain to address mapping (called by NameService contracts)
     * @param owner Domain owner address
     * @param domain Full domain name
     * @dev Internal function called by NameService contracts
     */
    function addDomainToAddress(
        address owner,
        string calldata domain
    ) external onlyNS {
        addressToDomains[owner].push(domain);
        domainToIndex[owner][domain] = addressToDomains[owner].length; // 1-based indexing
        // Auto-assign main domain if this is the only domain or first domain
        if (addressToDomains[owner].length == 1) {
            mainDomain[owner] = domain;
        }
    }

    /**
     * @notice Removes domain from address mapping (called by NameService contracts)
     * @param owner Domain owner address
     * @param domain Full domain name
     * @dev Internal function called by NameService contracts
     */
    function removeDomainFromAddress(
        address owner,
        string calldata domain
    ) external onlyNS {
        string[] storage domains = addressToDomains[owner];
        uint256 index = domainToIndex[owner][domain] - 1;
        if (index < domains.length) {
            domains[index] = domains[domains.length - 1];
            domainToIndex[owner][domains[index]] = index + 1;
            domains.pop();
            delete domainToIndex[owner][domain];
        }
        if (keccak256(bytes(mainDomain[owner])) == keccak256(bytes(domain))) {
            delete mainDomain[owner];
            if (domains.length > 0) {
                mainDomain[owner] = domains[0];
            }
        }
    }

    receive() external payable {}
}
