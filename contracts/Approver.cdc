import FungibleToken from "./FungibleToken.cdc"

pub contract Approver {

    pub event AllowanceCreated(by: Address?, value: UFix64)
    pub event AllowanceCapReceiverCreated(by: Address?)

    pub let AllowanceCapReceiverStoragePath: StoragePath
    pub let AllowanceCapReceiverPubPath: PublicPath

    // Allowance interfaces

    pub resource interface AllowanceInfo {
        pub var value: UFix64
        pub fun getVaultOwner(): Address
    }

    pub resource interface AllowanceProvider {
        pub fun withdraw(amount: UFix64): @FungibleToken.Vault
    }

    pub resource interface AllowanceManager {
        pub fun setAllowance(value: UFix64)
    }

    // Allowance resources

    pub resource Allowance: AllowanceInfo, AllowanceProvider, AllowanceManager {
        pub var value: UFix64
        priv let vaultCap: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>

        pub fun getVaultOwner(): Address {
            return self.vaultCap.address
        }

        pub fun setAllowance(value: UFix64) {
            self.value = value
        }

        pub fun withdraw(amount: UFix64): @FungibleToken.Vault {
            pre {
                amount <= self.value: "Withdraw amount exceed allowance value"
                amount <= self.vaultCap.borrow()!.balance: "Withdraw amount exceed vault's balance"
            }

            self.value = self.value - amount
            return <- self.vaultCap.borrow()!.withdraw(amount: amount)
        }

        init(value: UFix64, vaultCap: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>) {
            self.value = value
            self.vaultCap = vaultCap

            emit AllowanceCreated(by: self.owner?.address, value: value)
        }
    }

    // AllowanceCapReceiver interfaces

    pub resource interface AllowanceCapReceiverPublic {
        pub fun addAllowanceCap(_ allowance: Capability<&{AllowanceProvider, AllowanceInfo}>)
        pub fun getAllowanceCapsInfoByApprover(_ approver: Address): [&{AllowanceInfo}]
    }

    // AllowanceCapReceiver resources

    pub resource AllowanceCapReceiver: AllowanceCapReceiverPublic {
        priv var allowanceCaps: {Address: [Capability<&{AllowanceProvider, AllowanceInfo}>]}

        pub fun addAllowanceCap(_ cap: Capability<&{AllowanceProvider, AllowanceInfo}>) {
            // TODO: 需要这样写吗？取出来再重新赋值？
            let caps: [Capability<&{AllowanceProvider, AllowanceInfo}>] = self.allowanceCaps[cap.address] ?? []
            caps.append(cap)
            self.allowanceCaps[cap.address] = caps
        }

        pub fun getAllowanceCapsInfoByApprover(_ approver: Address): [&{AllowanceInfo}] {
            let infos: [&{AllowanceInfo}] = []
            if let caps = self.allowanceCaps[approver] {
                for cap in caps {
                    if let info = cap.borrow() {
                        infos.append(info)
                    }
                }
            }

            return infos
        }

        pub fun getAllowanceCapsByApprover(_ approver: Address): [Capability<&{AllowanceProvider, AllowanceInfo}>] {
            return self.allowanceCaps[approver] ?? []
        }

        init() {
            self.allowanceCaps = {}

            emit AllowanceCapReceiverCreated(by: self.owner?.address)
        }
    }

    pub fun createAllowance(value: UFix64, vaultCap: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>): @Allowance {
        return <- create Allowance(value: value, vaultCap: vaultCap)
    }

    pub fun createAllowanceCapReceiver(): @AllowanceCapReceiver {
        return <- create AllowanceCapReceiver()
    }

    init() {
        self.AllowanceCapReceiverStoragePath = /storage/allowanceCapReceiver
        self.AllowanceCapReceiverPubPath = /public/allowanceCapReceiverPublic
    }
}