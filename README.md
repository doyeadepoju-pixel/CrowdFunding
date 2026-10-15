# 🚀 CrowdFunding Smart Contract

A decentralized, trustless crowdfunding platform built on Ethereum using **Solidity** and the **Foundry** development framework. 

This project enables creators to launch target-based fundraising campaigns using custom ERC-20 tokens (or mock tokens for testnets). It features automated goal verification, trustless payout execution, and double-spend protected refunds for backers if a campaign fails to reach its funding target before the deadline.

---

## 📌 Features

- **Custom ERC-20 Token Support**: Fund campaigns using any standard ERC-20 token (includes `MockToken.sol` for local and testnet deployments).
- **Campaign Management**: Creators can set customizable funding goals, deadlines, and descriptions.
- **Trustless Refunds**: If a campaign misses its funding target before the deadline, contributors can claim 100% of their pledged tokens back.
- **Double-Spend & Reentrancy Protected**: Built with strict state checks and modern Solidity patterns to guard against standard smart contract vulnerabilities.
- **Foundry Toolchain**: Fully simulated unit testing, gas tracking, and script-based deployments.

---

## 🛠 Tech Stack

- **Smart Contracts**: Solidity (`^0.8.30`)
- **Token Standards**: OpenZeppelin ERC-20 (`IERC20`)
- **Development Framework**: [Foundry](https://getfoundry.sh/) (`forge`, `cast`)
- **Target Network**: Ethereum Sepolia Testnet

---

## 📂 Project Structure

```text
crowdfunding/
├── src/
│   ├── CrowdFunding.sol     # Main campaign logic & state management
│   └── MockToken.sol        # Standard ERC-20 token for testing
├── script/
│   └── CrowdFundingScript.s.sol # Deployment script
├── test/
│   └── CrowdFundingTest.t.sol   # Unit and integration tests
├── .env.example             # Template for required environment variables
├── foundry.toml             # Foundry configuration settings
└── README.md
