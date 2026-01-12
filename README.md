# Merkle Airdrop with EIP-712 Signatures

This project implements a **secure and gas-efficient ERC20 airdrop system** using **Merkle Trees** and **EIP-712 typed data signatures**.
It ensures that **only eligible users can claim**, **only once**, and **only for the correct amount**.

Repository:
👉 [https://github.com/samirbenbouker/merkle-airdrop](https://github.com/samirbenbouker/merkle-airdrop)

---

## ✨ Features

* ✅ Merkle Tree eligibility verification
* ✅ EIP-712 off-chain user authorization
* ✅ Single-claim enforcement
* ✅ Gas-efficient on-chain validation
* ✅ Secure ERC20 transfers (OpenZeppelin)
* ✅ Foundry scripts for full automation
* ✅ Compatible with zkSync

---

## 🧠 High-Level Architecture

```text
Off-chain                         On-chain
────────────────────────────────────────────────
Addresses + amounts ───┐
                       ├─> Merkle Tree ──> Root  ──> MerkleAirdrop ──> ERC20 Transfer
User signs EIP-712 ────┘                   
```

---

## 📁 Project Structure

```text
.
├── src/
│   ├── MerkleAirdrop.sol
│   └── BagelToken.sol
│
├── script/
│   ├── GenerateInput.s.sol
│   ├── MakeMerkle.s.sol
│   ├── DeployMerkleAidrop.s.sol
│   ├── SplitSignature.s.sol
│   └── Interact.s.sol
│
├── test/
│   └── MerkleAirdrop.t.sol
│
├── interactZk.sh
├── Makefile
├── foundry.toml
└── README.md
```

---

## 📜 Smart Contract: `MerkleAirdrop.sol`

### Purpose

The `MerkleAirdrop` contract allows users to **claim ERC20 tokens** if and only if:

1. Their address is included in the Merkle Tree
2. They provide a **valid Merkle proof**
3. They provide a **valid EIP-712 signature**
4. They have **not claimed before**

---

### Key State Variables

```solidity
bytes32 private immutable i_merkleRoot;
IERC20 private immutable i_airdropToken;
mapping(address => bool) private s_hashClaimed;
```

* `i_merkleRoot`: Merkle Tree root
* `i_airdropToken`: ERC20 token being distributed
* `s_hashClaimed`: prevents double claims

---

### EIP-712 Typed Data

```solidity
struct AirdropClaim {
    address account;
    uint256 amount;
}
```

Type hash:

```text
AirdropClaim(address account,uint256 amount)
```

The contract uses OpenZeppelin’s `EIP712` implementation to securely verify signed messages.

---

### Claim Flow

```text
User
 ├─ Generates Merkle proof
 ├─ Signs EIP-712 message
 └─ Calls claim()

Contract
 ├─ Checks if already claimed
 ├─ Verifies EIP-712 signature
 ├─ Verifies Merkle proof
 ├─ Marks address as claimed
 └─ Transfers ERC20 tokens
```

---

### Security Considerations

| Threat           | Mitigation                 |
| ---------------- | -------------------------- |
| Double claim     | `mapping(address => bool)` |
| Invalid signer   | EIP-712 + ECDSA recovery   |
| Replay attack    | Domain separator           |
| Unsafe transfers | `SafeERC20`                |
| Merkle collision | Double `keccak256`         |

---

## 🛠 Scripts

### 1️⃣ Generate `input.json`

Creates the list of recipients and amounts.

```bash
forge script script/GenerateInput.s.sol:GenerateInput
```

Output:

```text
input.json
```

---

### 2️⃣ Generate Merkle Tree (`output.json`)

Computes:

* leaf nodes
* Merkle proofs
* Merkle root

```bash
forge script script/MakeMerkle.s.sol:MakeMerkle
```

Output:

```text
output.json
```

---

## 🚀 Deployment

### Step 1: Deploy Contracts

```bash
make deploy
```

Expected output:

```text
0: contract MerkleAirdrop 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
1: contract BagelToken   0x5FbDB2315678afecb367f032d93F642f64180aa3
```

---

## ✍️ EIP-712 Signature Generation

### Step 2: Generate the Digest

```bash
cast call 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512 \
"getMessageHash(address,uint256)" \
0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
25000000000000000000 \
--rpc-url http://localhost:8545
```

Result:

```text
0x184e30c4b19f5e304a89352421dc50346dad61c461e79155b910e73fd856dc72
```

---

### Step 3: Sign the Digest

⚠️ `--no-hash` is required because the digest is already hashed.

```bash
cast wallet sign --no-hash \
0x184e30c4b19f5e304a89352421dc50346dad61c461e79155b910e73fd856dc72 \
--private-key 0xac0974...
```

Signature:

```text
0xfbd2270e6f23fb5f...
```

---

## 📦 Claiming the Airdrop

```bash
forge script script/Interact.s.sol:ClaimAirdrop \
--rpc-url http://localhost:8545 \
--private-key 0x59c6995e... \
--broadcast
```

---

## ✅ Verifying Token Balance

```bash
cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 \
"balanceOf(address)" \
0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
```

Hex result:

```text
0x0000000000000000000000000000000000000000000000015af1d78b58c40000
```

Convert to decimal:

```bash
cast --to-dec 0x0000000000000000000000000000000000000000000000015af1d78b58c40000
```

Result:

```text
25000000000000000000
```

---

## ⚡ zkSync Support

Run the zkSync interaction script:

```bash
chmod +x interactZk.sh && ./interactZk.sh
```

---

## 🧪 Testing

The test suite covers:

* Valid and invalid Merkle proofs
* Signature verification
* Double claim prevention
* Token transfers
* Edge cases

```bash
forge test
```

---

## 🧩 Tech Stack

* Solidity `^0.8.24`
* Foundry
* OpenZeppelin
* EIP-712
* Merkle Trees
* Anvil / Cast
* zkSync
