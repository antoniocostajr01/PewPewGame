import Foundation
import Darwin
import AVFoundation

// MARK: - Entry Point

func startSystem() {
    let menu = """
         
     ▗▄▄▖ ▗▞▀▚▖▄   ▄ ▗▄▄▖ ▗▞▀▚▖▄   ▄  ▗▄▄▖▗▞▀▜▌▄▄▄▄  ▗▞▀▚▖
     ▐▌ ▐▌▐▛▀▀▘█ ▄ █ ▐▌ ▐▌▐▛▀▀▘█ ▄ █ ▐▌   ▝▚▄▟▌█ █ █ ▐▛▀▀▘
     ▐▛▀▘ ▝▚▄▄▖█▄█▄█ ▐▛▀▘ ▝▚▄▄▖█▄█▄█ ▐▌▝▜▌     █   █ ▝▚▄▄▖
     ▐▌              ▐▌              ▝▚▄▞▘                

    1 = Start Game
    0 = Finish Game
    
    """

    var option: String?
    repeat {
        print(menu)
        print("==> ", terminator: "")
        option = readLine()

        switch option {
        case "1": selectDifficult()
        case "0": break
        default: print("Invalid option")
        }
    } while option != "0"
}

// MARK: - Terminal Input Handling

func readWord(timeout: Int) -> String? {
    setRawMode(true)
    var word = ""
    let startTime = Date()

    while true {
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed >= Double(timeout) {
            setRawMode(false)
            return nil
        }

        if let char = readSingleChar(timeout: 1) {
            if char == "\n" || char == "\r" {
                break
            } else if char == "\u{7f}" || char == "\u{8}" {
                if !word.isEmpty {
                    word.removeLast()
                    print("\u{8} \u{8}", terminator: "")
                    fflush(stdout)
                }
            } else {
                word.append(char)
                print(char, terminator: "")
                fflush(stdout)
            }
        }
    }

    setRawMode(false)
    return word
}

func setRawMode(_ enabled: Bool) {
    var attr = termios()
    tcgetattr(STDIN_FILENO, &attr)
    if enabled {
        attr.c_lflag &= ~tcflag_t(ICANON | ECHO)
    } else {
        attr.c_lflag |= tcflag_t(ICANON | ECHO)
    }
    tcsetattr(STDIN_FILENO, TCSANOW, &attr)
}

func readSingleChar(timeout: Int) -> Character? {
    var readSet = fd_set()
    fdZero(&readSet)
    fdSet(fd: STDIN_FILENO, set: &readSet)

    var timeoutStruct = timeval(tv_sec: timeout, tv_usec: 0)
    let result = select(STDIN_FILENO + 1, &readSet, nil, nil, &timeoutStruct)

    if result > 0 {
        var buffer: UInt8 = 0
        if read(STDIN_FILENO, &buffer, 1) == 1 {
            return Character(UnicodeScalar(buffer))
        }
    }

    return nil
}

func fdZero(_ set: inout fd_set) {
    withUnsafeMutablePointer(to: &set.fds_bits) {
        $0.withMemoryRebound(to: Int32.self, capacity: 32) { ptr in
            for i in 0..<32 { ptr[i] = 0 }
        }
    }
}

func fdSet(fd: Int32, set: inout fd_set) {
    withUnsafeMutablePointer(to: &set.fds_bits) {
        $0.withMemoryRebound(to: Int32.self, capacity: 32) { ptr in
            ptr[Int(fd) / 32] |= 1 << (fd % 32)
        }
    }
}

func readLineWithTimeout(seconds: Int) -> String? {
    var input: String?
    let sema = DispatchSemaphore(value: 0)

    DispatchQueue.global().async {
        input = readLine()
        sema.signal()
    }

    let result = sema.wait(timeout: .now() + .seconds(seconds))
    return result == .success ? input : nil
}

func center(_ text: String, width: Int) -> String {
    let pad = max(0, width - text.count)
    let left = pad / 2
    let right = pad - left
    return String(repeating: " ", count: left) + text + String(repeating: " ", count: right)
}

// MARK: - Game Logic

func game(difficulty: String) {
    var score = 0
    var scoreAdd = 0
    var wordList: [String]
    var maxWords = 0
    var inputTime = 0
    var status = ""
    var shouldAddWord = true

    let antonioPew = "/Users/ticpucrs/Desktop/PewPewGame/PewPewGame/Musics/Antonio’s pew.m4a"
    let gabrielPew = "/Users/ticpucrs/Desktop/PewPewGame/PewPewGame/Musics/Gabi’s pew.m4a"
    let loseSong = "/Users/ticpucrs/Desktop/PewPewGame/PewPewGame/Musics/Som da derrota.m4a"
    let mistakeSong = "/Users/ticpucrs/Desktop/PewPewGame/PewPewGame/Musics/Som do erro.m4a"
    let timeSong = "/Users/ticpucrs/Desktop/PewPewGame/PewPewGame/Musics/Som de tempo.m4a"

    let musicPlayer = AudioPlayer()

    switch difficulty {
    case "Hard":
        wordList = Words.hardWords; maxWords = 6; inputTime = 3; scoreAdd = 15
    case "Easy":
        wordList = Words.easyWords; maxWords = 10; inputTime = 4; scoreAdd = 5
    default:
        wordList = Words.mediumWords; maxWords = 7; inputTime = 3; scoreAdd = 10
    }

    var gameArea: [String] = []

    while true {
        print("\u{001B}[2J\u{001B}[H", terminator: "")

        if shouldAddWord {
            let randomIndex = Int.random(in: 0..<wordList.count)
            gameArea.insert(wordList[randomIndex], at: 0)
        }

        if gameArea.count > maxWords {
            musicPlayer.play(song: loseSong)
            print("💥 The table is full! Game over ☠️.")
            print("Your score was: \(score)")
            break
        }

        if gameArea.isEmpty {
            let randomIndex = Int.random(in: 0..<wordList.count)
            gameArea.insert(wordList[randomIndex], at: 0)
        }

        drawBoard(score: score, status: status, gameArea: gameArea, maxWords: maxWords)

        print("\nType the word located at the base, you have \(inputTime) seconds: ", terminator: "")
        fflush(stdout)

        if let userInput = readWord(timeout: inputTime) {
            if userInput.lowercased() == gameArea.last?.lowercased() {
                musicPlayer.play(song: Bool.random() ? gabrielPew : antonioPew)
                status = " ✅ Correct! "
                gameArea.removeLast()
                score += scoreAdd
                shouldAddWord = false
            } else {
                status = " ❌ Wrong! "
                musicPlayer.play(song: mistakeSong)
                shouldAddWord = true
            }
        } else {
            status = " ⏰ Out of time ⏰ "
            musicPlayer.play(song: timeSong)
            shouldAddWord = true
        }

        print("\u{001B}[H\u{001B}[2J", terminator: "")
    }

    startSystem()
}

// MARK: - Board Drawing

private func drawBoard(score: Int, status: String, gameArea: [String], maxWords: Int) {
    let width = 40
    let borderTop = "╔" + String(repeating: "═", count: width) + "╗"
    let borderMid = "╠" + String(repeating: "═", count: width) + "╣"
    let borderBot = "╚" + String(repeating: "═", count: width) + "╝"

    func displayWidth(of text: String) -> Int {
        return text.reduce(0) { $0 + ($1.isASCII ? 1 : 2) }
    }

    func formatLine(_ text: String, _ isLast: Bool) -> String {
        let visibleWidth = displayWidth(of: text)
        let padding = max(0, width - visibleWidth)
        let left = padding / 2
        let right = padding - left
        let content = isLast ? "\u{001B}[0;32m" + text + "\u{001B}[0m" : text
        return "║" + String(repeating: " ", count: left) + content + String(repeating: " ", count: right) + "║"
    }

    print(borderTop)
    print(formatLine("PEWPEW GAME", false))
    print(borderMid)
    print(formatLine("Score: \(score)", false))
    print(formatLine("Status: \(status.trimmingCharacters(in: .whitespaces))", false))
    print(borderMid)
    print(formatLine("Falling Words", false))

    for i in 0..<gameArea.count {
        print(formatLine(gameArea[i].uppercased(), i == gameArea.count - 1))
    }

    for _ in 0..<(maxWords - gameArea.count) {
        print(formatLine("", false))
    }

    print(formatLine("🚀", false))
    print(borderBot)
}
