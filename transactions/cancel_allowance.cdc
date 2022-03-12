transaction(spender: Address) {
    prepare(signer: AuthAccount) {
        let pathID = "fusdAllowanceFor".concat(spender.toString())
        let privatePath = PrivatePath(identifier: pathID)!
        let publicPath = PublicPath(identifier: pathID)!

        signer.unlink(privatePath)
        signer.unlink(publicPath)
    }
}