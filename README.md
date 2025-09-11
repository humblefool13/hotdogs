# HotDogs Naming Service (HNS)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-blue)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)

A professional, gas-optimized decentralized naming system that provides unified domain resolution across multiple TLDs with ERC721 NFT integration. Built with security, efficiency, and scalability in mind.

## 🚀 Features

- **Multi-TLD Support** - Register and manage multiple top-level domains
- **ERC721 NFT Integration** - Each domain is represented as a unique NFT with custom HotDogs design
- **Unified Resolution** - Single interface to resolve domains across all TLDs
- **Gas Optimized** - Efficient data structures and shared libraries reduce deployment and transaction costs
- **Automatic Fee Distribution** - 25% to development team, 75% to manager contract
- **Main Domain Concept** - Users can set a primary domain for reverse lookup
- **Global Reverse Lookup** - Find domains across all TLDs with one call
- **Expiration Management** - Efficient heap-based system for domain expiration handling
- **Marketplace Compatible** - Full ERC721 compliance with royalty support (EIP-2981)

## 📋 Table of Contents

- [Architecture](#architecture)
- [Smart Contracts](#smart-contracts)
- [Usage](#usage)
- [Security](#security)
- [API Reference](#api-reference)
- [License](#license)

## 🏗️ Architecture

The HotDogs Naming Service consists of five main components:

```
HNSManager (Central Manager)
├── SVG Library (Shared, deployed once)
├── DomainUtils Library (Validation utilities)
├── TokenURILibrary (Metadata generation)
├── MinHeap Library (Expiration management)
├── TLD: "hotdogs" → NameService Contract
├── TLD: "rise" → NameService Contract
└── ... (additional TLDs)

NameService Contracts (per TLD)
├── Domain registrations & renewals
├── ERC721 NFT minting with custom metadata
├── Domain ownership management
├── Expiration handling with automatic cleanup
└── Fee distribution to manager
```

### Core Components

1. **HNSManager** - Central orchestrator managing TLD deployments and global resolution
2. **NameService** - Individual TLD contracts handling domain operations and NFT minting
3. **SVGLibrary** - Shared SVG generation for consistent NFT artwork
4. **DomainUtils** - Domain validation and parsing utilities
5. **TokenURILibrary** - Metadata generation for NFT marketplaces
6. **MinHeap** - Efficient expiration management system

## 💰 Pricing Structure

| Domain Length | Price per Year | Example |
|---------------|----------------|---------|
| 3 characters  | 0.012 ETH      | `abc.hotdogs` |
| 4 characters  | 0.01 ETH       | `test.hotdogs` |
| 5 characters  | 0.008 ETH      | `hello.hotdogs` |
| 6 characters  | 0.006 ETH      | `domain.hotdogs` |
| 7+ characters | 0.004 ETH      | `mycompany.hotdogs` |

## 🔧 Smart Contracts

### HNSManager.sol

**Purpose**: Central orchestrator managing TLD deployments and global resolution

**Key Features**:
- Deploys and manages SVG library
- Creates new TLD contracts on-demand
- Maintains global TLD registry
- Provides unified domain resolution interface
- Manages global address-to-domain mappings
- Handles main domain concept for reverse lookup

**Key Functions**:
```solidity
function addTLD(string calldata tld) external onlyOwner
function resolve(string calldata name, string calldata tld) external view returns (address, uint256, address, uint256)
function setMainDomain(string calldata domain) external
function reverseLookup(address addr) external view returns (string memory)
function withdrawFunds() external onlyOwner
```

### NameService.sol

**Purpose**: Individual TLD contract handling domain operations and NFT minting

**Key Features**:
- Domain registration and renewal (1-10 years)
- ERC721 NFT minting with custom metadata
- Domain ownership management and transfers
- Automatic expiration handling with heap-based cleanup
- Fee distribution (25% dev, 75% manager)
- EIP-2981 royalty support for marketplaces

**Key Functions**:
```solidity
function register(string calldata name, uint256 yearsToRegister) external payable
function renew(string calldata name, uint256 yearsToRenew) external payable
function transferDomain(string calldata name, address to) external
function isDomainAvailable(string calldata name) external view returns (bool)
function getDomainInfo(string calldata name) external view returns (address, uint256, uint256, uint256)
function cleanupExpiredDomains(uint256 maxDomains) external
```

### SVGLibrary.sol

**Purpose**: Shared SVG generation for consistent NFT artwork

**Key Features**:
- Generates HotDogs-themed SVG images
- Reduces contract size and gas costs
- Provides consistent visual design across all TLDs
- Pure function implementation for gas efficiency

### DomainUtils.sol

**Purpose**: Domain validation and parsing utilities

**Key Features**:
- TLD validation (3-10 lowercase letters)
- Domain name validation (3-10 chars, alphanumeric + hyphens)
- Domain parsing (extract name/TLD from full domain)
- Input sanitization and format checking

### TokenURILibrary.sol

**Purpose**: Metadata generation for NFT marketplaces

**Key Features**:
- Generates ERC721-compliant token URIs
- Base64 encoding for SVG images
- Rich metadata with domain information
- Marketplace-compatible JSON structure

### MinHeap.sol

**Purpose**: Efficient expiration management system

**Key Features**:
- O(log n) insertions and updates
- O(1) access to earliest expiration
- Efficient domain removal and updates
- Bounded cleanup to prevent gas bombs

## 📖 Usage

### Basic Operations

#### 1. Adding a New TLD
```solidity
// Only contract owner can add TLDs
HNSManager manager = HNSManager(managerAddress);
manager.addTLD("rise");
```

#### 2. Registering a Domain
```solidity
// Register "alice.hotdogs" for 2 years
NameService nameService = NameService(tldContractAddress);
nameService.register{value: 0.02 ether}("alice", 2);
```

#### 3. Renewing a Domain
```solidity
// Renew "alice.hotdogs" for 1 additional year
nameService.renew{value: 0.01 ether}("alice", 1);
```

#### 4. Transferring Domain Ownership
```solidity
// Transfer domain to new owner
nameService.transferDomain("alice", newOwnerAddress);
```

#### 5. Setting Main Domain
```solidity
// Set primary domain for reverse lookup
manager.setMainDomain("alice.hotdogs");
```

### Advanced Operations

#### Global Reverse Lookup
```solidity
// Get main domain or first available domain for an address
string memory domain = manager.reverseLookup(userAddress);
```

#### Domain Resolution
```solidity
// Get complete domain information
(address owner, uint256 expiration, address nftAddress, uint256 tokenId) = 
    manager.resolve("alice", "hotdogs");
```

#### Checking Domain Availability
```solidity
// Check if domain is available for registration
bool available = nameService.isDomainAvailable("alice");
```

#### Getting Domain Information
```solidity
// Get detailed domain information
(address owner, uint256 expiration, uint256 registrationDate, uint256 renewalCount) = 
    nameService.getDomainInfo("alice");
```

### NFT Operations

#### Transferring Domain NFT
```solidity
// Transfer the NFT (automatically updates domain ownership)
IERC721(nameServiceAddress).transferFrom(from, to, tokenId);
```

#### Checking Royalty Information
```solidity
// Get royalty information for marketplace integration
(address receiver, uint256 royaltyAmount) = nameService.royaltyInfo(tokenId, salePrice);
```

## 🔒 Security Features

### Access Control
- **Ownable Contracts** - Restricted access to management functions
- **Role-based Permissions** - Only authorized contracts can update mappings
- **Input Validation** - Comprehensive domain name and TLD validation
- **Reentrancy Protection** - Safe external calls with `nonReentrant` modifier

### Error Handling
- **Custom Errors** - Gas-optimized error handling instead of require statements
- **Input Sanitization** - Domain name validation prevents malicious inputs
- **Overflow Protection** - Safe math operations throughout
- **State Validation** - Comprehensive checks before state changes

### Contract Security
- **Immutable References** - Critical addresses are immutable after deployment
- **Bounded Operations** - Limited batch operations to prevent gas bombs
- **Expiration Handling** - Automatic cleanup prevents storage bloat
- **Transfer Safety** - Domain ownership updates on NFT transfers

## ⚡ Gas Optimization

### Architecture Optimizations
- **Shared Libraries** - SVG and utility libraries reduce contract size
- **Efficient Data Structures** - MinHeap for O(log n) expiration management
- **Minimal Storage Operations** - Optimized mappings and arrays
- **Batch Operations** - Bounded cleanup operations

### Code Optimizations
- **Custom Errors** - More gas-efficient than require statements
- **Pure Functions** - Library functions use minimal gas
- **Packed Structs** - Optimized struct layouts
- **Efficient Loops** - Minimal iterations in validation functions

## 📚 API Reference

### HNSManager Contract

| Function | Visibility | Description |
|----------|------------|-------------|
| `addTLD(string)` | external | Deploy new TLD contract |
| `resolve(string, string)` | external | Resolve domain to owner info |
| `setMainDomain(string)` | external | Set primary domain for address |
| `reverseLookup(address)` | external | Get main domain for address |
| `withdrawFunds()` | external | Withdraw accumulated fees |

### NameService Contract

| Function | Visibility | Description |
|----------|------------|-------------|
| `register(string, uint256)` | external payable | Register new domain |
| `renew(string, uint256)` | external payable | Renew domain registration |
| `transferDomain(string, address)` | external | Transfer domain ownership |
| `isDomainAvailable(string)` | external view | Check domain availability |
| `getDomainInfo(string)` | external view | Get domain details |
| `cleanupExpiredDomains(uint256)` | external | Clean up expired domains |

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

- **Documentation**: Check this README and inline code comments
- **Issues**: Open an issue on [GitHub](https://github.com/humblefool13/hotdogs/issues)
- **Discussions**: Use GitHub Discussions for questions and ideas
- **Security**: Report security issues privately via [Telegram](https://t.me/humblefool13)

## 🙏 Acknowledgments

- Built with [Foundry](https://getfoundry.sh/) framework
- Uses [OpenZeppelin](https://openzeppelin.com/) contracts for security
- Inspired by modern naming service architectures
- Designed for the HotDogs NFT community
- Secrets present in `foundry.toml` were accidentally pushed, and have been revoked from providers and thus are invalid.

---

**Made with ❤️ for the HotDogs community**
