[ORG 0x00]
[BITS 16]

SECTION .text

; 코드 영역
START:
    mov ax, 0x1000              ; 보호 모드 엔트리 포인트의 시작 어드레스(0x10000)를 세그먼트 레지스터 값으로 변환
    mov ds, ax
    mov es, ax

    cli                         ; 인터럽트가 발생하지 못하도록 설정
    lgdt [ GDTR ]               ; GDTR 자료구조를 프로세서에 설정하여 GDT 테이블을 로드

    ; 보호 모드로 진입
    mov eax, 0x4000003B         ; PG=0, CD=1, NW=0, AM=0, WP=0, NE=1, ET=1, TS=1, EM=0, MP=1, PE=1
    mov cr0, eax                ; CR0 컨트롤 레지스터에 위에서 저장한 플래그를 설정하여 보호 모드로 전환

    ; 커널 코드 세그먼트를 0x00을 기준ㅇ로 하는 것으로 교체하고 EIP의 값을 0x00을 기준으로 설정
    ; CS 세그먼트 셀렉터 : EIP
    jmp dword 0x08: ( PROTECTEDMODE - $$ + 0x10000 )

; 보호 모드로 진입
[BITS 32]
PROTECTEDMODE:
    mov ax, 0x10                ; 보호 모드 커널용 데이터 세그먼트 디스크립터를 AX 레지스터에 저장
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    ; 스택을 0x00000000~0x0000FFFF 영역에 64KB 크기로 생성
    mov ss, ax
    mov esp, 0xFFFE
    mov ebp, 0xFFFE

    ; 화면에 보호 모드로 전환되었다는 메시지를 찍는다.
    push ( SWITCHSUCCESSMESSAGE - $$ + 0x10000 )
    push 2
    push 0
    call PRINTMESSAGE
    add esp, 12                 ; 삽입한 파라미터 제거

    jmp $

; 함수 코드 영역
PRINTMESSAGE:
    push ebp
    mov ebp, esp
    push esi
    push edi
    push eax
    push ecx
    push edx

    ; X, Y의 좌표로 비디오 메모리의 어드레스를 계산함
    ; Y 좌표를 이용해서 ㅁ너저 라인 어드레스를 구함
    mov eax, dword [ ebp + 12 ] ; 파라미터 2(화면 좌표 Y)를 EAX 레지스터에 설정
    mov esi, 160                ; 한 라인의 바이트 수(2 * 80 칼럼)를 ESI 레지스터에 설정
    mul esi                     ; EAX 레지스터와 ESI 레지스터를 곱하여 화면 Y 어드레스 계산
    mov edi, eax                ; 계산된 화면 Y 어드레스를 EDI 레지스터에 설정

    ; X 좌표를 이용해서 2를 곱한 후 최종 어드레스를 구함
    mov eax, dword [ ebp + 8 ]  ; 파라미터 1(화면 좌표 X)를 EAX 레지스터에 설정
    mov esi, 2                  ; 한 문자를 나타내는 바이트 수(2)를 ESI 레지스터에 설정
    mul esi                     ; EAX 레지스터와 ESI 레지스터를 곱하여 화면 X 어드레스를 계산
    add edi, eax                ; 화면 Y 어드레스와 계산된 X 어드레스를 더해서 실제 비디오 메모리 어드레스를 계산
    
    ; 출력할 문자열의 어드레스
    mov esi, dword [ ebp + 16 ] ; 파라미터 3(출력할 문자열의 어드레스)

.MESSAGELOOP:
    mov cl, byte [ esi ]
    cmp cl, 0
    je .MESSAGEEND

    mov byte [ edi + 0xB8000 ], cl  ; 0이 아니라면 비디오 메모리 어드레스 0xB8000 + EDI에 문자를 출력

    add esi, 1
    add edi, 2

    jmp .MESSAGELOOP
.MESSAGEEND:
    pop edx
    pop ecx
    pop eax
    pop edi
    pop esi
    pop ebp
    ret

; 데이터 영역
; 아래의 데이터들을 8바이트에 맞춰 정렬하기 위해 추가
align 8, db 0

; GDTR 자료구조 정의
GDTR:
    dw GDTEND - GDT - 1         ; 아래에 위치하는 GDT 테이블의 전체 크기
    dd ( GDT - $$ + 0x10000)    ; 아래에 위치하는 GDT 테이블의 시작 어드레스

; GDT 테이블 정의
GDT:
    ; 널 디스크립터. 반드시 0으로 초기화해야 함
    NULLDescriptor:
        dw 0x0000
        dw 0x0000
        db 0x00
        db 0x00
        db 0x00
        db 0x00

    ; 보호 모드 커널용 코드 세그먼트 디스크립터
    CODEDESCRIPTOR:
        dw 0xFFFF               ; Limit [15:0]
        dw 0x0000               ; Base [15:0]
        db 0x00                 ; Base [23:16]
        db 0x9A                 ; P=1, DPL=0, Code Segment, Excute/Read
        db 0xCF                 ; G=1, D=1, L=0, Limit[19:16]
        db 0x00                 ; Base [31:24]

    ; 보호 모드 커널용 데이터 세그먼트 디스크립터
    DATADESCRIPTOR:
        dw 0xFFFF               ; Limit [15:0]
        dw 0x0000               ; Base [15:0]
        db 0x00                 ; Base [23:16]
        db 0x92                 ; P=1, DPL=0, Data Segment, Read/Write
        db 0xCF                 ; G=1, D=1, L=0, Limit[19:16]
        db 0x00                 ; Base [31:24]
GDTEND:

; 보호 모드로 전환되었다는 메시지
SWITCHSUCCESSMESSAGE: db 'Switch To Protected Mode Success~!!', 0

times 512 - ( $ - $$ ) db   0x00          ; 512바이트를 맞추기 위해 남은 부분을 0으로 채움