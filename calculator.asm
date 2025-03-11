

.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Calculator - Oltean Razvan",0
area_width EQU 640
area_height EQU 480
area DD 0

screen_pos DD 240
rez DD 0
interm DD 0
op DB 0
on DB 0
op_ant DB 0
temp DD 0
temp_op DD 0
sign DB 0
equal DB 0
equal_op DB 0

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

cadru_calc_x EQU 225
cadru_calc_y EQU 80
cadru_size_x EQU 200
cadru_size_y EQU 200
button_size EQU 40
operatie_x EQU 400
operatie_y EQU 100
screen_x EQU 240
screen_y EQU 100
zece DD 10
trigger DB 0
end_screen DD 370
lim_sup DD 370

; '-' pentru impartire
; ',' pentru scadere
; 'k' pentru sqrt
; 'i' pentru !
; 'z' pentru pi
; 'q' pentru /
; 'h' pentru (
; 'j' pentru )
; 'v' pentru e
; 'w' pentru =

counter DD 0 ; numara evenimentele de tip timer
symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc
include signs.inc

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_signs
	cmp eax, '9'
	jg make_signs
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_signs:
	cmp eax, '*'
	jl make_space
	cmp eax, '-'
	jg make_space
	sub eax, '*'
	lea esi, signs
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

line_horizontal macro x, y, len, color
local bucla_line
	mov eax, y
	mov ebx, area_width
	mul ebx
	add eax, x
	shl eax, 2
	add eax, area
	mov ecx, len
bucla_line:
	mov dword ptr[eax], color
	add eax, 4
	loop bucla_line
endm

line_vertical macro x, y, len, color
local bucla_line
	mov eax, y
	mov ebx, area_width
	mul ebx
	add eax, x
	shl eax, 2
	add eax, area
	mov ecx, len
bucla_line:
	mov dword ptr[eax], color
	add eax, area_width * 4
	loop bucla_line
endm

curatare_ecran macro pos
local l1,fin
	mov pos,370
	l1:
	make_text_macro ' ', area, pos, screen_y
	cmp pos,screen_x
	je fin
	sub pos,10
	jmp l1
	fin:
endm

curatare_operatie macro pos, area
local l1
	mov pos, operatie_x - 10
l1:
	make_text_macro ' ', area, pos, screen_y
	cmp pos,430
	je fin
	add pos,10
	jmp l1
fin:
endm

curatare_final_ecran macro pos
local l1,fin
	mov pos,370
l1:
	make_text_macro ' ', area, pos, screen_y
	cmp pos,320
	je fin
	sub pos,10
	jmp l1
fin:
mov temp,0
endm

afisare_eroare macro pos,area
	curatare_ecran pos
	make_text_macro 'X', area, screen_x, screen_y
endm

schimbare_semn macro rez
	mov eax,rez
	sub eax,rez
	sub eax,rez
	mov rez, eax
endm

verificare_semn macro rez,sign
local minus,fin
	cmp rez,0
	jl minus
	mov sign,0
	jmp fin
minus:
	mov sign,1
fin:
endm

egal_opp macro op
local cont
	curatare_ecran screen_pos
	cmp op,0 ; idle
	jz cont
	cmp op,1 ; adunare
	je adunare_opp
	cmp op,2 ; scadere
	je scadere_opp
	cmp op,3 ; inmultire
	je inmultire_opp
	cmp op,4 ; impartire
	je impartire_opp
	cmp op,5 ; modulo
	je modulo_opp
cont:
	cmp temp_op,0
	jnz afisare_ecran_opp
	cmp rez,0
	jnz afisare_ecran_opp
	mov eax,interm
	mov rez,eax
	jmp afisare_ecran_opp
endm

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov edx, [ebp+arg1]
	cmp edx, 1
	jz evt_click
	cmp edx, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	jmp afisare_litere
	
evt_click:
	
button1:										;MODULO					
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 0 * button_size
	jle button2
	cmp ebx,cadru_calc_x + 1 * button_size
	jge button2
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 1 * button_size
	jle button2
	cmp ebx,cadru_calc_y + 2 * button_size
	jge button2
;actiunea butonului
	cmp on,0
	jz afisare_litere
	make_text_macro 'M',area, operatie_x - 10, operatie_y
	make_text_macro 'O',area, operatie_x, operatie_y
	make_text_macro 'D',area, operatie_x + 10, operatie_y
	curatare_ecran screen_pos
	mov equal_op,1
	mov op,5
	cmp rez,0
	jne continuare_modulo_1
	cmp temp_op,0
	jne continuare_modulo_1
	mov eax,interm
	mov rez,eax
	mov interm,0
	jmp afisare_litere
continuare_modulo_1:
	cmp interm, 0
	jne continuare_modulo_2
	jmp afisare_litere
continuare_modulo_2:
	egal_opp op_ant
	jmp afisare_litere
	
button2:										;7			
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 1 * button_size
	jle button3
	cmp ebx,cadru_calc_x + 2 * button_size
	jge button3
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 1 * button_size
	jle button3
	cmp ebx,cadru_calc_y + 2 * button_size
	jge button3
;actiunea butonului
	curatare_final_ecran temp
	cmp on,0
	jz afisare_litere
	cmp screen_pos,320
	jge afisare_litere
	cmp equal,0
	jz cont_7
	cmp equal_op,0
	jnz cont_7
	mov rez,0
	mov interm,0
	mov equal,0
	mov temp_op,0
cont_7:
	make_text_macro '7', area, screen_pos, screen_y
	add screen_pos,10
	
	mov eax,interm
	mul zece
	add eax,7
	mov interm,eax
	
	jmp afisare_litere
	
button3:										;8			
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 2 * button_size
	jle button4
	cmp ebx,cadru_calc_x + 3 * button_size
	jge button4
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 1 * button_size
	jle button4
	cmp ebx,cadru_calc_y + 2 * button_size
	jge button4
;actiunea butonului
	curatare_final_ecran temp
	cmp on,0
	jz afisare_litere
	cmp screen_pos,320
	jge afisare_litere
	cmp equal,0
	jz cont_8
	cmp equal_op,0
	jnz cont_8
	mov rez,0
	mov interm,0
	mov equal,0
	mov temp_op,0
cont_8:
	make_text_macro '8', area, screen_pos, screen_y
	add screen_pos,10
	
	mov eax,interm
	mul zece
	add eax,8
	mov interm,eax
	
	jmp afisare_litere
	
button4:										;9					
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 3 * button_size
	jle button5
	cmp ebx,cadru_calc_x + 4 * button_size
	jge button5
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 1 * button_size
	jle button5
	cmp ebx,cadru_calc_y + 2 * button_size
	jge button5
;actiunea butonului
	curatare_final_ecran temp
	cmp on,0
	jz afisare_litere
	cmp screen_pos,320
	jge afisare_litere
	cmp equal,0
	jz cont_9
	cmp equal_op,0
	jnz cont_9
	mov rez,0
	mov interm,0
	mov equal,0
	mov temp_op,0
cont_9:
	make_text_macro '9', area, screen_pos, screen_y
	add screen_pos,10
	
	mov eax,interm
	mul zece
	add eax,9
	mov interm,eax
	
	jmp afisare_litere
	
button5:										;IMPARTIRE							
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 4 * button_size
	jle button6
	cmp ebx,cadru_calc_x + 5 * button_size
	jge button6
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 1 * button_size
	jle button6
	cmp ebx,cadru_calc_y + 2 * button_size
	jge button6
;actiunea butonului
	cmp on,0
	jz afisare_litere
	make_text_macro '-',area, operatie_x, operatie_y
	curatare_ecran screen_pos
	mov equal_op,1
	mov op,4
	cmp rez,0
	jne continuare_impartire_1
	cmp temp_op,0
	jne continuare_impartire_1
	mov eax,interm
	mov rez,eax
	mov interm,0
	jmp afisare_litere
continuare_impartire_1:
	cmp interm, 0
	jne continuare_impartire_2
	jmp afisare_litere
continuare_impartire_2:
	verificare_semn rez, sign
	cmp sign,1
	jne continuare_impartire_4
	schimbare_semn rez
continuare_impartire_4:
	egal_opp op_ant
	jmp afisare_litere
	
button6:										;VALOARE_ABSOLUTA				
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 0 * button_size
	jle button7
	cmp ebx,cadru_calc_x + 1 * button_size
	jge button7
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 2 * button_size
	jle button7
	cmp ebx,cadru_calc_y + 3 * button_size
	jge button7
;actiunea butonului
	cmp on,0
	jz afisare_litere
	;mov equal_op,1
	mov equal,1
	cmp on,0
	je afisare_litere
	curatare_ecran screen_pos
	cmp temp_op,0
	jz continuare_val_abs
	verificare_semn rez,sign
	cmp sign,0
	jz afisare_ecran
	schimbare_semn rez
	verificare_semn rez,sign
	jmp afisare_ecran
continuare_val_abs:
	mov eax,interm
	mov rez,eax
	mov op_ant,0
	jmp afisare_ecran
	
button7:										;4								
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 1 * button_size
	jle button8
	cmp ebx,cadru_calc_x + 2 * button_size
	jge button8
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 2 * button_size
	jle button8
	cmp ebx,cadru_calc_y + 3 * button_size
	jge button8
;actiunea butonului
	curatare_final_ecran temp
	cmp on,0
	jz afisare_litere
	cmp screen_pos,320
	jge afisare_litere
	cmp equal,0
	jz cont_4
	cmp equal_op,0
	jnz cont_4
	mov rez,0
	mov interm,0
	mov equal,0
	mov temp_op,0
cont_4:
	make_text_macro '4', area, screen_pos, screen_y
	add screen_pos,10
	
	mov eax,interm
	mul zece
	add eax,4
	mov interm,eax
	
	jmp afisare_litere

button8:										;5								
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 2 * button_size
	jle button9
	cmp ebx,cadru_calc_x + 3 * button_size
	jge button9
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 2 * button_size
	jle button9
	cmp ebx,cadru_calc_y + 3 * button_size
	jge button9
;actiunea butonului
	curatare_final_ecran temp
	cmp on,0
	jz afisare_litere
	cmp screen_pos,320
	jge afisare_litere
	cmp equal,0
	jz cont_5
	cmp equal_op,0
	jnz cont_5
	mov rez,0
	mov interm,0
	mov equal,0
	mov temp_op,0
cont_5:
	make_text_macro '5', area, screen_pos, screen_y
	add screen_pos,10
	
	mov eax,interm
	mul zece
	add eax,5
	mov interm,eax
	
	jmp afisare_litere
	
button9:										;6				
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 3 * button_size
	jle button10
	cmp ebx,cadru_calc_x + 4 * button_size
	jge button10
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 2 * button_size
	jle button10
	cmp ebx,cadru_calc_y + 3 * button_size
	jge button10
;actiunea butonului
	curatare_final_ecran temp
	cmp on,0
	jz afisare_litere
	cmp screen_pos,320
	jge afisare_litere
	cmp equal,0
	jz cont_6
	cmp equal_op,0
	jnz cont_6
	mov rez,0
	mov interm,0
	mov equal,0
	mov temp_op,0
cont_6:
	make_text_macro '6', area, screen_pos, screen_y
	add screen_pos,10
	
	mov eax,interm
	mul zece
	add eax,6
	mov interm,eax
	
	jmp afisare_litere
	
button10:										;INMULTIRE									
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 4 * button_size
	jle button11
	cmp ebx,cadru_calc_x + 5 * button_size
	jge button11
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 2 * button_size
	jle button11
	cmp ebx,cadru_calc_y + 3 * button_size
	jge button11
;actiunea butonului
	cmp on,0
	jz afisare_litere
	make_text_macro '*',area, operatie_x, operatie_y
	curatare_ecran screen_pos
	mov equal_op,1
	cmp rez,0
	jne continuare_inmultire_1
	cmp temp_op,0
	jne continuare_inmultire_1
	mov eax, interm
	mov rez,eax
	mov op,3
	mov interm,0
	jmp afisare_litere
continuare_inmultire_1:
	cmp interm, 0
	jne continuare_inmultire_2 
	mov op,3
	jmp afisare_litere
continuare_inmultire_2:
	mov op,3
	egal_opp op_ant
	jmp afisare_litere
	
button11:										;RIDICARE_LA_PATRAT					
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 0 * button_size
	jle button12
	cmp ebx,cadru_calc_x + 1 * button_size
	jge button12
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 3 * button_size
	jle button12
	cmp ebx,cadru_calc_y + 4 * button_size
	jge button12
;actiunea butonului
	cmp on,0
	jz afisare_litere
	curatare_ecran screen_pos
	mov equal,1
	;mov equal_op,1
	mov sign, 0
	cmp temp_op,0
	je continuare_ridicare_la_patrat
	mov eax, rez
	mul eax
	mov rez, eax
	jmp afisare_ecran
continuare_ridicare_la_patrat:
	mov eax, interm
	mul eax
	mov rez,eax
	mov op_ant,0
	jmp afisare_ecran
	
	
button12:										;1		
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 1 * button_size
	jle button13
	cmp ebx,cadru_calc_x + 2 * button_size
	jge button13
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 3 * button_size
	jle button13
	cmp ebx,cadru_calc_y + 4 * button_size
	jge button13
;actiunea butonului
	curatare_final_ecran temp
	cmp on,0
	jz afisare_litere
	cmp screen_pos,320
	jge afisare_litere
	cmp equal,0
	jz cont_1
	cmp equal_op,0
	jnz cont_1
	mov rez,0
	mov interm,0
	mov equal,0
	mov temp_op,0
cont_1:
	make_text_macro '1', area, screen_pos, screen_y
	add screen_pos,10
	
	mov eax,interm
	mul zece
	add eax,1
	mov interm,eax
	
	jmp afisare_litere
	
	
button13:										;2
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 2 * button_size
	jle button14
	cmp ebx,cadru_calc_x + 3 * button_size
	jge button14
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 3 * button_size
	jle button14
	cmp ebx,cadru_calc_y + 4 * button_size
	jge button14
;actiunea butonului
	curatare_final_ecran temp
	cmp on,0
	jz afisare_litere
	cmp screen_pos,320
	jge afisare_litere
	cmp equal,0
	jz cont_2
	cmp equal_op,0
	jnz cont_2
	mov rez,0
	mov interm,0
	mov equal,0
	mov temp_op,0
cont_2:
	make_text_macro '2', area, screen_pos, screen_y
	add screen_pos,10
	
	mov eax,interm
	mul zece
	add eax,2
	mov interm,eax
	
	jmp afisare_litere
	
	
button14:										;3
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 3 * button_size
	jle button15
	cmp ebx,cadru_calc_x + 4 * button_size
	jge button15
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 3 * button_size
	jle button15
	cmp ebx,cadru_calc_y + 4 * button_size
	jge button15
;actiunea butonului
	curatare_final_ecran temp
	cmp on,0
	jz afisare_litere
	cmp screen_pos,320
	jge afisare_litere
	cmp equal,0
	jz cont_3
	cmp equal_op,0
	jnz cont_3
	mov rez,0
	mov interm,0
	mov equal,0
	mov temp_op,0
cont_3:
	make_text_macro '3', area, screen_pos, screen_y
	add screen_pos,10
	
	mov eax,interm
	mul zece
	add eax,3
	mov interm,eax
	
	jmp afisare_litere
	
	
button15:										;SCADERE								
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 4 * button_size
	jle button16
	cmp ebx,cadru_calc_x + 5 * button_size
	jge button16
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 3 * button_size
	jle button16
	cmp ebx,cadru_calc_y + 4 * button_size
	jge button16
;actiunea butonului
	cmp on,0
	jz afisare_litere
	make_text_macro ',',area, operatie_x, operatie_y
	curatare_ecran screen_pos
	mov equal_op,1
	cmp rez,0
	jne continuare_scadere
	schimbare_semn rez
continuare_scadere:
	mov op,2
	egal_opp op_ant
	jmp afisare_litere
	
	
button16:										;DEL				
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 0 * button_size
	jle button17
	cmp ebx,cadru_calc_x + 1 * button_size
	jge button17
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 4 * button_size
	jle button17
	cmp ebx,cadru_calc_y + 5 * button_size
	jge button17
;actiunea butonului
	cmp interm,0
	jz cont_delete
	;interm
	cmp screen_pos, screen_x
	je  afisare_litere
	sub screen_pos, 10
	make_text_macro ' ',area, screen_pos,screen_y
	mov eax,interm
	xor edx,edx
	mov ebx,10
	div ebx
	mov interm,eax
	jmp afisare_litere
  ;rez
cont_delete:
	cmp lim_sup, screen_x
	je afisare_litere
	sub lim_sup, 10
	make_text_macro ' ',area, lim_sup,screen_y
	mov eax,rez
	xor edx,edx
	mov ebx,10
	div ebx
	mov rez,eax
	jmp afisare_litere
	
	
button17:										;CE
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 1 * button_size
	jle button18
	cmp ebx,cadru_calc_x + 2 * button_size
	jge button18
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 4 * button_size
	jle button18
	cmp ebx,cadru_calc_y + 5 * button_size
	jge button18
;actiunea butonului
	curatare_ecran screen_pos
	mov on,1
	mov equal_op,0
	mov temp_op,0
	mov op,0
	mov op_ant,0
	mov equal,0
	mov rez,0
	mov interm,0
	jmp afisare_litere
	
button18:										;0			
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 2 * button_size
	jle button19
	cmp ebx,cadru_calc_x + 3 * button_size
	jge button19
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 4 * button_size
	jle button19
	cmp ebx,cadru_calc_y + 5 * button_size
	jge button19
;actiunea butonului
	curatare_final_ecran temp
	cmp on,0
	jz afisare_litere
	cmp screen_pos,320
	jge afisare_litere
	cmp equal,0
	jz cont_0
	cmp equal_op,0
	jnz cont_0
	mov rez,0
	mov interm,0
	mov equal,0
	mov temp_op,0
cont_0:
	make_text_macro '0', area, screen_pos, screen_y
	add screen_pos,10
	
	mov eax,interm
	mul zece
	add eax,0
	mov interm,eax
	
	jmp afisare_litere
	
	
button19:										;EGAL							
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 3 * button_size
	jle button20
	cmp ebx,cadru_calc_x + 4 * button_size
	jge button20
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 4 * button_size
	jle button20
	cmp ebx,cadru_calc_y + 5 * button_size
	jge button20
;actiunea butonului
	mov equal_op,0
	curatare_ecran screen_pos
	cmp op,0 ; idle
	jz afisare_litere
	cmp op,1 ; adunare
	je adunare
	cmp op,2 ; scadere
	je scadere
	cmp op,3 ; inmultire
	je inmultire
	cmp op,4 ; impartire
	je impartire
	cmp op,5 ; modulo
	je modulo
	
	jmp afisare_litere
	
	
button20:										;ADUNARE								
;detectare buton
	mov ebx,[ebp + arg2]
	cmp ebx,cadru_calc_x + 4 * button_size
	jle afisare_litere
	cmp ebx,cadru_calc_x + 5 * button_size
	jge afisare_litere
	mov ebx,[ebp + arg3]
	cmp ebx,cadru_calc_y + 4 * button_size
	jle afisare_litere
	cmp ebx,cadru_calc_y + 5 * button_size
	jge afisare_litere
;actiunea butonului
	cmp on,0
	jz afisare_litere
	make_text_macro '+', area, operatie_x, operatie_y
	curatare_ecran screen_pos
	mov op, 1
	mov equal_op,1
	egal_opp op_ant
	jmp afisare_litere
	
	
adunare:
	cmp rez,0
	jl scadere_adunare
	mov sign,0
	mov eax, rez
	add eax, interm
	mov rez,eax
	jmp afisare_ecran
scadere_adunare:
	schimbare_semn rez
	mov eax,rez
	sub eax,interm
	mov rez,eax
	cmp rez,0
	jge afisare_ecran
	schimbare_semn rez
	verificare_semn rez,sign
	jmp afisare_ecran
scadere:
	mov sign,0
	mov eax,rez
	sub eax,interm
	mov rez,eax
	cmp rez,0
	jge afisare_ecran
	schimbare_semn rez
	mov sign, 1
	jmp afisare_ecran
inmultire:
	verificare_semn rez,sign
	cmp sign,1
	jne continuare_inmultire_3
	schimbare_semn rez
continuare_inmultire_3:
	mov eax,rez
	mul interm
	mov rez,eax
	jmp afisare_ecran
impartire:
	verificare_semn rez,sign
	cmp sign,1
	jne continuare_impartire_3
	schimbare_semn rez
continuare_impartire_3:
	mov eax,rez
	mov edx,0
	div interm
	mov rez,eax
	jmp afisare_ecran
modulo:
	verificare_semn rez,sign
	cmp sign,1
	jne continuare_modulo_3
	schimbare_semn rez
	mov eax,rez
	mov edx,0
	div interm
	mov ecx,interm
	sub ecx,edx
	mov rez,ecx
	mov sign, 0
continuare_modulo_3:
	mov eax,rez
	mov edx,0
	div interm
	mov rez,edx
	jmp afisare_ecran

	
	
afisare_ecran:
	mov eax,rez
    mov ebx, 10
	mov screen_pos, 360
ll:
    xor edx, edx
    div ebx
    add edx, '0'
    make_text_macro edx ,area ,screen_pos ,screen_y
    sub screen_pos, 10
    cmp eax, 0
    jne ll
	
	mov op, 0
	mov interm,0
	mov temp_op,1
	mov equal,1
	mov lim_sup,370
	curatare_operatie temp,area
	mov eax,screen_pos
	mov temp,eax
	mov screen_pos, screen_x
	
	make_text_macro ' ',area,temp,screen_y
	cmp sign,1
	jne afisare_litere
	make_text_macro ',',area,temp,screen_y
	schimbare_semn rez
	
jmp afisare_litere

											;dupa operatii

adunare_opp:
	cmp rez,0
	jl scadere_adunare_opp
	mov sign,0
	mov eax, rez
	add eax, interm
	mov rez,eax
	jmp afisare_ecran_opp
scadere_adunare_opp:
	schimbare_semn rez
	mov eax,rez
	sub eax,interm
	mov rez,eax
	cmp rez,0
	jge afisare_ecran_opp
	schimbare_semn rez
	verificare_semn rez,sign
	jmp afisare_ecran_opp
scadere_opp:
	mov sign,0
	mov eax,rez
	sub eax,interm
	mov rez,eax
	cmp rez,0
	jge afisare_ecran_opp
	schimbare_semn rez
	mov sign, 1
	jmp afisare_ecran_opp
inmultire_opp:
	verificare_semn rez,sign
	cmp sign,1
	jne continuare_inmultire_3_opp
	schimbare_semn rez
continuare_inmultire_3_opp:
	mov eax,rez
	mul interm
	mov rez,eax
	jmp afisare_ecran_opp
impartire_opp:
	verificare_semn rez,sign
	cmp sign,1
	jne continuare_impartire_3_opp
	schimbare_semn rez
continuare_impartire_3_opp:
	mov eax,rez
	mov edx,0
	div interm
	mov rez,eax
	jmp afisare_ecran_opp
modulo_opp:
	verificare_semn rez,sign
	cmp sign,1
	jne continuare_modulo_3_opp
	schimbare_semn rez
	mov eax,rez
	mov edx,0
	div interm
	mov ecx,interm
	sub ecx,edx
	mov rez,ecx
	mov sign, 0
continuare_modulo_3_opp:
	mov eax,rez
	mov edx,0
	div interm
	mov rez,edx
	jmp afisare_ecran_opp

	
	
afisare_ecran_opp:
	mov eax,rez
    mov ebx, 10
	mov screen_pos, 360
ll_opp:
    xor edx, edx
    div ebx
    add edx, '0'
    make_text_macro edx ,area ,screen_pos ,screen_y
    sub screen_pos, 10
    cmp eax, 0
    jne ll_opp
	
	;mov op, 0
	mov interm,0
	;mov temp_op,1
	mov equal,1
	mov lim_sup,370
	;curatare_operatie temp,area
	mov eax,screen_pos
	mov temp,eax
	mov screen_pos, screen_x
	
	mov eax,0
	mov AL,op
	mov op_ant,AL
	
	make_text_macro ' ',area,temp,screen_y
	cmp sign,1
	jne afisare_litere
	make_text_macro ',',area,temp,screen_y
	schimbare_semn rez
	
jmp afisare_litere

	

evt_timer:
	inc counter
	
afisare_litere:
	;scriem un mesaj
	
	;cadru calculator
	line_horizontal cadru_calc_x,cadru_calc_y,cadru_size_x,0h
	line_vertical cadru_calc_x,cadru_calc_y,cadru_size_y,0h
	line_horizontal cadru_calc_x,cadru_calc_y + cadru_size_x,cadru_size_x,0h
	line_vertical cadru_calc_x + cadru_size_y,cadru_calc_y,cadru_size_y,0h
	
	;ecran
	line_horizontal cadru_calc_x,cadru_calc_y + button_size, cadru_size_x, 0h
	line_vertical cadru_calc_x + 160,cadru_calc_y,40,0h
	
	;comenzi
	line_horizontal cadru_calc_x,2 * button_size + cadru_calc_y,cadru_size_x,0h
	line_horizontal cadru_calc_x,3 * button_size + cadru_calc_y,cadru_size_x,0h
	line_horizontal cadru_calc_x,4 * button_size + cadru_calc_y,cadru_size_x,0h
	line_vertical cadru_calc_x + 1 * button_size,cadru_calc_y + button_size,cadru_size_y - button_size,0h
	line_vertical cadru_calc_x + 2 * button_size,cadru_calc_y + button_size,cadru_size_y - button_size,0h
	line_vertical cadru_calc_x + 3 * button_size,cadru_calc_y + button_size,cadru_size_y - button_size,0h
	line_vertical cadru_calc_x + 4 * button_size,cadru_calc_y + button_size,cadru_size_y - button_size,0h
	
	;simboluri
	make_text_macro 'M',area,cadru_calc_x + 1 * button_size/2 - 10,cadru_calc_y + 3 * button_size/2
	make_text_macro 'O',area,cadru_calc_x + 1 * button_size/2,cadru_calc_y + 3 * button_size/2
	make_text_macro 'D',area,cadru_calc_x + 1 * button_size/2 + 10,cadru_calc_y + 3 * button_size/2
	make_text_macro '7',area,cadru_calc_x + 3 * button_size/2,cadru_calc_y + 3 * button_size/2
	make_text_macro '8',area,cadru_calc_x + 5 * button_size/2,cadru_calc_y + 3 * button_size/2
	make_text_macro '9',area,cadru_calc_x + 7 * button_size/2,cadru_calc_y + 3 * button_size/2
	make_text_macro '-',area,cadru_calc_x + 9 * button_size/2,cadru_calc_y + 3 * button_size/2
	
	line_vertical cadru_calc_x + 1 * button_size/2 - 3,cadru_calc_y + 5 * button_size/2,20,0h
	make_text_macro 'X',area,cadru_calc_x + 1 * button_size/2,cadru_calc_y + 5 * button_size/2
	line_vertical cadru_calc_x + 1 * button_size/2 + 11,cadru_calc_y + 5 * button_size/2,20,0h
	make_text_macro '4',area,cadru_calc_x + 3 * button_size/2,cadru_calc_y + 5 * button_size/2
	make_text_macro '5',area,cadru_calc_x + 5 * button_size/2,cadru_calc_y + 5 * button_size/2
	make_text_macro '6',area,cadru_calc_x + 7 * button_size/2,cadru_calc_y + 5 * button_size/2
	make_text_macro '*',area,cadru_calc_x + 9 * button_size/2,cadru_calc_y + 5 * button_size/2
	
	make_text_macro 'X',area,cadru_calc_x + 1 * button_size/2,cadru_calc_y + 7 * button_size/2
	make_text_macro '2',area,cadru_calc_x + 1 * button_size/2 + 10,cadru_calc_y + 7 * button_size/2 - 10
	make_text_macro '1',area,cadru_calc_x + 3 * button_size/2,cadru_calc_y + 7 * button_size/2
	make_text_macro '2',area,cadru_calc_x + 5 * button_size/2,cadru_calc_y + 7 * button_size/2
	make_text_macro '3',area,cadru_calc_x + 7 * button_size/2,cadru_calc_y + 7 * button_size/2
	make_text_macro ',',area,cadru_calc_x + 9 * button_size/2,cadru_calc_y + 7 * button_size/2
	
	make_text_macro 'D',area,cadru_calc_x + 1 * button_size/2 - 10,cadru_calc_y + 9 * button_size/2
	make_text_macro 'E',area,cadru_calc_x + 1 * button_size/2,cadru_calc_y + 9 * button_size/2
	make_text_macro 'L',area,cadru_calc_x + 1 * button_size/2 + 10,cadru_calc_y + 9 * button_size/2
	make_text_macro 'C',area,cadru_calc_x + 3 * button_size/2 - 5,cadru_calc_y + 9 * button_size/2
	make_text_macro 'E',area,cadru_calc_x + 3 * button_size/2 + 5,cadru_calc_y + 9 * button_size/2
	make_text_macro '0',area,cadru_calc_x + 5 * button_size/2,cadru_calc_y + 9 * button_size/2
	make_text_macro 'W',area,cadru_calc_x + 7 * button_size/2,cadru_calc_y + 9 * button_size/2
	make_text_macro '+',area,cadru_calc_x + 9 * button_size/2,cadru_calc_y + 9 * button_size/2
	
	
	
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	mov on,1
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start