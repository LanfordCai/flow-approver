import FUSD from "../contracts/FUSD.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"
import Approver from "../contracts/Approver.cdc"

transaction {
    prepare(signer: AuthAccount) {
        if signer.borrow<&Approver.AllowanceCapReceiver>(from: Approver.AllowanceCapReceiverStoragePath) != nil {
            return
        }

        signer.save(
            <- Approver.createAllowanceCapReceiver(), 
            to: Approver.AllowanceCapReceiverStoragePath
        )

        signer.link<&{Approver.AllowanceCapReceiverPublic}>(
            Approver.AllowanceCapReceiverPubPath, 
            target: Approver.AllowanceCapReceiverStoragePath
        )
    }
}