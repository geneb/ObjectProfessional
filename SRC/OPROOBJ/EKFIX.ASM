;******************************************************
;                     EKFIX.ASM
;              by TurboPower Software
;******************************************************

;To generate EKFIX.COM using Turbo Assembler:
;
;   TASM EKFIX
;   TLINK EKFIX /T/X
;   DEL EKFIX.OBJ

CODE    SEGMENT PUBLIC 'CODE'

        ASSUME  CS:CODE,DS:CODE

        ORG     100h                    ;set up as a COM file

Begin:
        JMP     SHORT Start             ;skip over the data

Enable  DB      'Enhanced keyboard flag enabled by EKFIX', 0Dh, 0Ah, '$'
Disable DB      'Enhanced keyboard flag disabled by EKFIX', 0Dh, 0Ah, '$'
EnhFlag =       00010000b               ;mask for bit 4

Start:
        MOV     AX,0040h                ;ES:DI points to BIOS flag
        MOV     ES,AX
        MOV     DI,0096h
        MOV     AL,ES:[DI]              ;AL has flag
        TEST    AL,EnhFlag              ;is bit 4 set?
        JZ      TurnBitOn               ;if not, turn it on
        AND     AL,(not EnhFlag)        ;else, turn it off
        MOV     DX,offset Disable       ;DS:DX points to message
        JMP     SHORT Go

TurnBitOn:
        OR      AL,EnhFlag              ;Turn bit on
        MOV     DX,offset Enable        ;DS:DX points to message

Go:
        MOV     ES:[DI],AL              ;toggle bit 4
        MOV     AH,09h                  ;execute DOS print string function
        INT     21h

        MOV     AX,4C00h                ;terminate the program
        INT     21h

CODE    ENDS

        END     Begin
