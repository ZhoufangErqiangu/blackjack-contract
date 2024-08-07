// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract Blackjack is Ownable {
  IERC20 public _token;
  uint256 public _bet = 10 ** 18;

  uint256 public _cardsCount = 52;
  uint16[] public _cards = [
    // spade
    0x11,
    0x12,
    0x13,
    0x14,
    0x15,
    0x16,
    0x17,
    0x18,
    0x19,
    // spade 10
    0x1A,
    // spade J
    0x1B,
    // spade Q
    0x1C,
    // spade K
    0x1D,
    // heart
    0x21,
    0x22,
    0x23,
    0x24,
    0x25,
    0x26,
    0x27,
    0x28,
    0x29,
    // heart 10
    0x2A,
    // heart J
    0x2B,
    // heart Q
    0x2C,
    // heart K
    0x2D,
    // diamond
    0x31,
    0x32,
    0x33,
    0x34,
    0x35,
    0x36,
    0x37,
    0x38,
    0x39,
    // diamond 10
    0x3A,
    // diamond J
    0x3B,
    // diamond Q
    0x3C,
    // diamond K
    0x3D,
    // club
    0x41,
    0x42,
    0x43,
    0x44,
    0x45,
    0x46,
    0x47,
    0x48,
    0x49,
    // club 10
    0x4A,
    // club J
    0x4B,
    // club Q
    0x4C,
    // club K
    0x4D
    // NO JOKERS
  ];

  constructor(address aceptedToken) Ownable(msg.sender) {
    _token = IERC20(aceptedToken);
  }

  /**
   * set bet
   * @param bet bet amount
   */
  function setBet(uint256 bet) public onlyOwner {
    _bet = bet;
  }

  /**
   * @dev withdarw token
   * @param amount amount to withdraw
   */
  function withdraw(uint256 amount) public onlyOwner {
    _token.transfer(owner(), amount);
  }

  /**
   * @dev calcualte point of cards, returns hard point and ace count
   * @param cards array of card
   * @return point hard point
   * @return aceCount ace count
   */
  function calculatePoint(
    uint16[] memory cards
  ) public pure returns (uint256, uint256) {
    uint256 point = 0;
    uint256 aceCount = 0;

    // there is no need to use safe math here, as card point is limited
    // even if there is a bug causing add all card, the point will not overflow
    for (uint256 i = 0; i < cards.length; i++) {
      // use card point
      uint256 cp = cards[i] & 0x0F;
      // check if card is valid
      require(cp >= 1 && cp <= 13, "Invalid card");
      // count ace
      if (cp == 1) {
        aceCount++;
      }
      // add all point
      if (cp > 10) {
        point += 10;
      } else {
        point += cp;
      }
    }

    return (point, aceCount);
  }

  /**
   * @dev calculate point of player
   * @param cards array of card
   * @return point
   */
  function calculatePointPlayer(
    uint16[] memory cards
  ) public pure returns (uint256) {
    (uint256 point, uint256 aceCount) = calculatePoint(cards);

    // use soft ace
    while (point <= 11 && aceCount > 0) {
      point += 10;
      aceCount--;
    }

    return point;
  }

  /**
   * @dev calculate point of dealer
   * @param cards array of card
   * @param soft if dealer is soft
   * @return point
   */
  function calculatePointDealer(
    uint16[] memory cards,
    bool soft
  ) public pure returns (uint256) {
    (uint256 point, uint256 aceCount) = calculatePoint(cards);

    if (soft) {
      // use soft ace
      while (point <= 17 && aceCount > 0) {
        point += 10;
        aceCount--;
      }
    }

    return point;
  }

  /**
   * @dev draw cards
   * @return cards
   */
  function dealCards() public view returns (uint16[] memory) {
    // generate cards
    uint16[] memory cards = new uint16[](_cardsCount);
    for (uint256 i = 0; i < _cardsCount; i++) {
      cards[i] = _cards[i];
    }

    // shuffle cards
    for (uint256 i = 0; i < _cardsCount; i++) {
      // could use pyth random here
      uint256 j = i +
        (uint256(keccak256(abi.encodePacked(block.timestamp))) %
          (_cardsCount - i));
      uint16 temp = cards[i];
      cards[i] = cards[j];
      cards[j] = temp;
    }

    return cards;
  }

  enum GameStatus {
    Init,
    Playing,
    PlayerWin,
    DealerWin,
    Draw
  }

  struct Game {
    uint256 bet;
    bool dealerSoft;
    bool isDoubled;
    uint16[] cards;
    uint16[] playerCards;
    uint16[] dealerCards;
    uint256 nextCardIndex;
    GameStatus status;
  }

  // next game index
  mapping(address => uint256) public _nextGameIndex;
  // games
  mapping(address => mapping(uint256 => Game)) public _games;

  /**
   * @dev get next game index
   * @param player player address
   * @return next game index
   */
  function getNextGameIndex(address player) public view returns (uint256) {
    return _nextGameIndex[player];
  }

  function _getGame(
    address player,
    uint256 index
  ) internal view returns (Game storage) {
    return _games[player][index];
  }

  /**
   * @dev get game
   * @param player player address
   * @param index game index
   * @return game
   */
  function getGame(
    address player,
    uint256 index
  ) public view returns (Game memory) {
    return _getGame(player, index);
  }

  /**
   * @dev deal next card
   * @param game game
   * @param toPlayer if card is to player
   */
  function _dealNextCard(Game storage game, bool toPlayer) internal {
    // get next card
    uint16 card = game.cards[game.nextCardIndex];
    if (toPlayer) {
      // add card to player
      uint16[] memory playerCards = game.playerCards;
      uint16[] memory newPlayerCards = new uint16[](playerCards.length + 1);
      for (uint256 i = 0; i < playerCards.length; i++) {
        newPlayerCards[i] = playerCards[i];
      }
      newPlayerCards[playerCards.length] = card;
      // update game
      game.playerCards = newPlayerCards;
    } else {
      // add card to dealer
      uint16[] memory dealerCards = game.dealerCards;
      uint16[] memory newDealerCards = new uint16[](dealerCards.length + 1);
      for (uint256 i = 0; i < dealerCards.length; i++) {
        newDealerCards[i] = dealerCards[i];
      }
      newDealerCards[dealerCards.length] = card;
      // update game
      game.dealerCards = newDealerCards;
    }
    game.nextCardIndex += 1;
  }

  /**
   * @dev start game, this is the only way to start a new game
   * @param dealerSoft if dealer is soft
   * @return game index
   */
  function start(bool dealerSoft) public returns (uint256) {
    // check balance
    require(_token.balanceOf(msg.sender) >= _bet, "Insufficient balance");

    // transfer token
    _token.transferFrom(msg.sender, address(this), _bet);

    // generate cards
    uint16[] memory cards = dealCards();

    // deal cards
    uint16[] memory playerCards = new uint16[](2);
    uint16[] memory dealerCards = new uint16[](2);

    playerCards[0] = cards[0];
    playerCards[1] = cards[1];
    dealerCards[0] = cards[2];
    dealerCards[1] = cards[3];

    // set game
    uint256 gameIndex = _nextGameIndex[msg.sender];
    _games[msg.sender][gameIndex] = Game({
      bet: _bet,
      dealerSoft: dealerSoft,
      isDoubled: false,
      cards: cards,
      playerCards: playerCards,
      dealerCards: dealerCards,
      nextCardIndex: 4,
      status: GameStatus.Playing
    });
    _nextGameIndex[msg.sender] = gameIndex + 1;

    return gameIndex;
  }

  /**
   * @dev hit
   * @param index game index
   */
  function hit(uint256 index, bool isDouble) public {
    // check game status
    Game storage game = _getGame(msg.sender, index);
    require(game.status == GameStatus.Playing, "Game is not playing");

    if (isDouble) {
      // check balance
      require(_token.balanceOf(msg.sender) >= _bet, "Insufficient balance");

      // transfer token
      _token.transferFrom(msg.sender, address(this), _bet);

      // update game
      game.isDoubled = true;
      game.bet = _safeMul(game.bet, 2);
    }

    // add card to player
    _dealNextCard(game, true);

    _judgeGame(game, false);
  }

  /**
   * @dev stand
   * @param index game index
   */
  function stand(uint256 index) public {
    // check game status
    Game storage game = _getGame(msg.sender, index);
    require(game.status == GameStatus.Playing, "Game is not playing");

    _judgeGame(game, true);
  }

  /**
   * @dev judge game
   * @param game game
   * @param isStand if player stand
   */
  function _judgeGame(
    Game storage game,
    bool isStand
  ) internal returns (GameStatus) {
    // get player point
    uint256 playerPoint = calculatePointPlayer(game.playerCards);
    // check player bust
    if (playerPoint > 21) {
      game.status = GameStatus.DealerWin;
      return GameStatus.DealerWin;
    }

    // continue game
    if (!isStand) {
      return GameStatus.Playing;
    }

    // check dealer point
    uint256 dealerPoint = calculatePointDealer(
      game.dealerCards,
      game.dealerSoft
    );
    while (dealerPoint < 17) {
      // add card to dealer
      _dealNextCard(game, false);
      dealerPoint = calculatePointDealer(game.dealerCards, game.dealerSoft);
    }
    // check dealer bust
    if (dealerPoint > 21) {
      game.status = GameStatus.PlayerWin;

      // transfer token
      _token.transfer(msg.sender, _safeMul(game.bet, 2));

      return GameStatus.PlayerWin;
    }

    // check winner
    if (playerPoint > dealerPoint) {
      game.status = GameStatus.PlayerWin;

      // check blackjack
      if (game.playerCards.length == 2 && playerPoint == 21) {
        // transfer token
        _token.transfer(msg.sender, Math.mulDiv(game.bet, 3, 2));
      } else {
        // transfer token
        _token.transfer(msg.sender, _safeMul(game.bet, 2));
      }

      return GameStatus.PlayerWin;
    } else if (playerPoint < dealerPoint) {
      game.status = GameStatus.DealerWin;
      return GameStatus.DealerWin;
    } else {
      game.status = GameStatus.Draw;

      // transfer token
      _token.transfer(msg.sender, game.bet);

      return GameStatus.Draw;
    }
  }

  /**
   * @dev safe add
   * @param a number a
   * @param b number b
   */
  function _safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
    (bool isMathSafe, uint256 c) = Math.tryAdd(a, b);
    require(isMathSafe, "Sap: math error");
    return c;
  }

  /**
   * @dev safe sub, return a - b
   * @param a number a
   * @param b number b
   */
  function _safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    (bool isMathSafe, uint256 c) = Math.trySub(a, b);
    require(isMathSafe, "Sap: math error");
    return c;
  }

  /**
   * @dev safe mul
   * @param a number a
   * @param b number b
   */
  function _safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
    (bool isMathSafe, uint256 c) = Math.tryMul(a, b);
    require(isMathSafe, "Sap: math error");
    return c;
  }

  /**
   * @dev safe div, return a / b
   * @param a number a
   * @param b number b
   */
  function _safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    (bool isMathSafe, uint256 c) = Math.tryDiv(a, b);
    require(isMathSafe, "Sap: math error");
    return c;
  }
}
