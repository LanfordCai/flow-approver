import FUSD from "../contracts/FUSD.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"
import Approver from "../contracts/Approver.cdc"

transaction(spender: Address, value: UFix64) {
    let allowanceCap: Capability<&{Approver.AllowanceProvider, Approver.AllowanceInfo}>

    prepare(signer: AuthAccount) {
        signer.link<&{FungibleToken.Provider, FungibleToken.Balance}>(/private/fusdVault, target: /storage/fusdVault)
        let vaultCap = signer.getCapability<&{FungibleToken.Provider, FungibleToken.Balance}>(/private/fusdVault)!

        let allowance <- Approver.createAllowance(
            value: value, 
            vaultCap: vaultCap
        )

        let pathID = "fusdAllowanceFor".concat(spender.toString())
        let storagePath = StoragePath(identifier: pathID)!
        let publicPath = PublicPath(identifier: pathID)!
        let privatePath = PrivatePath(identifier: pathID)!

        signer.save(<- allowance, to: storagePath)

        signer.link<&{Approver.AllowanceInfo}>(publicPath, target: storagePath)

        signer.link<&{Approver.AllowanceProvider, Approver.AllowanceInfo}>(
            privatePath, 
            target: storagePath
        )

        self.allowanceCap = signer.getCapability<&{Approver.AllowanceProvider, Approver.AllowanceInfo}>(privatePath)
    }

    execute {
        let receiver = getAccount(spender).getCapability<&{Approver.AllowanceCapReceiverPublic}>(
            Approver.AllowanceCapReceiverPubPath).borrow()
            ?? panic("Could not borrow AllowanceCapReceiver capability")

        receiver.addAllowanceCap(self.allowanceCap)
    }
}