.segment "STARTUP"
;******************************************************************
; Conway's Game of Life
; After Starting the game, draw some pixels on the screen using
; the mouse.
; Hit 'G' (for Go) to start the game or pause the game.
; Hit 'Q' (for Quit) to end the game and exit to basic.
; You can even draw pixels while the game is playing :-)
;
; This variant has aging.  
; That is, a cell with two neighbours will age and go progressively
; darker.  A cell with three neighbours will be rejuvinated.
;******************************************************************

.segment "ZEROPAGE"
;******************************************************************
; The KERNAL and BASIC reserve all the addresses from $0080-$00FF. 
; Locations $00 and $01 determine which banks of RAM and ROM are  
; visible in high memory, and locations $02 through $21 are the
; pseudoregisters used by some of the new KERNAL calls
; (r0 = $02+$03, r1 = $04+$05, etc)
; So we have $22 through $7f to do with as we please, which is 
; where .segment "ZEROPAGE" variables are stored.
;******************************************************************

;.org $0022

; Zero Page
MOUSE_X:           .res 2
MOUSE_Y:           .res 2
ArrayPointer:      .res 2

; Global Variables
paint_color:       .byte BLACK << 4
Go_NoGo:           .byte $00
NeighbourCount:    .byte $00

.segment "INIT"
.segment "ONCE"
.segment "CODE"

.org $080D

   jmp start

.include "..\..\INC\x16.inc"

; VERA
VSYNC_BIT         = $01

; PETSCII
SPACE             = $20
CHAR_O            = $4f
CLR               = $93
HOME              = $13
CHAR_Q            = $51
CHAR_G            = $47
CHAR_ENTER        = $0D

; Colors
BLACK             = 0
RED               = 15

; ARRAY DATA
ARRAY             = $0C00

Title:          .byte "conway's game of life",CHAR_ENTER,CHAR_ENTER,CHAR_ENTER,CHAR_ENTER,$00
Instr1:         .byte "instructions:",CHAR_ENTER,CHAR_ENTER,$00
Instr2:         .byte " - draw cells with the mouse and then hit 'g' to go",CHAR_ENTER,CHAR_ENTER,$00
Instr3:         .byte " - hit 'g' while the game is running to stop",CHAR_ENTER,CHAR_ENTER,$00
Instr4:         .byte " - hit 'q' to quit the game",CHAR_ENTER,CHAR_ENTER,$00
Instr5:         .byte CHAR_ENTER,CHAR_ENTER,"this is a slightly modified variant of the game where cells that only have two ",CHAR_ENTER,"neighbours will age and eventually die.",CHAR_ENTER,CHAR_ENTER,$00
Instr6:         .byte CHAR_ENTER,CHAR_ENTER,"press enter to begin",$00


start:
   ; clear screen
   lda #CLR
   jsr CHROUT

   jsr intro

   lda #CHAR_O
   jsr ClearScreen
   jsr setPalette
   jsr showMouse
   jsr ClearArray



main_loop:
   jsr GETIN
   cmp #CHAR_Q
   beq @exit ; Q was pressed
   cmp #CHAR_G ; GO!
   beq @goNoGo
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
@goNoGo:
   lda Go_NoGo
   eor #$FF
   sta Go_NoGo
   beq @STOP
   jsr setPalette
   bra main_loop
@STOP:
   jsr showMouse
   bra main_loop
@exit:
   lda #SPACE
   jsr ClearScreen
   jsr exit_resetPalette
   lda #CLR
   jsr CHROUT
   rts



exit_resetPalette:
   ;set FG Palette to White
   stz VERA_ctrl
   lda #$11  ; bank 1, stride 1 (00000001)
   sta VERA_addr_bank
   lda #$FA
   sta VERA_addr_high
   lda #$02
   sta VERA_addr_low
   lda #$FF
   sta VERA_data0 ; set mouse colour
   sta VERA_data0
    ;set BG Palette to Blue
   stz VERA_ctrl
   lda #$11  ; bank 1, stride 1 (00000001)
   sta VERA_addr_bank
   lda #$FA
   sta VERA_addr_high
   lda #$0C
   sta VERA_addr_low
   lda #$0F
   sta VERA_data0 
   stz VERA_data0  
   rts

get_mouse_xy: 
; Output: A = button ID; X/Y = text map coordinates
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
   bpl @CCRows
   dex
   bpl @CCCols
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
   cmp #(BLACK << 4)
   beq @topmiddle
   inc NeighbourCount ; increment the count
@topmiddle:
   inx
   jsr getCell
   cmp #(BLACK << 4)
   beq @topright
   inc NeighbourCount ; increment the count
@topright:
   inx
   jsr getCell
   cmp #(BLACK << 4)
   beq @right
   inc NeighbourCount ; increment the count
@right:
   iny
   jsr getCell
   cmp #(BLACK << 4)
   beq @bottomright
   inc NeighbourCount ; increment the count
@bottomright:
   iny
   jsr getCell
   cmp #(BLACK << 4)
   beq @bottommiddle
   inc NeighbourCount ; increment the count
@bottommiddle:   
   dex
   jsr getCell
   cmp #(BLACK << 4)
   beq @bottomleft
   inc NeighbourCount ; increment the count
@bottomleft:
   dex
   jsr getCell
   cmp #(BLACK << 4)
   beq @left
   inc NeighbourCount ; increment the count
@left:
   dey
   jsr getCell
   cmp #(BLACK << 4)
   beq @done
   inc NeighbourCount ; increment the count
@done:
   lda NeighbourCount
   cmp #$03 ; has three neighbours?
   beq @CellLives
   cmp #$02 ; has two neighbours?
   bne @CellDies
   lda paint_color
   beq @checkNeighboursEnd
   sec ;age the cell
   sbc #$10 
   sta paint_color
   bra @checkNeighboursEnd
@CellDies:
   lda #(BLACK << 4)
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
   bpl @SNGRows
   dex
   bpl @SNGCols
   rts


ClearScreen:
   ; Input: A contains the charcter to write to the screen
   ; Clear the screen to black
   pha
   stz VERA_ctrl
   lda #$11 ; stride = 1
   sta VERA_addr_bank
   lda #$B0
   sta VERA_addr_high
   stz VERA_addr_low
TOTALPIXELCOUNT = 63*128
   ldx #<TOTALPIXELCOUNT ; #$00 ;(0)
   ldy #>TOTALPIXELCOUNT ; #$20 ;(32)
@canvas_loop:
   pla
   sta VERA_data0
   pha
   lda #(BLACK << 4)
   sta VERA_data0
   dex
   bne @canvas_loop
   cpy #$00
   beq @EndClearScreen
   dey
   bra @canvas_loop
@EndClearScreen:
   pla
   rts


ClearArray:
; Clear the contents of the array (probably not necessary)
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
   bpl @CARows
   dex
   bpl @CACols
   rts


getCell: 
   ; Input: X/Y = text map coordinates
   ; Output: A = value of the tile
   jsr checkXYWrap
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


checkXYWrap:
   ; Input X/Y = tex map coordinates
   ; this does screen wrap around
   txa
   cmp #$FF ; has x gone past the left border?
   bne @checkXRight
   ldx #$4F
@checkXRight:
   cmp #$50 ; has x gone past the right border?
   bne @checkYTop
   ldx #$00
@checkYTop:
   tya
   cmp #$FF ; has y gone past the top border?
   bne @checkYBottom
   ldy #$3B
@checkYBottom:
   cmp  #$3C ; has y gone past the bottom border?
   bne @endcheckXYWrap
   ldy #$00
@endcheckXYWrap:
   rts


setPalette:
; Sets the default paltte to shades of RED
; start with the vera palette address $1FA1F (colour 15)
   stz VERA_ctrl
   lda #$19  ; bank 1, stride -1 (00011001)
   sta VERA_addr_bank
   lda #$FA
   sta VERA_addr_high
   lda #$1F
   sta VERA_addr_low
   ldx #$0F
@loop:
   stx VERA_data0 
   stz VERA_data0
   dex
   bne @loop
   ; disable default mouse cursor
   sec
   jsr SCREEN_MODE
   lda #0
   jsr MOUSE_CONFIG
   rts


showMouse:
   ; enable default mouse cursor
   sec
   jsr SCREEN_MODE
   lda #1
   jsr MOUSE_CONFIG

   stz VERA_ctrl
   lda #$11  ; bank 1, stride 1 (00000001)
   sta VERA_addr_bank
   lda #$FA
   sta VERA_addr_high
   lda #$02
   sta VERA_addr_low
   lda #$FF
   sta VERA_data0 ; set mouse colour
   sta VERA_data0
   rts

intro:
   lda #HOME
   jsr CHROUT
   lda #CHAR_ENTER
   jsr CHROUT
;TITLE
   ldx #$00
@TitleLoop:
   lda Title,x
   beq @Titledone
   jsr CHROUT
   inx
   bne @TitleLoop
@Titledone:

;INSTRUCTION1
   ldx #$00
@Instr1Loop:
   lda Instr1,x
   beq @Instr1done
   jsr CHROUT
   inx
   bne @Instr1Loop
@Instr1done:

;INSTRUCTION2
   ldx #$00
@Instr2Loop:
   lda Instr2,x
   beq @Instr2done
   jsr CHROUT
   inx
   bne @Instr2Loop
@Instr2done:

;INSTRUCTION3
   ldx #$00
@Instr3Loop:
   lda Instr3,x
   beq @Instr3done
   jsr CHROUT
   inx
   bne @Instr3Loop
@Instr3done:

;INSTRUCTION4
   ldx #$00
@Instr4Loop:
   lda Instr4,x
   beq @Instr4done
   jsr CHROUT
   inx
   bne @Instr4Loop
@Instr4done:

;INSTRUCTION5
   ldx #$00
@Instr5Loop:
   lda Instr5,x
   beq @Instr5done
   jsr CHROUT
   inx
   bne @Instr5Loop
@Instr5done:

;INSTRUCTION6
   ldx #$00
@Instr6Loop:
   lda Instr6,x
   beq @Instr6done
   jsr CHROUT
   inx
   bne @Instr6Loop
@Instr6done:

@wait:
   jsr GETIN
   CMP #CHAR_ENTER
   bne @wait
   rts
