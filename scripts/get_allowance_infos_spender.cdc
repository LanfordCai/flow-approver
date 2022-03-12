import Approver from "../contracts/Approver.cdc"

pub struct AllowanceInfo {
    pub let value: UFix64
    pub let vaultOwner: Address

    init(value: UFix64, vaultOwner: Address) {
        self.value = value
        self.vaultOwner = vaultOwner
    }
}

pub fun main(approver: Address, spender: Address): [AllowanceInfo] {
    let receiver = getAccount(spender)
        .getCapability<&{Approver.AllowanceCapReceiverPublic}>(Approver.AllowanceCapReceiverPubPath)
        .borrow() 
        ?? panic("Could not borrow AllowanceCapReceiverPublic capability")

    let infos: [AllowanceInfo] = []
    for i in receiver.getAllowanceCapsInfoByApprover(approver) {
        infos.append(
            AllowanceInfo(value: i.value, vaultOwner: i.getVaultOwner())
        )
    }

    return infos
}