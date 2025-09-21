import Foundation

enum Suit: CaseIterable {
    case clubs, diamonds, hearts, spades

    var symbol: String {
        switch self {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        }
    }
}

enum Rank: String {
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "10"
    case jack = "J"
    case queen = "Q"
    case king = "K"
    case ace = "A"
    case joker = "JOKER"

    static let standardRanks: [Rank] = [
        .ace, .two, .three, .four, .five, .six, .seven, .eight, .nine, .ten, .jack, .queen, .king
    ]

    func possibleAdditions() -> [Int] {
        switch self {
        case .ace:
            return [1, 11]
        case .two:
            return [2]
        case .three:
            return [3]
        case .four:
            return [4]
        case .five:
            return [5]
        case .six:
            return [6]
        case .seven:
            return [7]
        case .eight:
            return [0]
        case .nine:
            return [0]
        case .ten:
            return [-10, 10]
        case .jack:
            return [10]
        case .queen:
            return [20]
        case .king:
            return [30]
        case .joker:
            return [50]
        }
    }
}

struct Card {
    let rank: Rank
    let suit: Suit?

    var description: String {
        if rank == .joker {
            return "JOKER"
        }
        return "\(suit?.symbol ?? "")\(rank.rawValue)"
    }

    func possibleAdditions(currentTotal: Int) -> [Int] {
        let additions = rank.possibleAdditions()
        if rank == .ace {
            return additions
        }
        if rank == .ten {
            return additions
        }
        return additions
    }
}

struct Deck {
    private(set) var cards: [Card]

    init(cards: [Card]) {
        self.cards = cards
    }

    static func standardShuffled() -> Deck {
        var cards: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.standardRanks {
                cards.append(Card(rank: rank, suit: suit))
            }
        }
        cards.append(Card(rank: .joker, suit: nil))
        cards.append(Card(rank: .joker, suit: nil))
        var deck = Deck(cards: cards)
        deck.shuffle()
        return deck
    }

    mutating func shuffle() {
        cards.shuffle()
    }

    mutating func draw(from discard: inout [Card]) -> Card? {
        if cards.isEmpty {
            if discard.isEmpty {
                return nil
            }
            cards = discard
            discard.removeAll()
            shuffle()
            print("山札がなくなったため、捨て札をシャッフルして山札に戻しました。")
        }
        return cards.popLast()
    }
}

struct Player {
    let name: String
    let isHuman: Bool
    var hand: [Card] = []
    var score: Int = 0
}

enum PlayerAction {
    case playFromHand(cardIndex: Int, addition: Int)
    case drawAndPlay
}

enum RoundOutcome {
    case bust(loser: Int)
    case jokerWin(winner: Int, loser: Int)
}

struct Game {
    var players: [Player]

    mutating func start() {
        print("=== 101 ゲームへようこそ ===")
        print("合計値が101を超えたプレイヤーが負けになります。")
        print("JOKERを100に重ねると一人勝ち！")
        var round = 1
        while !players.contains(where: { $0.score <= -5 }) {
            print("\n--- ラウンド \(round) 開始 ---")
            playRound(number: round)
            round += 1
        }
        if let finalLoser = players.enumerated().min(by: { $0.element.score < $1.element.score }) {
            print("\n*** ゲーム終了 ***")
            print("最終的な負けは \(players[finalLoser.offset].name) (\(finalLoser.element.score) ポイント) でした。")
            printScoreBoard()
        }
    }

    mutating func playRound(number: Int) {
        var deck = Deck.standardShuffled()
        var discard: [Card] = []
        for index in players.indices {
            players[index].hand.removeAll()
        }
        for _ in 0..<2 {
            for index in players.indices {
                if let card = deck.draw(from: &discard) {
                    players[index].hand.append(card)
                }
            }
        }

        var total = 0
        var direction = 1
        var currentIndex = Int.random(in: 0..<players.count)
        var previousPlayerIndex: Int? = nil
        var flowCount = 0

        roundLoop: while true {
            var player = players[currentIndex]
            print("\n場の合計値: \(total)")
            print("現在のプレイヤー: \(player.name)")
            if flowCount > 0 {
                print("現在、負けポイントは \(-(flowCount + 1)) になります。")
            }
            let action: PlayerAction
            if player.isHuman {
                action = promptHumanAction(for: player, total: total, deck: &deck, discard: &discard)
            } else {
                action = decideCPUAction(for: player, total: total, deck: deck)
                if case .drawAndPlay = action {
                    print("CPUの \(player.name) は山札から引いてプレイすることを選びました。")
                } else if case let .playFromHand(cardIndex, addition) = action {
                    let card = player.hand[cardIndex]
                    print("CPUの \(player.name) は手札の \(card.description) を使用します (加算値 \(addition >= 0 ? "+" : "")\(addition))。")
                }
            }

            let directionBeforePlay = direction
            var playedCard: Card
            var additionValue: Int
            var drewFromDeck = false

            switch action {
            case let .playFromHand(cardIndex, addition):
                playedCard = player.hand.remove(at: cardIndex)
                additionValue = addition
            case .drawAndPlay:
                guard let drawn = deck.draw(from: &discard) else {
                    print("山札からカードを引けませんでした。代わりに手札からプレイします。")
                    if player.hand.isEmpty {
                        print("手札がないためターンをスキップします。")
                        players[currentIndex] = player
                        currentIndex = nextPlayerIndex(from: currentIndex, direction: direction, playerCount: players.count)
                        continue
                    }
                    let fallbackIndex = 0
                    playedCard = player.hand.remove(at: fallbackIndex)
                    additionValue = chooseAutomaticAddition(for: playedCard, currentTotal: total)
                    print("代わりに \(playedCard.description) をプレイします。")
                    break
                }
                drewFromDeck = true
                playedCard = drawn
                if player.isHuman {
                    print("山札から \(playedCard.description) を引きました。")
                    additionValue = promptForAddition(for: playedCard, currentTotal: total)
                } else {
                    additionValue = chooseAutomaticAddition(for: playedCard, currentTotal: total)
                    print("CPUの \(player.name) は引いた \(playedCard.description) を (加算値 \(additionValue >= 0 ? "+" : "")\(additionValue)) でプレイします。")
                }
            }

            if playedCard.rank == .nine {
                direction *= -1
                print("9が出たため、進行方向が変更されました。")
            }

            let effectiveAddition: Int
            switch playedCard.rank {
            case .eight, .nine:
                effectiveAddition = 0
            default:
                effectiveAddition = additionValue
            }

            var outcome: RoundOutcome? = nil

            if playedCard.rank == .joker && total == 100 {
                let loserIndex: Int
                if let prev = previousPlayerIndex {
                    loserIndex = prev
                } else {
                    loserIndex = (currentIndex - directionBeforePlay + players.count) % players.count
                }
                outcome = .jokerWin(winner: currentIndex, loser: loserIndex)
                print("JOKERで一人勝ち！ \(player.name) が勝利し、\(players[loserIndex].name) が失点します。")
            } else {
                let newTotal = total + effectiveAddition
                if newTotal > 101 {
                    outcome = .bust(loser: currentIndex)
                    print("合計値が\(newTotal)となり101を超えました！ \(player.name) の負けです。")
                } else if newTotal == 101 {
                    flowCount += 1
                    total = 0
                    print("合計値が101になり流れました。負けポイントは \(-(flowCount + 1)) になります。")
                } else {
                    total = newTotal
                    print("\(player.name) のプレイ後の合計値は \(total) です。")
                }
            }

            discard.append(playedCard)

            if !drewFromDeck {
                if let replacement = deck.draw(from: &discard) {
                    player.hand.append(replacement)
                }
            }

            players[currentIndex] = player

            if let outcome = outcome {
                apply(outcome: outcome, flowCount: flowCount)
                break roundLoop
            }

            previousPlayerIndex = currentIndex
            currentIndex = nextPlayerIndex(from: currentIndex, direction: direction, playerCount: players.count)
        }

        print("ラウンド終了時のスコア：")
        printScoreBoard()
    }

    mutating func apply(outcome: RoundOutcome, flowCount: Int) {
        let penaltyMagnitude = flowCount + 1
        switch outcome {
        case let .bust(loser):
            players[loser].score -= penaltyMagnitude
            print("\(players[loser].name) は \(-penaltyMagnitude) ポイントを受け取りました。")
        case let .jokerWin(winner, loser):
            players[winner].score += penaltyMagnitude
            players[loser].score -= penaltyMagnitude
            print("\(players[winner].name) は \(penaltyMagnitude) ポイントを獲得し、\(players[loser].name) は \(-penaltyMagnitude) ポイントとなります。")
        }
    }

    mutating func promptHumanAction(for player: Player, total: Int, deck: inout Deck, discard: inout [Card]) -> PlayerAction {
        while true {
            print("あなたの手札:")
            for (idx, card) in player.hand.enumerated() {
                let additions = card.possibleAdditions(currentTotal: total)
                let additionDescriptions = additions.map { "\($0 >= 0 ? "+" : "")\($0)" }.joined(separator: ", ")
                print("  [\(idx)] \(card.description) (加算候補: \(additionDescriptions))")
            }
            print("行動を選択してください: 1) 手札から出して引く  2) 山札から引いてそのまま出す")
            guard let input = readLine(), !input.isEmpty else { continue }
            if input == "1" {
                print("出すカードの番号を入力してください:")
                guard let indexInput = readLine(), let cardIndex = Int(indexInput), player.hand.indices.contains(cardIndex) else {
                    print("無効な入力です。")
                    continue
                }
                let card = player.hand[cardIndex]
                let addition = promptForAddition(for: card, currentTotal: total)
                return .playFromHand(cardIndex: cardIndex, addition: addition)
            } else if input == "2" {
                return .drawAndPlay
            } else {
                print("1か2を入力してください。")
            }
        }
    }

    func promptForAddition(for card: Card, currentTotal: Int) -> Int {
        let options = card.possibleAdditions(currentTotal: currentTotal)
        if options.count == 1 {
            return options[0]
        }
        while true {
            print("使用する数値を選択してください (選択肢: \(options.map { String($0) }.joined(separator: ", "))):")
            if let input = readLine(), let value = Int(input), options.contains(value) {
                return value
            }
            print("無効な入力です。")
        }
    }

    func chooseAutomaticAddition(for card: Card, currentTotal: Int) -> Int {
        let options = card.possibleAdditions(currentTotal: currentTotal)
        if options.count == 1 {
            return options[0]
        }
        var bestValue = options[0]
        var bestScore = Int.min
        for value in options {
            let result = currentTotal + value
            var score = result
            if result > 101 {
                score = 101 - result
            } else if result == 101 {
                score = 101
            }
            if score > bestScore {
                bestScore = score
                bestValue = value
            }
        }
        return bestValue
    }

    func decideCPUAction(for player: Player, total: Int, deck: Deck) -> PlayerAction {
        var bestScore = Int.min
        var bestIndex: Int? = nil
        var bestAddition = 0
        for (idx, card) in player.hand.enumerated() {
            let options = card.possibleAdditions(currentTotal: total)
            for addition in options {
                if card.rank == .joker && total == 100 {
                    return .playFromHand(cardIndex: idx, addition: addition)
                }
                let newTotal = total + (card.rank == .eight || card.rank == .nine ? 0 : addition)
                var score = newTotal
                if newTotal == 101 {
                    score += 5
                }
                if newTotal > 101 {
                    score = -100 - (newTotal - 101)
                }
                if card.rank == .eight || card.rank == .nine {
                    score = total - 1
                }
                if score > bestScore {
                    bestScore = score
                    bestIndex = idx
                    bestAddition = addition
                }
            }
        }
        if let index = bestIndex, bestScore > -100 {
            return .playFromHand(cardIndex: index, addition: bestAddition)
        }
        if !deck.cards.isEmpty {
            return .drawAndPlay
        }
        if let index = bestIndex {
            return .playFromHand(cardIndex: index, addition: bestAddition)
        }
        return .drawAndPlay
    }

    func printScoreBoard() {
        for player in players {
            print("  \(player.name): \(player.score) ポイント")
        }
    }
}

func nextPlayerIndex(from index: Int, direction: Int, playerCount: Int) -> Int {
    let next = (index + direction) % playerCount
    return next >= 0 ? next : next + playerCount
}

func readCPUCount() -> Int {
    print("CPUプレイヤーの人数を入力してください (0以上):")
    while true {
        if let input = readLine(), let count = Int(input), count >= 0 {
            return count
        }
        print("0以上の整数を入力してください。")
    }
}

let cpuCount = readCPUCount()
var players: [Player] = []
players.append(Player(name: "あなた", isHuman: true))
if cpuCount == 0 {
    print("CPUなしでゲームを開始します。")
}
for index in 1...cpuCount {
    players.append(Player(name: "CPU\(index)", isHuman: false))
}

var game = Game(players: players)
game.start()
