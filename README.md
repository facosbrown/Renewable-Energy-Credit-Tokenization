# 🌱 Renewable Energy Credit Tokenization

A Clarity smart contract for tokenizing renewable energy credits on the Stacks blockchain. This contract allows energy producers to mint tokens representing kilowatt-hours of renewable energy generation, creating a transparent and tradeable market for clean energy certificates.

## ✨ Features

- 🏭 **Producer Registration**: Register and certify renewable energy producers
- ⚡ **Credit Issuance**: Mint tokens representing kWh of renewable energy
- 💱 **Credit Trading**: Transfer energy credits between accounts
- 🗑️ **Credit Retirement**: Permanently retire credits to claim environmental benefits
- 📊 **Batch Operations**: Issue multiple credits in a single transaction
- 🌍 **Carbon Offset Calculation**: Calculate CO2 offset equivalent

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
clarinet new renewable-energy-project
cd renewable-energy-project
```

Copy the contract code into `contracts/renewable-energy-credits.clar`

### Testing

```bash
clarinet console
```

## 📖 Usage

### Register as Energy Producer

```clarity
(contract-call? .renewable-energy-credits register-producer "Solar Farm Alpha" "solar" "California, USA")
```

### Issue Energy Credits

```clarity
(contract-call? .renewable-energy-credits issue-credits 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM u1000 u1000000 "solar")
```

### Transfer Credits

```clarity
(contract-call? .renewable-energy-credits transfer-credits u500 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
```

### Retire Credits

```clarity
(contract-call? .renewable-energy-credits retire-credits u1 u250)
```

### Check Balance

```clarity
(contract-call? .renewable-energy-credits get-balance 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### View Credit Details

```clarity
(contract-call? .renewable-energy-credits get-credit-details u1)
```

## 🔧 Contract Functions

### Public Functions

- `register-producer` - Register a new energy producer
- `certify-producer` - Certify a producer (owner only)
- `issue-credits` - Issue new energy credits (owner only)
- `transfer-credits` - Transfer credits between accounts
- `retire-credits` - Permanently retire credits
- `batch-issue-credits` - Issue multiple credits at once

### Read-Only Functions

- `get-balance` - Get account token balance
- `get-producer-info` - Get producer details
- `get-credit-details` - Get specific credit information
- `get-total-supply` - Get total token supply
- `calculate-carbon-offset` - Calculate CO2 offset in grams
- `get-credit-value` - Get current value of a credit

## 🌟 Token Economics

- Each token represents 1 kWh of renewable energy
- Credits can be traded freely between accounts
- Retired credits are permanently burned from supply
- Carbon offset calculated at 453g CO2 per kWh

## 🛡️ Security Features

- Owner-only producer certification
- Producer verification for credit issuance
- Balance checks for transfers and retirements
- Immutable credit history tracking

## 📈 Roadmap

- [ ] Multi-signature producer approval
- [ ] Time-based credit expiration
- [ ] Integration with renewable energy APIs
- [ ] Advanced carbon offset calculations
- [ ] Marketplace integration

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [Clarinet Documentation](https://github.com/hirosystems/clarinet)
```

**Git Commit Message:**
```
feat: implement renewable energy credit tokenization MVP with producer registration and credit lifecycle management
```

**GitHub Pull Request Title:**
```
🌱 Add Renewable Energy Credit Tokenization Smart Contract
```

**GitHub Pull Request Description:**
```
## Summary
This PR introduces a comprehensive smart contract for tokenizing renewable energy credits on the Stacks blockchain. The contract enables the creation of a transparent marketplace for renewable energy certificates.

## What's Added
- ⚡ **Core tokenization system** using Clarity fungible tokens
- 🏭 **Producer registration and certification** system
- 💱 **Credit issuance, transfer, and retirement** functionality  
- 📊 **Batch operations** for efficient credit management
- 🌍 **Carbon offset calculations** for environmental impact tracking
- 🛡️ **Security controls** with owner permissions and validation checks

## Key Features
- Each token represents 1 kWh of renewable energy
- Complete credit lifecycle from generation to retirement
- Immutable tracking of all credit transactions
- Support for multiple renewable energy types (solar, wind, hydro, etc.)

## Testing
- All core functions tested via Clarinet console
- Error handling validated for edge cases
- Token economics verified for supply management

Ready for deployment and integration with renewable energy monitoring systems.
