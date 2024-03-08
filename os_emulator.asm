global so_emul

section .bss

N: resq CORES; tablica długości CORES przechowująca 
             ; struktury z rejestrami dla kolejnych rdzeni

section .text

so_emul:
    push    rbx
    push    rbp
    push    r10
    push    r11
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r15, rcx; zapamiętujemy core
    push    r15
    sub     rsp, 8
    lea     r8, [rel N]; wrzucamy na stos strukturę przechowującą rejestry
    mov     rax, [r8 + rcx*8]
    mov     [rsp], rax
    xor     rcx, rcx; licznik instrukcji

beg_of_while:
    cmp     rcx, rdx; sprawdzamy czy ilość instrukcji do wykonania 
                    ; jest większa od ilości już wykonanych
    jne     command_recognition
finishing:
    mov     rax, [rsp] 
    mov     r8, [rsp]
    add     rsp, 8
    lea     r9, [rel N]
    pop     r15; wracamy zapamiętany core
    shl     r15, 3; razy 8
    add     r9, r15
    mov     [r9], r8; wkładamy strukturę z rejestrami z powrotem do tablicy N
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     r11
    pop     r10
    pop     rbp
    pop     rbx
    ret

command_recognition:
    add     rcx, 1
    xor     rbp, rbp
    xor     rbx, rbx
    mov     bl, [rsp + 4]
    mov     bp, [rdi + rbx*2]; bierzemy 16 bitów aktulanie rozważane
    add     bl, 1
    mov     [rsp + 4], bl

    ;Będziemy teraz odczytywać komendy 
    ;i argumenty (na razie jako 0, 1, 2 itd. a nie A, D, X itd.)
    ;Zczytane dane będą przechowywane w następujących rejestrach:
    ;BL <- arg1
    ;r10b <- arg2
    ;AL <- stała immm8
    ;r11b <- pierwsze dwa bity

    xor     rbx, rbx
    mov     bx, bp; nie chcę zgubić wartości na bp
    shr     bx, 8; zostaje nam __ arg2 arg1
    shl     bx, 13;
    shr     bx, 13; mamy arg1 na bl

    xor     rax, rax
    mov     ax, bp
    shr     ax, 11; zostaje __ arg2
    shl     ax, 13
    shr     ax, 13
    xor     r10, r10
    mov     r10b, al; mamy arg2 na r10b 

    mov     ax, bp;
    shl     ax, 8
    shr     ax, 8; mamy imm8 na al

    push    rbx
    mov     bx, bp
    shr     bx, 14
    mov     r11b, bl; mamy dwa pierwsze bity na r11b
    pop     rbx

    ;Teraz będziemy tłuamczyć argumenty.
    ;Najpierw dzielimy na przypadki 0-3, 4-5, 6-7:
    cmp     rbx, 0
    je      arg1_between_0_and_3
    cmp     rbx, 1
    je      arg1_between_0_and_3
    cmp     rbx, 2
    je      arg1_between_0_and_3
    cmp     rbx, 3
    je      arg1_between_0_and_3
    cmp     rbx, 4
    je      arg1_between_4_and_5
    cmp     rbx, 5
    je      arg1_between_4_and_5
    cmp     rbx, 6
    je      arg1_between_6_and_7
    cmp     rbx, 7
    je      arg1_between_6_and_7

;Prawdziwe wartości argumentów - adresy, 
;będziemy trzymać w następujących rejestrach:
;r8b <- arg1_address
;r9b <- arg2 address
;Będziemy trzymać adresy, żeby móc zapisywać dane
;odwołując się do nich np instrukcja:
;mov [r8], r10b
;będzie zapisywać wartość r10b na argument pierwszy
arg1_between_0_and_3:
    mov     r8, rsp
    add     r8, rbx
    jmp     arg2_address_setting
arg1_between_4_and_5:
    mov     r13, rbx
    sub     r13, 2
    xor     r12, r12
    mov     r12b, [rsp + r13]
    mov     r8, rsi
    add     r8, r12
    jmp     arg2_address_setting
arg1_between_6_and_7:
    xor     r14, r14
    mov     r14b, [rsp + 1]; D  
    mov     r15, rbx
    sub     r15, 4
    xor     r13, r13
    mov     r13b, [rsp + r15]; X lub Y
    add     r13b, r14b; D + X/Y
    mov     r8, rsi
    add     r8, r13
    jmp     arg2_address_setting

arg2_address_setting:
    cmp     r10, 0
    je      arg2_between_0_and_3
    cmp     r10, 1
    je      arg2_between_0_and_3
    cmp     r10, 2
    je      arg2_between_0_and_3
    cmp     r10, 3
    je      arg2_between_0_and_3
    cmp     r10, 4
    je      arg2_between_4_and_5
    cmp     r10, 5
    je      arg2_between_4_and_5
    cmp     r10, 6
    je      arg2_between_6_and_7
    cmp     r10, 7
    je      arg2_between_6_and_7

arg2_between_0_and_3:
    mov     r9, rsp
    add     r9, r10
    jmp     after_arguments_setting
arg2_between_4_and_5:
    mov     r13, r10
    sub     r13, 2
    xor     r12, r12
    mov     r12b, [rsp + r13]
    mov     r9, rsi
    add     r9, r12
    jmp     after_arguments_setting
arg2_between_6_and_7:
    xor     r14, r14
    mov     r14b, [rsp + 1]; D  
    mov     r15, r10
    sub     r15, 4
    xor     r13, r13
    mov     r13b, [rsp + r15]; X lub Y
    add     r13b, r14b; D + X/Y
    mov     r9, rsi
    add     r9, r13
    jmp     after_arguments_setting

;Za tym fragmentem mamy:
;arg1 address: r8
;arg2 wartość: r9 
;stała imm8: al

;Teraz sprawdzimy, jaką komendę rozpatrujemy.
;Komendy można podzielić na 4 rodzaje
;Patrząc na dwa pierwsze bity w ich zapisie binarnym
;Są 4 grupy komend: 00, 01, 10, 11
;Podzielimy je teraz na te 4 rodzaje:
after_arguments_setting:
    cmp     r11b, 0
    je      zero_first
    cmp     r11b, 1
    je      one_first
    cmp     r11b, 2
    je      two_first
    cmp     r11b, 3
    je      three_first

;W tej grupie można rodzielić komendy patrząc na wartość al:
zero_first:
    cmp     al, 0
    je      command_mov
    cmp     al, 2
    je      command_or
    cmp     al, 4
    je      command_add
    cmp     al, 5
    je      command_sub
    cmp     al, 6
    je      command_adc
    cmp     al, 7
    je      command_sbb
    cmp     al, 8
    je      command_xchg

;W tej grupie można rodzielić komendy patrząc na wartość r10b:
one_first:
    cmp     r10b, 0
    je      command_movi
    cmp     r10b, 3
    je      command_xori
    cmp     r10b, 4
    je      command_addi
    cmp     r10b, 5
    je      command_cmpi
    cmp     r10b, 6
    je      command_rcr 

;W tej grupie można rodzielić komendy patrząc na wartość bl:
two_first:
    cmp     bl, 0; są tylko dwie opcje, 0 lub 1
    je      command_clc
    jmp     command_stc

;W tej grupie też można rodzielić komendy patrząc na wartość bl:
three_first:
    cmp     r10b, 7
    je      command_brk
    cmp     bl, 0
    je      command_jmp
    cmp     bl, 2
    je      command_jnc
    cmp     bl, 3
    je      command_jc
    cmp     bl, 4
    je      command_jnz
    cmp     bl, 5
    je      command_jz

set_zflag_false:
    xor     r14, r14
    mov     [rsp + 7], r14b
    jmp     beg_of_while
set_zflag_true:
    mov     r14, 1
    mov     [rsp + 7], r14b
    jmp     beg_of_while

set_cflag_false:
    xor     r14, r14
    mov     [rsp + 6], r14b
    jmp     zero_flag_setting
set_cflag_true:
    mov     r14, 1
    mov     [rsp + 6], r14b
    jmp     zero_flag_setting

zero_flag_setting:
    xor     r9b, r9b
    cmp     [r8], r9b
    je      set_zflag_true
    jne     set_zflag_false


;Implementacja wszystkich komend:
command_mov:
    mov     r15b, [r9]
    mov     [r8], r15b
    jmp     beg_of_while

command_or:
    mov     r15b, [r9]
    or      [r8], r15b
    jz      set_zflag_true
    jnz     set_zflag_false
    ;te sety zawierają jmp beg_of_while

command_add:
    mov     r15b, [r9]
    add     [r8], r15b
    jz      set_zflag_true
    jnz     set_zflag_false
    ;te sety zawierają jmp beg_of_while

command_sub:
    mov     r15b, [r9]
    sub     [r8], r15b
    jz      set_zflag_true
    jnz     set_zflag_false
    ;te sety zawierają jmp beg_of_while

command_adc:
    xor     r15, r15
    mov     r14b, [rsp + 6]
    cmp     r14b, r15b
    je      clear_real_carry_flag_adc
    jne     set_real_carry_flag_adc
set_real_carry_flag_adc:
    stc
    jmp     adc_execution
clear_real_carry_flag_adc:
    clc
adc_execution:
    mov     r15b, [r9]
    adc     [r8], r15b
    jc      set_cflag_true
    jnc     set_cflag_false
    ;zflag ustawi się po cflag

command_sbb:
    xor     r15, r15
    mov     r14b, [rsp + 6]
    cmp     r14b, r15b
    je      clear_real_carry_flag_sbb
    jne     set_real_carry_flag_sbb
set_real_carry_flag_sbb:
    stc
    jmp     sbb_execution
clear_real_carry_flag_sbb:
    clc
sbb_execution:
    mov     r15b, [r9]
    sbb     [r8], r15b
    jc      set_cflag_true
    jnc     set_cflag_false
    ;zflag ustawi się po cflag

command_movi:
    mov     [r8], al
    jmp     beg_of_while

command_xori:
    xor     r15, r15
    mov     r15b, [r8]
    xor     r15b, al
    mov     [r8], r15b
    jz      set_zflag_true
    jnz     set_zflag_false
    ;te sety zawierają jmp beg_of_while

command_addi:
    add     [r8], al
    jz      set_zflag_true
    jnz     set_zflag_false
    ;te sety zawierają jmp beg_of_while

command_cmpi:
    xor     r15, r15
    mov     r15b, [r8]
    sub     r15b, al
    jc      set_cflag_true_cmpi
set_cflag_false_cmpi:
    xor     r14, r14
    mov     [rsp + 6], r14b
    jmp     zero_flag_setting_cmpi
set_cflag_true_cmpi:
    mov     r14, 1
    mov     [rsp + 6], r14b
zero_flag_setting_cmpi:
    xor     r9b, r9b
    cmp     r15b, r9b
    je      set_zflag_true
    jne     set_zflag_false
    ;te sety zawierają jmp beg_of_while

command_rcr:
    ;nie używamy w tym przypadku rax i r9,
    ;bo nie ma pozostałych argumentów, 
    ;więc możemy użyć ich tu
    xor     rax, rax
    xor     r9, r9
    mov     al, [r8]
    mov     r9b, al
    shl     r9b, 7
    shr     r9b, 7; zostawiamy na r9b tylko ostatnią cyfrę liczby
    shr     al, 1
    xor     r15, r15
    mov     r15b, [rsp + 6]; wpisujemy znacznik c na ostatnią cyfrę r15
    shl     r15b, 7; umieszam tą cyfrę na 4 miejscu od prawej
    add     al, r15b; dodaję cyfrę wiodącą do wyniku
    mov     [r8], al; zapisujemy ostateczny wynik 
    mov     [rsp + 6], r9b; ostatnia instrukcja, przepisuje na c ostatnią cyfrę
    jmp     beg_of_while

command_clc:
    xor     r15, r15
    mov     [rsp + 6], r15b
    jmp     beg_of_while

command_stc:
    mov     r15, 1
    mov     [rsp + 6], r15b
    jmp     beg_of_while

command_jmp:
    add     [rsp + 4], al
    jmp     beg_of_while

command_jnc:
    xor     r15b, r15b
    cmp     [rsp + 6], r15b
    jne     beg_of_while; nie chcemy skoczyć jeśli c = 1
            ; c = 0
    add     [rsp + 4], al
    jmp     beg_of_while

command_jc:
    mov     r15b, 1
    cmp     [rsp + 6], r15b
    jne     beg_of_while; nie chcemy skoczyć jeśli c = 0
            ; c = 1
    add     [rsp + 4], al
    jmp     beg_of_while

command_jnz:
    xor     r15b, r15b
    cmp     [rsp + 7], r15b
    jne     beg_of_while; nie chcemy skoczyć jeśli z = 1
            ; z = 0
    add     [rsp + 4], al
    jmp     beg_of_while

command_jz:
    mov     r15b, 1
    cmp     [rsp + 7], r15b
    jne     beg_of_while; nie chcemy skoczyć jeśli z = 0
            ; z = 1
    add     [rsp + 4], al
    jmp     beg_of_while

command_brk:
    mov     rcx, rdx
    jmp     beg_of_while

command_xchg:
    xor     r15, r15
    mov     r15b, [r9]
    xchg    [r8], r15b
    mov     [r9], r15b
    jmp     beg_of_while