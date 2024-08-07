// @ts-ignore
import { ethers } from "hardhat";
import { n2b } from "../utils/math";

async function main() {
  // deploy below
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error("deploy error", error);
  process.exitCode = 1;
});
