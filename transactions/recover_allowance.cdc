import Approver from "../contracts/Approver.cdc"

transaction(spender: Address) {
    prepare(signer: AuthAccount) {
        let pathID = "fusdAllowanceFor".concat(spender.toString())
        let storagePath = StoragePath(identifier: pathID)!
        let privatePath = PrivatePath(identifier: pathID)!
        let publicPath = PublicPath(identifier: pathID)!

        signer.link<&{Approver.AllowanceProvider, Approver.AllowanceInfo}>(privatePath, target: storagePath)
        signer.link<&{Approver.AllowanceInfo}>(publicPath, target: storagePath)

        signer.getCapability<&{Approver.AllowanceProvider, Approver.AllowanceInfo}>(privatePath).borrow()
            ?? panic("Could not get private {AllowanceProvider, AllowanceInfo} capability")
        signer.getCapability<&{Approver.AllowanceInfo}>(publicPath).borrow()
            ?? panic("Could not get public {AllowanceInfo} capability")
    }
}