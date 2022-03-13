import path from "path"
import { 
  emulator, 
  init,
  shallPass,
  getAccountAddress, 
  deployContractByName, 
  sendTransaction,
  executeScript,
  shallResolve
} from "flow-js-testing";

jest.setTimeout(50000)

describe("Approver", () => {
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, "..")
    const port = 8080
    await init(basePath, { port })
    await emulator.start(port)
    return await new Promise(r => setTimeout(r, 2000));
  })

  afterEach(async () => {
    await emulator.stop();
    return await new Promise(r => setTimeout(r, 2000));
  })

  it("should be ok if Bob transfer Alice's FUSD in the range of allowance", async () => {
    await deployContracts()
    // Alice's balance = 1000.0
    // Bob's allowance = 500.0
    await setupAccounts(1000.0, 500.0)

    const Alice = await getAccountAddress("Alice")
    const Bob = await getAccountAddress("Bob")
    const Carl = await getAccountAddress("Carl")

    let [tx, err] = await transferFrom(Bob, Alice, Carl, 100.0)
    expect(err).toBeNull()
    await checkBalance(Alice, 900.0)
    await checkBalance(Carl, 100.0)
    await checkAllowance(Alice, Bob, 400.0)
  })

  it("should be ok if Bob transfer Alice's FUSD which is exactly the allowance", async () => {
    await deployContracts()
    await setupAccounts(1000.0, 500.0)

    const Alice = await getAccountAddress("Alice")
    const Bob = await getAccountAddress("Bob")

    let [tx, err] = await transferFrom(Bob, Alice, Bob, 500.0)
    expect(err).toBeNull()
    await checkBalance(Alice, 500.0)
    await checkBalance(Bob, 500.0)
    await checkAllowance(Alice, Bob, 0.0)
  })

  it("should be ok if Bob transfer Alice's FUSD which is exactly Alice's balance", async () => {
    await deployContracts()
    await setupAccounts(1000.0, 1500.0)

    const Alice = await getAccountAddress("Alice")
    const Bob = await getAccountAddress("Bob")

    let [tx, err] = await transferFrom(Bob, Alice, Bob, 1000.0)
    expect(err).toBeNull()
    await checkBalance(Alice, 0.0)
    await checkBalance(Bob, 1000.0)
    await checkAllowance(Alice, Bob, 500.0)
  })

  it("should be failed if Bob transfer Alice's FUSD exceed allowance", async () => {
    await deployContracts()
    await setupAccounts(1000.0, 500.0)

    const Alice = await getAccountAddress("Alice")
    const Bob = await getAccountAddress("Bob")

    let [tx, err] = await transferFrom(Bob, Alice, Bob, 800.0)
    expect(err).not.toBeNull()
    expect(err.includes("Withdraw amount exceed allowance value")).toBeTruthy()
  })

  it("should be failed if Bob transfer Alice's FUSD exceed Alice's balance", async () => {
    await deployContracts()
    await setupAccounts(1000.0, 2000.0)

    const Alice = await getAccountAddress("Alice")
    const Bob = await getAccountAddress("Bob")

    let [tx, err] = await transferFrom(Bob, Alice, Bob, 1500.0)
    expect(err).not.toBeNull()
    expect(err.includes("Withdraw amount exceed vault's balance")).toBeTruthy()
  })

  it("should ok if Alice reset Bob's allowance", async () => {
    await deployContracts()
    await setupAccounts(1000.0, 2000.0)

    const Alice = await getAccountAddress("Alice")
    const Bob = await getAccountAddress("Bob")

    await checkAllowance(Alice, Bob, 2000.0)
    await checkAllowance_spender(Alice, Bob, 2000.0)

    await setAllowance(Alice, Bob, 100.0)

    await checkAllowance(Alice, Bob, 100.0)
    await checkAllowance_spender(Alice, Bob, 100.0)
  })

  it("should be failed if Bob want to transfer Alice's FUSD after Alice cancel the allowance", async () => {
    await deployContracts()
    await setupAccounts(1000.0, 1000.0)

    const Alice = await getAccountAddress("Alice")
    const Bob = await getAccountAddress("Bob")

    await cancelAllowance(Alice, Bob)
    await checkAllowance(Alice, Bob, "Could not borrow AllowanceInfo capability")
    await checkAllowance_spender(Alice, Bob, 0.0)
    let [tx, err] = await transferFrom(Bob, Alice, Bob, 100.0)
    expect(err).not.toBeNull()
    expect(err.includes("unexpectedly found nil while forcing an Optional value")).toBeTruthy()
  })

  it("should be ok if Bob transfer Alice's FUSD after Alice recover the allowance", async () => {
    await deployContracts()
    await setupAccounts(1000.0, 1000.0)

    const Alice = await getAccountAddress("Alice")
    const Bob = await getAccountAddress("Bob")

    await cancelAllowance(Alice, Bob)

    await recoverAllowance(Alice, Bob)
    await checkAllowance(Alice, Bob, 1000.0)
    await checkAllowance_spender(Alice, Bob, 1000.0)
    let [tx, err] = await transferFrom(Bob, Alice, Bob, 100.0)
    expect(err).toBeNull()
    await checkBalance(Alice, 900.0)
    await checkBalance(Bob, 100.0)
    await checkAllowance(Alice, Bob, 900.0)
    await checkAllowance_spender(Alice, Bob, 900.0)
  })
})

// Helpers

async function deployContracts() {
  const Alice = await getAccountAddress("Alice")
  await deploy(Alice, "Approver")
  await deploy(Alice, "FUSD")
}

async function setupAccounts(mintAmount, allowance) {
  const Alice = await getAccountAddress("Alice")
  const Bob = await getAccountAddress("Bob")
  const Carl = await getAccountAddress("Carl")

  await setupFUSDVault(Alice)
  await setupFUSDVault(Bob)
  await setupFUSDVault(Carl)

  await mintFUSD(Alice, mintAmount, Alice)
  await checkBalance(Alice, mintAmount)

  await setupAllowanceCapReceiver(Bob)
  await approve(Alice, Bob, allowance)

  await checkAllowance(Alice, Bob, allowance)
}

async function deploy(deployer, contractName) {
  const [deploymentResult, err] = await deployContractByName({ to: deployer, name: contractName})
}

async function setupFUSDVault(account) {
  const signers = [account]
  const name = "setup_fusd_vault"
  const [tx, error] = await shallPass(sendTransaction({ name: name, signers: signers }))
}

async function mintFUSD(minter, amount, recipient) {
  const signers = [minter]
  const args = [amount, recipient]
  const name = "mint_fusd"
  const [tx, error] = await shallPass(sendTransaction({ name: name, args: args, signers: signers }))
}

async function getFUSDBalance(account) {
  const [result, err] = await shallResolve(executeScript({name: "get_fusd_balance", args: [account]}))
  return parseFloat(result)
}

async function checkBalance(account, expectedBalance) {
  const balance = await getFUSDBalance(account)
  expect(balance).toBe(expectedBalance) 
}

// Approver

async function setupAllowanceCapReceiver(account) {
  const signers = [account]
  const name = "setup_allowance_cap_receiver"
  const [tx, error] = await shallPass(sendTransaction({ name: name, signers: signers }))
  expect(error).toBeNull()
}

async function approve(approver, spender, value) {
  const signers = [approver]
  const name = "approve"
  const args = [spender, value]
  const [tx, error] = await shallPass(sendTransaction({ name: name, signers: signers, args: args }))
  expect(error).toBeNull()
}

async function setAllowance(approver, spender, value) {
  const signers = [approver]
  const name = "set_allowance"
  const args = [spender, value]
  const [tx, error] = await shallPass(sendTransaction({ name: name, signers: signers, args: args }))
  expect(error).toBeNull()
}

async function transferFrom(spender, from, to, value) {
  const signers = [spender]
  const name = "transfer_from"
  const args = [from, to, value]
  return await sendTransaction({ name: name, signers: signers, args: args })
}

async function getAllowanceInfo_approver(approver, spender) {
  const name = "get_allowance_info_approver"
  const args = [approver, spender]
  return await executeScript({name: name, args: args})
}

async function getAllowanceInfos_spender(approver, spender) {
  const name = "get_allowance_infos_spender"
  const args = [approver, spender]
  return await executeScript({name: name, args: args})
}

async function checkAllowance(approver, spender, expectedValue) {
  const [result, err] = await getAllowanceInfo_approver(approver, spender)
  if (typeof(expectedValue) == "string") {
    expect(err.message.includes(expectedValue)).toBeTruthy()
  } else {
    const value = parseFloat(result.value)
    expect(value).toBe(expectedValue)
    expect(result.vaultOwner).toBe(approver)
  }
}

async function checkAllowance_spender(approver, spender, expectedValue) {
  const [result, err] = await getAllowanceInfos_spender(approver, spender)
  if (typeof(expectedValue) == "string") {
    expect(err.message.includes(expectedValue)).toBeTruthy()
    return
  }

  let info = null
  for (var i = 0; i < result.length; i++) {
    const tempInfo = result[i]
    if (tempInfo.vaultOwner == approver) {
      info = tempInfo
      break
    }
  }

  if (info == null) {
    expect(expectedValue).toEqual(0.0)
  } else {
    const value = parseFloat(info.value)
    expect(value).toBe(expectedValue)
    expect(info.vaultOwner).toBe(approver)
  }
}

async function cancelAllowance(approver, spender) {
  const signers = [approver]
  const name = "cancel_allowance"
  const args = [spender]
  const [tx, error] = await shallPass(sendTransaction({ name: name, signers: signers, args: args }))
  expect(error).toBeNull()
}

async function recoverAllowance(approver, spender) {
  const signers = [approver]
  const name = "recover_allowance"
  const args = [spender]
  const [tx, error] = await shallPass(sendTransaction({ name: name, signers: signers, args: args }))
  expect(error).toBeNull() 
}