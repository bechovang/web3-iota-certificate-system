
# 🎓 VeriMove - Decentralized Career Verification Protocol

[![IOTA](https://img.shields.io/badge/IOTA-Network-blue?style=for-the-badge&logo=iota)](https://iota.org)
[![Move](https://img.shields.io/badge/Language-Move_Smart_Contract-green?style=for-the-badge)](https://move-language.com)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

> **VeriMove** is a decentralized career verification protocol built on the IOTA Blockchain. It tackles the issue of credential fraud by placing professional history on-chain as **Soulbound Career Items** – immutable, transparent, and fully traceable.

---

## 🌟 The Context

In the digital era, verifying the reputation of an organization or the competence of an individual is costly and time-consuming. VeriMove leverages the power of **Move VM** and IOTA's **Object-Centric** model to create a "Web3 version of LinkedIn":

*   **Trustless:** Eliminates intermediaries; trust is anchored in Smart Contracts.
*   **Immutable:** Once issued, certificates cannot be silently altered.
*   **Revocable:** Supports a revocation mechanism if fraud is detected – a critical feature often missing in standard NFTs.
*   **Object-Based:** Each credential is a distinct Object containing rich metadata, optimized for storage and query.


## ⚙️ Architecture & Workflow

VeriMove operates on a Two-layer Verification model:

### 1. System Layer (Admin)
*   **Authority:** Holds `VeriMoveAdminCap`.
*   **Role:** Performs KYC (Know Your Customer) for registering Organizations.
*   **Outcome:** Organization receives `is_verified: true` status (Blue Checkmark).

### 2. Organization Layer
*   **Authority:** Holds `OrgCap` (Organization Capability).
*   **Role:** Issues certificates (`CareerItem`) to employees or students.
*   **Special Power:** Can `Revoke` certificates if the holder is found to be fraudulent.

### 3. User Layer (Holder)
*   **Authority:** Owns the `CareerItem` Object.
*   **Feature:** Soulbound (non-transferable) to ensure authenticity and ownership.

---

## 🛠️ Tech Stack

*   **Language:** Move (Sui/IOTA variant).
*   **Blockchain:** IOTA (Layer 1).
*   **Pattern:** Custom Object Pattern (Optimized for Status management).
*   **Tools:** IOTA CLI, MoveStdlib.

---

## 💻 CLI Demo Walkthrough

The following steps replicate the actual operations performed on the blockchain:

### Step 1: Register Organization
*Scenario: "FPT Software" registers a business account.*
```bash
iota client call --package <PKG_ID> --module verimove --function register_organization \
--args "FPT Software" "Technology" "https://fpt-software.com/logo.png" \
--gas-budget 100000000
```

### Step 2: Admin KYC Verification
*Scenario: System Admin verifies the license and grants the Blue Checkmark.*
```bash
iota client call --package <PKG_ID> --module verimove --function verify_organization \
--args <ADMIN_CAP> <ORG_ID> \
--gas-budget 100000000
```

### Step 3: Issue Career Item (Certificate)
*Scenario: FPT Software confirms "Nguyen Van A" as a Senior Developer.*
```bash
iota client call --package <PKG_ID> --module verimove --function issue_career_item \
--args <ORG_ID> <ORG_CAP> 0x6 "Nguyen Van A" "Blockchain Developer" "Tech" "2023" "2024" "Web3 Project" <RECIPIENT_ADDR> \
--gas-budget 100000000
```

### Step 4: Verify Data (On-chain)
*Scenario: Reading data directly from the blockchain to validate the CV.*
```bash
iota client object <ITEM_ID>
```
*Actual Output:*
```json
{
  "fields": {
    "org_name": "FPT Software",
    "title": "Blockchain Developer",
    "status": 0,
    "holder_name": "Nguyen Van A"
  }
}
```



## 👨‍💻 Author

**Developed by Nguyen Ngoc Phuc**
*   *Passionate about Web3 & Blockchain Technology.*
*   *Focusing on Real-world Assets (RWA) and Identity solutions on IOTA/Sui.*

---
*Built with ❤️ on IOTA Network.*
