import Approver from "../contracts/Approver.cdc"

transaction(spender: Address, value: UFix64) {
    prepare(signer: AuthAccount) {
        let pathID = "fusdAllowanceFor".concat(spender.toString())
        let storagePath = StoragePath(identifier: pathID)!

        let allowance = signer.borrow<&Approver.Allowance>(from: storagePath)
            ?? panic("Could not borrow Allowance reference")

        allowance.setAllowance(value: value)
    }
}