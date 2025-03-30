MOV A, 0x55      ; Загрузить 0x55 в A
MOV B, A         ; Скопировать A в B
ADD A, B         ; A = A + B
MOV A, 0x05
MOV B, 0x03
MOV C, 0xFF
MOV D, 0x01
ADD A, B
SUB B, D
AND A, B
OR C, D
XOR A, C
MOV A, 0xFF
MOV C, 0x11
ADD A, C
HALT             ; Остановка процессора