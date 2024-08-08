// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract Blackjack is Ownable {
  IERC20 private _token;
  uint256 private _bet = 10 ** 18;

  uint16[] private _cards = [
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
  uint256 private _cardsCount = _cards.length;

  event GameStart(
    address indexed player,
    uint256 indexed index,
    bool dealerSoft,
    uint16 playerCard1,
    uint16 playerCard2,
    uint16 dealerCard1
  );
  event GameHit(
    address indexed player,
    uint256 indexed index,
    bool isDouble,
    uint16 card
  );
  event GameStand(address indexed player, uint256 indexed index);
  event GameEnd(
    address indexed player,
    uint256 indexed index,
    bool isDouble,
    GameStatus status
  );

  constructor(address aceptedToken) Ownable(msg.sender) {
    _token = IERC20(aceptedToken);
  }

  /**
   * @dev get token address
   */
  function getToken() public view returns (address) {
    return address(_token);
  }

  /**
   * @dev get bet
   */
  function getBet() public view returns (uint256) {
    return _bet;
  }

  /**
   * set bet
   * @param bet bet amount
   */
  function setBet(uint256 bet) public onlyOwner {
    _bet = bet;
  }

  /**
   * @dev get cards
   */
  function getCards() public view returns (uint16[] memory) {
    return _cards;
  }

  /**
   * @dev get cards count
   */
  function getCardsCount() public view returns (uint256) {
    return _cardsCount;
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
    PlayerBlackjack,
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
  mapping(address => uint256) private _nextGameIndex;
  // games
  mapping(address => mapping(uint256 => Game)) private _games;

  /**
   * @dev get next game index
   * @param player player address
   * @return next game index
   */
  function getNextGameIndex(address player) public view returns (uint256) {
    return _nextGameIndex[player];
  }

  /**
   * @dev get game
   * @param player player address
   * @param index game index
   */
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
    Game memory game = _getGame(player, index);

    if (game.status == GameStatus.Playing) {
      // hide dealer card
      uint16[] memory newDealerCards = new uint16[](game.dealerCards.length);
      newDealerCards[0] = game.dealerCards[0];
      game.dealerCards = newDealerCards;
      // hide game cards
      game.cards = new uint16[](0);
    }

    return game;
  }

  /**
   * @dev deal next card inner
   * @param originCards origin cards
   * @param card card to add
   * @return new cards
   */
  function _dealNextCardInner(
    uint16[] memory originCards,
    uint16 card
  ) public pure returns (uint16[] memory) {
    uint16[] memory newCards = new uint16[](originCards.length + 1);
    for (uint256 i = 0; i < originCards.length; i++) {
      newCards[i] = originCards[i];
    }
    newCards[originCards.length] = card;
    return newCards;
  }

  /**
   * @dev deal next card
   * @param game game
   * @param toPlayer if card is to player
   * @return card
   */
  function _dealNextCard(
    Game storage game,
    bool toPlayer
  ) internal returns (uint16) {
    // get next card
    uint16 card = game.cards[game.nextCardIndex];
    if (toPlayer) {
      // add card to player
      game.playerCards = _dealNextCardInner(game.playerCards, card);
    } else {
      // add card to dealer
      game.dealerCards = _dealNextCardInner(game.dealerCards, card);
    }
    game.nextCardIndex += 1;

    return card;
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

    emit GameStart(
      msg.sender,
      gameIndex,
      dealerSoft,
      playerCards[0],
      playerCards[1],
      dealerCards[0]
    );

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
    uint16 card = _dealNextCard(game, true);
    emit GameHit(msg.sender, index, isDouble, card);

    _judgeGame(game, index, false);
  }

  /**
   * @dev stand
   * @param index game index
   */
  function stand(uint256 index) public {
    // check game status
    Game storage game = _getGame(msg.sender, index);
    require(game.status == GameStatus.Playing, "Game is not playing");

    emit GameStand(msg.sender, index);

    _judgeGame(game, index, true);
  }

  /**
   * @dev judge game
   * @param index game index
   * @param game game
   * @param isStand if player stand
   */
  function _judgeGame(
    Game storage game,
    uint256 index,
    bool isStand
  ) internal returns (GameStatus) {
    // get player point
    uint256 playerPoint = calculatePointPlayer(game.playerCards);
    // check player bust
    if (playerPoint > 21) {
      game.status = GameStatus.DealerWin;
      emit GameEnd(msg.sender, index, game.isDoubled, GameStatus.DealerWin);
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
    bool playerBlackjack = game.playerCards.length == 2 && playerPoint == 21;
    while (dealerPoint < 17) {
      // add card to dealer
      _dealNextCard(game, false);
      dealerPoint = calculatePointDealer(game.dealerCards, game.dealerSoft);
    }
    // check dealer bust
    if (dealerPoint > 21) {
      if (playerBlackjack) {
        // player blackjack
        game.status = GameStatus.PlayerBlackjack;
        _playerWinTransfer(game);
        emit GameEnd(
          msg.sender,
          index,
          game.isDoubled,
          GameStatus.PlayerBlackjack
        );
        return GameStatus.PlayerBlackjack;
      } else {
        // player win
        game.status = GameStatus.PlayerWin;
        _playerWinTransfer(game);
        emit GameEnd(msg.sender, index, game.isDoubled, GameStatus.PlayerWin);
        return GameStatus.PlayerWin;
      }
    }

    // check winner
    bool dealerBlackjack = game.dealerCards.length == 2 && dealerPoint == 21;
    if (playerPoint > dealerPoint) {
      if (playerBlackjack) {
        // player blackjack
        game.status = GameStatus.PlayerBlackjack;
        _playerWinTransfer(game);
        emit GameEnd(
          msg.sender,
          index,
          game.isDoubled,
          GameStatus.PlayerBlackjack
        );
        return GameStatus.PlayerBlackjack;
      } else {
        // player win
        game.status = GameStatus.PlayerWin;
        _playerWinTransfer(game);
        emit GameEnd(msg.sender, index, game.isDoubled, GameStatus.PlayerWin);
        return GameStatus.PlayerWin;
      }
    } else if (playerPoint < dealerPoint) {
      // dealer win
      game.status = GameStatus.DealerWin;
      emit GameEnd(msg.sender, index, game.isDoubled, GameStatus.DealerWin);
      return GameStatus.DealerWin;
    } else {
      if (playerBlackjack && !dealerBlackjack) {
        // player blackjack
        game.status = GameStatus.PlayerBlackjack;
        _playerWinTransfer(game);
        emit GameEnd(
          msg.sender,
          index,
          game.isDoubled,
          GameStatus.PlayerBlackjack
        );
        return GameStatus.PlayerBlackjack;
      } else {
        // draw
        game.status = GameStatus.Draw;
        _drawTransfer(game);
        emit GameEnd(msg.sender, index, game.isDoubled, GameStatus.Draw);
        return GameStatus.Draw;
      }
    }
  }

  /**
   * @dev transfer token to player when player win
   * @param game game
   */
  function _playerWinTransfer(Game storage game) internal {
    uint256 bet = game.bet;

    // check blackjack
    if (game.status == GameStatus.PlayerBlackjack) {
      bet = Math.mulDiv(bet, 3, 2);
    }

    // check double
    if (game.isDoubled) {
      bet = _safeMul(bet, 2);
    }

    // transfer token
    _token.transfer(msg.sender, bet);
  }

  /**
   * @dev transfer token to player when draw
   * @param game game
   */
  function _drawTransfer(Game storage game) internal {
    uint256 bet = game.bet;

    // check double
    if (game.isDoubled) {
      bet = _safeMul(bet, 2);
    }

    // transfer token
    _token.transfer(msg.sender, bet);
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
