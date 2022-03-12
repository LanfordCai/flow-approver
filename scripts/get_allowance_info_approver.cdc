import Approver from "../contracts/Approver.cdc"

pub struct AllowanceInfo {
    pub let value: UFix64
    pub let vaultOwner: Address

    init(value: UFix64, vaultOwner: Address) {
        self.value = value
        self.vaultOwner = vaultOwner
    }
}

pub fun main(approver: Address, spender: Address): AllowanceInfo {
    let path = PublicPath(identifier: "fusdAllowanceFor".concat(spender.toString()))!
    let info = getAccount(approver)
        .getCapability<&{Approver.AllowanceInfo}>(path)
        .borrow() ?? panic("Could not borrow AllowanceInfo capability")

    return AllowanceInfo(value: info.value, vaultOwner: info.getVaultOwner())
}