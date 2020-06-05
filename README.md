# Minesweeper - Ruby Gosu
Minesweeper in Ruby using [Gosu Library](https://www.libgosu.org/).

The program is written in Ruby 2.6.0 and Gosu 0.15.1 using structured code, not OOP.

Available modes: Easy, Medium, Hard and (real time) Multiplayer.

# What does this program is about?
Minesweeper is a fun, classical game where the one who try to solve a level of this game without touching a single bomb.

The bombs will be spread throughout the board randomly and player will try to solve for the bomb positions with a time ticking on the top-left of their screen.

There is only one tool to be utilised in this game to be able to solve the puzzle, which is the flags.

However, the flags is not the only thing to be utilised in this game as each squares in each puzzles will indicate a number of bombs that is presented in its 8 adjacent squares.

Above is an accurate definition of the classical Minesweeper. However, this program does more than that.

Whenever a puzzle is finished, either losing or winning, the player will receive an endgame message, containing some basic informations and the rank about how well they do.

Ranking system depends purely on the time to solve the puzzle and how much flags are used.

Players can be ranked from A to F. However, the special ones will be ranked with ???.

Also, there is a multiplayer mode where players can compete against each other with their best possible time to solve a puzzle. Multiplayer mode is pretty much the same as single player mode; however, an end message pops up randomly or you have to wait for your opponent's board view to be able to play is what you will experience during multiplaying. 

Are you ready for a refined version of Minesweeper?

(The program will try to match players to each other as randomly as possible if there exists games in the game queue)

# This project is currently not in development
