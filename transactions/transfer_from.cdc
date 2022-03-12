import FUSD from "../contracts/FUSD.cdc"
import FungibleToken from "../contracts/FungibleToken.cdc"
import Approver from "../contracts/Approver.cdc"

transaction(from: Address, to: Address, value: UFix64) {
    let capReceiver: &Approver.AllowanceCapReceiver

    prepare(signer: AuthAccount) {
        self.capReceiver = signer.borrow<&Approver.AllowanceCapReceiver>(from: Approver.AllowanceCapReceiverStoragePath)
            ?? panic("Could not borrow AllowanceCapReceiver reference")
    }

    execute {
        let vaultReceiver = getAccount(to).getCapability<&{FungibleToken.Receiver}>(/public/fusdReceiver).borrow()
            ?? panic("Could not get Receiver capability")

        let cap = self.capReceiver.getAllowanceCapsByApprover(from)[0]
        vaultReceiver.deposit(from: <- cap.borrow()!.withdraw(amount: value))
    }
}