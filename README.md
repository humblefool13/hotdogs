# HotDogs Naming Service (HNS)

A professional, gas-optimized decentralized naming system built on Ethereum that provides unified domain resolution across multiple TLDs, specifically designed for the HotDogs NFT project.

## Overview

The HotDogs Naming Service consists of three main contracts:

1. **HotDogsNamingService** - Central manager contract that handles TLD deployment and provides unified resolution
2. **NameService** - Individual TLD contracts that manage domain registrations, NFTs, and domain operations
3. **SVGLibrary** - Shared SVG generation library for gas optimization

## Architecture

```
HotDogsNamingService (Manager Contract)
├── SVG Library (Deployed once, shared)
├── TLD: "hotdogs" → NameService Contract Address
├── TLD: "rise" → NameService Contract Address
└── ... (more TLDs)

NameService Contracts (per TLD)
├── Domain registrations
├── NFT minting with HotDogs design
├── Domain management
└── Fee distribution
```

## Features

### Core Functionality
- **Multi-TLD Support** - Register and manage multiple top-level domains
- **NFT Integration** - Each domain is represented as an ERC721 NFT with HotDogs design
- **Unified Resolution** - Single interface to resolve domains across all TLDs
- **Automatic Fee Distribution** - 25% to dev fee recipient, 75% to manager contract
- **Main Domain Concept** - Users can set a primary domain for reverse lookup
- **Global Reverse Lookup** - Find domains across all TLDs with one call

### Domain Management
- Domain registration with configurable duration (1-10 years)
- Domain renewal and transfer
- Text record management
- Reverse lookup capabilities
- Expiration handling with automatic NFT burning

### Pricing Structure
- **3 characters**: 0.012 ETH/year
- **4 characters**: 0.01 ETH/year
- **5 characters**: 0.008 ETH/year
- **6 characters**: 0.006 ETH/year
- **7+ characters**: 0.004 ETH/year

## Smart Contracts

### HotDogsNamingService.sol

The central manager contract that:
- Deploys SVG library and new TLD contracts
- Maintains TLD registry with main domain concept
- Provides unified resolution interface
- Handles fee withdrawals
- Manages global address-to-domain mappings

**Key Functions:**
- `addTLD(string tld)` - Deploy new TLD contract
- `removeTLD(string tld)` - Remove TLD and clear mappings
- `resolve(string name, string tld)` - Unified domain resolution
- `withdrawFunds()` - Withdraw entire contract balance
- `setMainDomain(string domain)` - Set primary domain for address
- `reverseLookup(address addr)` - Global reverse lookup across all TLDs

### NameService.sol

Individual TLD contracts that:
- Handle domain registrations and renewals
- Mint ERC721 NFTs for domains with HotDogs design
- Manage domain ownership and transfers
- Handle fee distribution
- Integrate with SVG library for image generation

**Key Functions:**
- `register(string name, uint256 years, string record)` - Register new domain
- `renew(string name, uint256 years)` - Renew domain registration
- `transferDomain(string name, address to)` - Transfer domain ownership
- `setRecord(string name, string record)` - Set domain text record
- `burnExpiredDomain(string name)` - Burn expired domain NFT

### SVGLibrary.sol

Shared SVG generation library that:
- Generates HotDogs-themed NFT images
- Reduces contract size and gas costs
- Provides consistent visual design across all TLDs

## Deployment

### Prerequisites
- Foundry installed
- Private key with sufficient ETH for deployment
- Environment variables configured

### Environment Setup
```bash
# Create .env file
echo "PRIVATE_KEY=your_private_key_here" > .env
```

### Deploy Contracts
```bash
# Deploy to local network
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy to testnet
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
```

## Usage Examples

### Adding a New TLD
```solidity
// Only contract owner can add TLDs
hotDogsNamingService.addTLD("dao");
```

### Registering a Domain
```solidity
// Register "alice.hotdogs" for 2 years with a record
nameService.register("alice", 2, "Hello World");
```

### Setting Main Domain
```solidity
// Set primary domain for reverse lookup
hotDogsNamingService.setMainDomain("alice.hotdogs");
```

### Global Reverse Lookup
```solidity
// Get main domain or first available domain for an address
string memory domain = hotDogsNamingService.reverseLookup(userAddress);
```

### Resolving a Domain
```solidity
// Get domain information
(address owner, uint256 expiration, address nft) = hotDogsNamingService.resolve("alice", "hotdogs");
```

### Transferring Domain Ownership
```solidity
// Transfer domain to new owner
nameService.transferDomain("alice", newOwnerAddress);
```

## NFT Features

### Industry Standard Implementation
- **ERC721 Compliant** - Fully compatible with all marketplaces
- **Separate Collections** - Each TLD is a distinct NFT collection
- **Rich Metadata** - Comprehensive domain information in token URI
- **Automatic Expiration** - NFTs are burned when domains expire
- **Transfer Integration** - NFT transfer automatically updates domain ownership

### Metadata Structure
```json
{
  "name": "alice.hotdogs",
  "description": "A domain on the HotDogs Naming Service",
  "image": "data:image/svg+xml;base64,...",
  "external_url": "https://hotdogs.xyz",
  "attributes": [
    {"trait_type": "TLD", "value": "hotdogs"},
    {"trait_type": "Name Length", "value": "5"},
    {"trait_type": "Registration Date", "value": "1234567890"},
    {"trait_type": "Expiration Date", "value": "1234567890"},
    {"trait_type": "Renewal Count", "value": "0"},
    {"trait_type": "Record", "value": "Hello World"}
  ],
  "properties": {
    "files": [{"uri": "data:image/svg+xml;base64,...", "type": "image/svg+xml"}],
    "category": "domain",
    "domain": "alice.hotdogs",
    "tld": "hotdogs",
    "name": "alice",
    "record": "Hello World"
  }
}
```

## Security Features

- **Ownable Contracts** - Restricted access to management functions
- **Input Validation** - Comprehensive domain name validation
- **Reentrancy Protection** - Safe external calls
- **Access Control** - Owner-only functions for critical operations
- **Error Handling** - Custom errors for gas optimization
- **Contract Verification** - Only authorized contracts can update mappings

## Gas Optimization

- **SVG Library** - Shared across all TLD contracts
- **Efficient Data Structures** - Optimized mappings and arrays
- **Minimal Storage Operations** - Reduced gas costs
- **Custom Errors** - Instead of require statements
- **Batch Operations** - Where possible

## Testing

```bash
# Run all tests
forge test

# Run with coverage
forge coverage

# Run specific test
forge test --match-test testDomainRegistration
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Support

For questions and support, please open an issue on GitHub.
