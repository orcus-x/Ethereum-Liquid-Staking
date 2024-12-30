
# Ethereum Liquid Staking Project

This project migrates the Rust smart contract from the [mx-liquid-staking-sc](https://github.com/multiversx/mx-liquid-staking-sc) repository to Solidity. It leverages the Hardhat framework to provide a robust development and testing environment.

## Features

- **Smart Contract Migration**: Implements the functionality of the original Rust contract in Solidity.
- **Liquid Staking**: Provides staking capabilities with improved liquidity for Ethereum-based networks.
- **Hardhat Integration**: Utilizes Hardhat for development, testing, and deployment.
- **Multichain Support**: Configured for Ethereum Sepolia Testnet and Hardhat local blockchain.

## Prerequisites

Before setting up the project, ensure you have the following installed:

- [Node.js](https://nodejs.org/) (v16 or later recommended)
- [Hardhat](https://hardhat.org/)
- A wallet and private key for the Sepolia Testnet
- An Infura API key or equivalent RPC provider

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/ethereum-liquid-staking.git
   cd ethereum-liquid-staking
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Configure environment variables:
   Create a `.env` file in the project root with the following details:
   ```plaintext
   INFURA_API_KEY=your_infura_api_key
   OWNER=your_private_key
   ```

## Usage

### Compile the Contract
Compile the Solidity contract:
```bash
npx hardhat compile
```

### Deploy the Contract
Deploy the contract to the Sepolia Testnet:
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

### Test the Contract
Run tests on the Hardhat local blockchain or Sepolia Testnet:
```bash
npx hardhat test --network sepolia
```

### Interact with the Contract
Use Hardhat tasks to interact with the deployed contract. For example:
```bash
npx hardhat run scripts/interact.js --network sepolia
```

## Project Structure

- **`LiquidStaking.sol`**: Solidity implementation of the liquid staking smart contract.
- **`hardhat.config.js`**: Hardhat configuration file for networks and settings.
- **`scripts/`**: Deployment and interaction scripts.
- **`test/`**: Test cases for contract functionality.

## Configuration

### Hardhat Config
The `hardhat.config.js` is pre-configured with:
- Local Hardhat blockchain (chainId 1337)
- Sepolia Testnet with Infura support

### Environment Variables
The `.env` file handles sensitive data like your private key and Infura API key.

## Roadmap

1. Complete feature parity with the Rust contract.
2. Add advanced staking functionalities.
3. Deploy to Ethereum Mainnet and other EVM-compatible chains.

## Contributing

Contributions are welcome! To contribute:
1. Fork the repository.
2. Create a feature branch.
3. Submit a pull request with your changes.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Acknowledgements

- Inspired by the [mx-liquid-staking-sc](https://github.com/multiversx/mx-liquid-staking-sc) repository.
- Built with [Hardhat](https://hardhat.org/).

## Contact

For feedback or inquiries, feel free to reach out at [www.orcus.x@gmail.com].
