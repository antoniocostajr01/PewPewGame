//
//  Difficulty.swift
//  PewPewGame
//
//  Created by ticpucrs on 07/04/25.
//

func selectDifficult() {
    let difficultyOptions: String = """
    
    SELECT THE DIFFICULTY
    
    1 - Easy
    2 - Medium
    3 - Hard

    ==> 
    """
    
    var option: String?

    repeat {
        print(difficultyOptions, terminator: "")
        option = readLine()

        switch option {
        case "1":
            game(difficulty: "Easy")
        case "2":
            game(difficulty: "Medium")
        case "3":
            game(difficulty: "Hard")
        default:
            print("Invalid option")
        }

    } while !["1", "2", "3"].contains(option)
}

