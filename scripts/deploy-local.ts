// @ts-ignore
import { ethers } from "hardhat";

async function main() {
  // deploy bet token
  const bet = await ethers.deployContract("Token", ["Bet", "BET"]);
  await bet.waitForDeployment();
  console.log("BET deployed to", bet.target);

  // deploy blackjack
  const blackjack = await ethers.deployContract("Blackjack", [bet.target]);
  await blackjack.waitForDeployment();
  console.log("Blackjack deployed to", blackjack.target);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error("deploy error", error);
  process.exitCode = 1;
});
