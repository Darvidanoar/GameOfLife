.org $080D
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"

;******************************************************************
; Conway's Game of Life
; After Starting the game, draw some pixels on the screen using
; the mouse.
; Hit 'G' (for Go) to start the game or pause the game.
; Hit 'Q' (for Quit) to end the game and exit to basic.
; You can even draw pixels while the game is playing :-)
;******************************************************************

   jmp start

.include "..\INC\x16.inc"

; Zero Page
MOUSE_X           = $32
MOUSE_Y           = $34
ArrayPointer      = $36

; VERA
VSYNC_BIT         = $01

; PETSCII
SPACE             = $20
LO_HALF_BLOCK     = $62
CLR               = $93
RT_HALF_BLOCK     = $E1
HI_HALF_BLOCK     = $E2
UL_UR_LR_QUAD     = $FB
UR_LL_LR_QUAD     = $FE
CHAR_Q            = $51
CHAR_G            = $47

; Colors
WHITE             = 1
RED               = 2

; ARRAY DATA
ARRAY             = $0C00

; Global Variables
paint_color:    .byte WHITE << 4
Go_NoGo:        .byte $00
NeighbourCount:  .byte $00


start:
   ; clear screen
   lda #CLR
   jsr CHROUT

   ; enable VSYNC IRQ
   lda #VSYNC_BIT
   sta VERA_ien

   ; render palette selector
   stz VERA_ctrl
   lda #$11 ; stride = 1
   sta VERA_addr_bank
   lda #$B0
   sta VERA_addr_high
   stz VERA_addr_low

; render canvas - all white spaces
REMAINDER = 48 + (60)*128
   ldx #$00 ;(0)
   ldy #$1E ;(30)
@canvas_loop:
   lda #SPACE
   sta VERA_data0
   lda #(WHITE << 4)
   sta VERA_data0
   dex
   bne @canvas_loop
   cpy #0
   beq @init_select
   dey
   bra @canvas_loop

@init_select:
   ; enable default mouse cursor
   sec
   jsr SCREEN_MODE
   lda #1
   jsr MOUSE_CONFIG

   jsr ClearArray

main_loop:
   jsr GETIN
   cmp #CHAR_Q
   beq @exit ; Q was pressed
   cmp #CHAR_G ; GO!
   beq @go
   jsr get_mouse_xy
   bit #$01 
   beq @doLife ; not left button
   ; set color selection
   lda #(RED << 4)
   sta paint_color ; color << 4
   jsr paint_cell
   bra main_loop
@doLife:
   lda Go_NoGo
   beq main_loop
   jsr calculateCells
   jsr showNextGen
   bra main_loop
@go:
   lda Go_NoGo
   eor #$FF
   sta Go_NoGo
   bra main_loop
@exit:
   lda #CLR
   jsr CHROUT
   rts

get_mouse_xy: ; Output: A = button ID; X/Y = text map coordinates
   ldx #MOUSE_X
   jsr MOUSE_GET
   ; divide coordinates by 8
   lsr MOUSE_X+1
   ror MOUSE_X
   lsr MOUSE_X+1
   ror MOUSE_X
   lsr MOUSE_X+1
   ror MOUSE_X
   ldx MOUSE_X
   lsr MOUSE_Y+1
   ror MOUSE_Y
   lsr MOUSE_Y+1
   ror MOUSE_Y
   lsr MOUSE_Y+1
   ror MOUSE_Y
   ldy MOUSE_Y
   rts

paint_cell: 
; Input: X/Y = text map coordinates
; Input: paint_color
   phx
   phy
   stz VERA_ctrl
   lda #$01 ; stride = 0, bank 1
   sta VERA_addr_bank
   tya
   clc
   adc #$B0
   sta VERA_addr_high ; Y
   txa
   asl
   inc
   sta VERA_addr_low ; 2*X + 1
   lda paint_color
   sta VERA_data0
   ply
   plx
   rts

calculateCells:
; Calculate the next generation of cells and store them in the array
; Starting at the bottom right (79,59), check each cell back towards the top left (0,0)
   lda #<ARRAY
   sta ArrayPointer
   lda #>ARRAY
   sta ArrayPointer+1

   ldx #$4F ;(79)
@CCCols:
   ldy #$3B ;(59)
@CCRows:
   jsr checkNeighbours
   lda paint_color
   sta (ArrayPointer)
   clc
   lda #$01
   adc ArrayPointer
   sta ArrayPointer
   lda #$00
   adc ArrayPointer+1
   sta ArrayPointer+1
   dey
   bne @CCRows
   dex
   bne @CCCols
   rts

checkNeighbours:
; Input: X/Y = text map coordinates
; Sets PaintColour for result
   phx
   phy
   jsr getCell
   sta paint_color
   stz NeighbourCount
   ; start at topleft and look at all the neighbours
   dex
   dey
   jsr getCell
   cmp #(WHITE << 4)
   beq @topmiddle
   inc NeighbourCount ; increment the count
@topmiddle:
   inx
   jsr getCell
   cmp #(WHITE << 4)
   beq @topright
   inc NeighbourCount ; increment the count
@topright:
   inx
   jsr getCell
   cmp #(WHITE << 4)
   beq @right
   inc NeighbourCount ; increment the count
@right:
   iny
   jsr getCell
   cmp #(WHITE << 4)
   beq @bottomright
   inc NeighbourCount ; increment the count
@bottomright:
   iny
   jsr getCell
   cmp #(WHITE << 4)
   beq @bottommiddle
   inc NeighbourCount ; increment the count
@bottommiddle:   
   dex
   jsr getCell
   cmp #(WHITE << 4)
   beq @bottomleft
   inc NeighbourCount ; increment the count
@bottomleft:
   dex
   jsr getCell
   cmp #(WHITE << 4)
   beq @left
   inc NeighbourCount ; increment the count
@left:
   dey
   jsr getCell
   cmp #(WHITE << 4)
   beq @done
   inc NeighbourCount ; increment the count
@done:
   lda NeighbourCount
   cmp #$03 ; has three neighbours?
   beq @CellLives
   cmp #$02
   bne @CellDies
   bra @checkNeighboursEnd
@CellDies:
   lda #(WHITE << 4)
   sta paint_color ; color << 4  
   bra @checkNeighboursEnd
@CellLives:
   lda #(RED << 4)
   sta paint_color ; color << 4
@checkNeighboursEnd:
   ply
   plx
   rts

showNextGen:
; Draw the results of the next generation from the array to the screen
   lda #<ARRAY
   sta ArrayPointer
   lda #>ARRAY
   sta ArrayPointer+1

   ldx #$4F ;(79)
@SNGCols:
   ldy #$3B ;(59)
@SNGRows:
   lda (ArrayPointer)
   sta paint_color
   jsr paint_cell
   clc
   lda #$01
   adc ArrayPointer
   sta ArrayPointer
   lda #$00
   adc ArrayPointer+1
   sta ArrayPointer+1
   dey
   bne @SNGRows
   dex
   bne @SNGCols
   rts


ClearArray:
; Calculate the next generation of cells and store them in the array
   lda #<ARRAY
   sta ArrayPointer
   lda #>ARRAY
   sta ArrayPointer+1

   ldx #$4F ;(79)
@CACols:
   ldy #$3B ;(59)
@CARows:
   lda #$00
   sta (ArrayPointer)
   clc
   lda #$01
   adc ArrayPointer
   sta ArrayPointer
   lda #$00
   adc ArrayPointer+1
   sta ArrayPointer+1
   dey
   bne @CARows
   dex
   bne @CACols
   rts

getCell: 
   ; Input: X/Y = text map coordinates
   ; Output: A = value of the tile
   stz VERA_ctrl
   lda #$01 ; stride = 0, bank 1
   sta VERA_addr_bank
   tya
   clc
   adc #$B0
   sta VERA_addr_high ; Y
   txa
   asl
   inc
   sta VERA_addr_low ; 2*X + 1
   lda VERA_data0   
   rts

