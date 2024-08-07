import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ContractFactory } from "ethers";
import { strictEqual } from "node:assert";
import { describe, test } from "mocha";
import { Blackjack as BlackjackContract } from "../typechain-types/contracts/Blackjack";
import { Token as TokenContract } from "../typechain-types/contracts/Token";
import { b2n, n2b } from "../utils/math";

// @ts-ignore
import { ethers } from "hardhat";

async function depoly() {
  const [owner, other] = await ethers.getSigners();
  // token
  const Token: ContractFactory = await ethers.getContractFactory("Token");
  const bet = (await Token.deploy("Bet", "BET")) as TokenContract;

  // mint init token to owner and other
  const initAmount = n2b(1000, 18);
  await bet.mint(owner.address, initAmount);
  await bet.mint(other.address, initAmount);

  // blackjack
  const Blackjack: ContractFactory =
    await ethers.getContractFactory("Blackjack");
  const blackjack = (await Blackjack.deploy(
    await bet.getAddress(),
  )) as BlackjackContract;
  // mint init token to blackjack contract
  await bet.mint(await blackjack.getAddress(), initAmount);

  return { owner, other, bet, blackjack };
}

describe("deploy test", () => {
  test("should be right owner", async () => {
    const { owner, blackjack } = await loadFixture(depoly);
    strictEqual(
      await blackjack.owner(),
      owner.address,
      "blackjack owner not match",
    );
  });
  test("should be right token", async () => {
    const { bet, blackjack } = await loadFixture(depoly);
    strictEqual(
      await blackjack._token(),
      await bet.getAddress(),
      "blackjack token not match",
    );
  });
  test("should be right bet", async () => {
    const { blackjack } = await loadFixture(depoly);

    // set bet
    const betAmount = n2b(1, 18);
    await blackjack.setBet(betAmount);

    strictEqual(
      await blackjack._bet(),
      betAmount,
      "blackjack bet amount not match",
    );

    const betAmount2 = n2b(2, 18);
    await blackjack.setBet(betAmount2);
    strictEqual(
      await blackjack._bet(),
      betAmount2,
      "blackjack bet amount not match",
    );
  });
});

describe("calculate point test", () => {
  test("should be right point", async () => {
    const { blackjack } = await loadFixture(depoly);
    const res = await blackjack.calculatePoint([
      n2b(0x11, 0),
      n2b(0x12, 0),
      n2b(0x13, 0),
    ]);
    const point = b2n(res[0], 0);
    const aceCount = b2n(res[1], 0);
    strictEqual(point, 0x06, "point not match");
    strictEqual(aceCount, 1, "ace count not match");
  });
  test("should be right point", async () => {
    const { blackjack } = await loadFixture(depoly);
    const res = await blackjack.calculatePoint([
      n2b(0x21, 0),
      n2b(0x22, 0),
      n2b(0x23, 0),
    ]);
    const point = b2n(res[0], 0);
    const aceCount = b2n(res[1], 0);
    strictEqual(point, 0x06, "point not match");
    strictEqual(aceCount, 1, "ace count not match");
  });
  test("should be right point for player", async () => {
    const { blackjack } = await loadFixture(depoly);
    const res = await blackjack.calculatePointPlayer([
      n2b(0x21, 0),
      n2b(0x22, 0),
      n2b(0x23, 0),
    ]);
    const point = b2n(res, 0);
    strictEqual(point, 0x10, "point not match");
  });
  test("should be right point for dealer", async () => {
    const { blackjack } = await loadFixture(depoly);
    const res = await blackjack.calculatePointPlayer([
      n2b(0x21, 0),
      n2b(0x22, 0),
      n2b(0x23, 0),
    ]);
    const point = b2n(res, 0);
    strictEqual(point, 0x10, "point not match");
  });
  test("should be right point for dealer", async () => {
    const { blackjack } = await loadFixture(depoly);
    const res = await blackjack.calculatePointDealer(
      [n2b(0x21, 0), n2b(0x23, 0), n2b(0x23, 0)],
      false,
    );
    const point = b2n(res, 0);
    strictEqual(point, 0x07, "point not match");
  });
  test("should be right point for dealer", async () => {
    const { blackjack } = await loadFixture(depoly);
    const res = await blackjack.calculatePointDealer(
      [n2b(0x21, 0), n2b(0x22, 0), n2b(0x23, 0)],
      true,
    );
    const point = b2n(res, 0);
    strictEqual(point, 0x10, "point not match");
  });
  test("should be right point for dealer", async () => {
    const { blackjack } = await loadFixture(depoly);
    const res = await blackjack.calculatePointDealer(
      [n2b(0x21, 0), n2b(0x23, 0), n2b(0x23, 0)],
      true,
    );
    const point = b2n(res, 0);
    strictEqual(point, 0x11, "point not match");
  });
});

// the game is random, it is very hard to test the game
// so we just test the game can be played
// more test can be added in the future
describe("play game test", () => {
  test("should be able to start a game", async () => {
    const { other, blackjack, bet } = await loadFixture(depoly);
    const gameIndex = await blackjack.getNextGameIndex(other.address);
    const betAmount = await blackjack._bet();
    await bet.connect(other).approve(await blackjack.getAddress(), betAmount);
    await blackjack.connect(other).start(false);
    const gameIndexNext = await blackjack.getNextGameIndex(other.address);
    strictEqual(
      b2n(gameIndex, 0),
      b2n(gameIndexNext - 1n, 0),
      "game index should be increased",
    );
    const game = await blackjack.getGame(other.address, gameIndex);
    strictEqual(b2n(game.status, 0), 1, "game status should be 1");
    strictEqual(game.playerCards.length, 2, "player cards length should be 2");
    strictEqual(game.dealerCards.length, 2, "dealer cards length should be 2");
  });
  test("should be able to hit", async () => {
    const { other, blackjack, bet } = await loadFixture(depoly);
    const gameIndex = await blackjack.getNextGameIndex(other.address);
    const betAmount = await blackjack._bet();
    await bet.connect(other).approve(await blackjack.getAddress(), betAmount);
    await blackjack.connect(other).start(false);
    await blackjack.connect(other).hit(gameIndex, false);
  });
  test("should be able to hit double", async () => {
    const { other, blackjack, bet } = await loadFixture(depoly);
    const gameIndex = await blackjack.getNextGameIndex(other.address);
    const betAmount = await blackjack._bet();
    await bet.connect(other).approve(await blackjack.getAddress(), betAmount);
    await blackjack.connect(other).start(false);
    await bet.connect(other).approve(await blackjack.getAddress(), betAmount);
    await blackjack.connect(other).hit(gameIndex, true);
  });
  test("should be able to stop a game by stand", async () => {
    const { other, blackjack, bet } = await loadFixture(depoly);
    const betAmount = await blackjack._bet();
    await bet.connect(other).approve(await blackjack.getAddress(), betAmount);
    const gameIndex = await blackjack.getNextGameIndex(other.address);
    await blackjack.connect(other).start(false);
    await blackjack.connect(other).stand(gameIndex);
    const game = await blackjack.getGame(other.address, gameIndex);
    strictEqual(
      b2n(game.status, 0) > 1,
      true,
      "game status should be greater than 1",
    );
  });
});
