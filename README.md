# GameOfLife
Conway's Game of Life in 6502 Assember for the Commander X16 (continuing to learn 6502 assembly on the Commander X16)

This is a slightly modified variant of the game where:
- live cells that have two neighbours will age and eventually die
- live cells that have three neighbours will not age


![GameOfLife](/Life.png)

## Basic method of play
After starting the game, draw some pixels on the screen using the mouse.
- Hit 'G' (for Go) to start the game or pause the game and add more pixels.
- Hit 'Q' (for Quit) to end the game and exit to basic.

You can even draw pixels while the game is playing :-)

## The algorithm
Once 'G' is pressed and the game is running, the code starts at the bottom right of the screen and calculates whether the cell lives, dies or spawns a new automoton.
The results of these next generation calculations are stored in an array.  
After the entire screen has been checked, the results in the array (the next generation) is displayed on screen.
The process of calculating the next generation starts again.
