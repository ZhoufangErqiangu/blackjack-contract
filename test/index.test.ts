import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { ContractFactory } from "ethers";
import { strictEqual } from "node:assert";
import { describe, test } from "mocha";
import { Blackjack as BlackjackContract } from "../typechain-types/contracts/Blackjack";
import { Token as TokenContract } from "../typechain-types/contracts/Token";
import { b2n, n2b } from "../utils/math";

// @ts-ignore
import { ethers } from "hardhat";

const CARDS = [
  // spade
  0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19,
  // spade 10
  0x1a,
  // spade J
  0x1b,
  // spade Q
  0x1c,
  // spade K
  0x1d,
  // heart
  0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29,
  // heart 10
  0x2a,
  // heart J
  0x2b,
  // heart Q
  0x2c,
  // heart K
  0x2d,
  // diamond
  0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39,
  // diamond 10
  0x3a,
  // diamond J
  0x3b,
  // diamond Q
  0x3c,
  // diamond K
  0x3d,
  // club
  0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49,
  // club 10
  0x4a,
  // club J
  0x4b,
  // club Q
  0x4c,
  // club K
  0x4d,
  // NO JOKERS
];

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
      await blackjack.getToken(),
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
      await blackjack.getBet(),
      betAmount,
      "blackjack bet amount not match",
    );

    const betAmount2 = n2b(2, 18);
    await blackjack.setBet(betAmount2);
    strictEqual(
      await blackjack.getBet(),
      betAmount2,
      "blackjack bet amount not match",
    );
  });
  test("should be right cards", async () => {
    const { blackjack } = await loadFixture(depoly);
    const cards = await blackjack.getCards();
    strictEqual(cards.length, 52, "cards length not match");
    strictEqual(cards.length, CARDS.length, "cards length not match");
    for (let i = 0; i < cards.length; i++) {
      strictEqual(b2n(cards[i], 0), CARDS[i], "cards not match");
    }
    const cardsCount = await blackjack.getCardsCount();
    strictEqual(b2n(cardsCount, 0), 52, "cards count not match");
    strictEqual(b2n(cardsCount, 0), CARDS.length, "cards length not match");
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
    const betAmount = await blackjack.getBet();
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
    strictEqual(game.dealerCards.length, 1, "dealer cards length should be 1");
  });
  test("should be able to hit", async () => {
    const { other, blackjack, bet } = await loadFixture(depoly);
    const gameIndex = await blackjack.getNextGameIndex(other.address);
    const betAmount = await blackjack.getBet();
    await bet.connect(other).approve(await blackjack.getAddress(), betAmount);
    await blackjack.connect(other).start(false);
    await blackjack.connect(other).hit(gameIndex, false);
  });
  test("should be able to hit double", async () => {
    const { other, blackjack, bet } = await loadFixture(depoly);
    const gameIndex = await blackjack.getNextGameIndex(other.address);
    const betAmount = await blackjack.getBet();
    await bet.connect(other).approve(await blackjack.getAddress(), betAmount);
    await blackjack.connect(other).start(false);
    await bet.connect(other).approve(await blackjack.getAddress(), betAmount);
    await blackjack.connect(other).hit(gameIndex, true);
  });
  test("should be able to stop a game by stand", async () => {
    const { other, blackjack, bet } = await loadFixture(depoly);
    const betAmount = await blackjack.getBet();
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
