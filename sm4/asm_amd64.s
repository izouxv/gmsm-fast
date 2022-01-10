// This SM4 implementation referenced https://github.com/mjosaarinen/sm4ni/blob/master/sm4ni.c
#include "textflag.h"

#define x X0
#define y X1
#define t0 X2
#define t1 X3
#define t2 X4
#define t3 X5

#define XTMP6 X6
#define XTMP7 X7

// shuffle byte order from LE to BE
DATA flip_mask<>+0x00(SB)/8, $0x0405060700010203
DATA flip_mask<>+0x08(SB)/8, $0x0c0d0e0f08090a0b
GLOBL flip_mask<>(SB), RODATA, $16

// shuffle byte and word order
DATA flip_mask2<>+0x00(SB)/8, $0x08090a0b0c0d0e0f
DATA flip_mask2<>+0x08(SB)/8, $0x0001020304050607
GLOBL flip_mask2<>(SB), RODATA, $16

//nibble mask
DATA nibble_mask<>+0x00(SB)/8, $0x0F0F0F0F0F0F0F0F
DATA nibble_mask<>+0x08(SB)/8, $0x0F0F0F0F0F0F0F0F
GLOBL nibble_mask<>(SB), RODATA, $16

// inverse shift rows
DATA inverse_shift_rows<>+0x00(SB)/8, $0x0B0E0104070A0D00
DATA inverse_shift_rows<>+0x08(SB)/8, $0x0306090C0F020508 
GLOBL inverse_shift_rows<>(SB), RODATA, $16

// Affine transform 1 (low and high hibbles)
DATA m1_low<>+0x00(SB)/8, $0x9197E2E474720701
DATA m1_low<>+0x08(SB)/8, $0xC7C1B4B222245157
GLOBL m1_low<>(SB), RODATA, $16

DATA m1_high<>+0x00(SB)/8, $0xE240AB09EB49A200
DATA m1_high<>+0x08(SB)/8, $0xF052B91BF95BB012  
GLOBL m1_high<>(SB), RODATA, $16

// Affine transform 2 (low and high hibbles)
DATA m2_low<>+0x00(SB)/8, $0x5B67F2CEA19D0834
DATA m2_low<>+0x08(SB)/8, $0xEDD14478172BBE82
GLOBL m2_low<>(SB), RODATA, $16

DATA m2_high<>+0x00(SB)/8, $0xAE7201DD73AFDC00
DATA m2_high<>+0x08(SB)/8, $0x11CDBE62CC1063BF
GLOBL m2_high<>(SB), RODATA, $16

// left rotations of 32-bit words by 8-bit increments
DATA r08_mask<>+0x00(SB)/8, $0x0605040702010003
DATA r08_mask<>+0x08(SB)/8, $0x0E0D0C0F0A09080B  
GLOBL r08_mask<>(SB), RODATA, $16

DATA r16_mask<>+0x00(SB)/8, $0x0504070601000302
DATA r16_mask<>+0x08(SB)/8, $0x0D0C0F0E09080B0A   
GLOBL r16_mask<>(SB), RODATA, $16

DATA r24_mask<>+0x00(SB)/8, $0x0407060500030201
DATA r24_mask<>+0x08(SB)/8, $0x0C0F0E0D080B0A09  
GLOBL r24_mask<>(SB), RODATA, $16

DATA fk_mask<>+0x00(SB)/8, $0x56aa3350a3b1bac6
DATA fk_mask<>+0x08(SB)/8, $0xb27022dc677d9197
GLOBL fk_mask<>(SB), RODATA, $16

#define SM4_SBOX(x, y) \
  ;                                   \ //#############################  inner affine ############################//
  MOVOU x, XTMP6;                     \
  PAND nibble_mask<>(SB), XTMP6;      \ //y = _mm_and_si128(x, c0f); 
  MOVOU m1_low<>(SB), y;              \
  PSHUFB XTMP6, y;                    \ //y = _mm_shuffle_epi8(m1l, y);
  PSRLQ $4, x;                        \ //x = _mm_srli_epi64(x, 4); 
  PAND nibble_mask<>(SB), x;          \ //x = _mm_and_si128(x, c0f);
  MOVOU m1_high<>(SB), XTMP6;         \
  PSHUFB x, XTMP6;                    \ //x = _mm_shuffle_epi8(m1h, x);
  MOVOU  XTMP6, x;                    \ //x = _mm_shuffle_epi8(m1h, x);
  PXOR y, x;                          \ //x = _mm_shuffle_epi8(m1h, x) ^ y;
  ;                                   \ // inverse ShiftRows
  PSHUFB inverse_shift_rows<>(SB), x; \ //x = _mm_shuffle_epi8(x, shr); 
  AESENCLAST nibble_mask<>(SB), x;    \ // AESNI instruction
  ;                                   \ //#############################  outer affine ############################//
  MOVOU  x, XTMP6;                    \
  PANDN nibble_mask<>(SB), XTMP6;     \ //XTMP6 = _mm_andnot_si128(x, c0f);
  MOVOU m2_low<>(SB), y;              \ 
  PSHUFB XTMP6, y;                    \ //y = _mm_shuffle_epi8(m2l, XTMP6)
  PSRLQ $4, x;                        \ //x = _mm_srli_epi64(x, 4);
  PAND nibble_mask<>(SB), x;          \ //x = _mm_and_si128(x, c0f); 
  MOVOU m2_high<>(SB), XTMP6;         \
  PSHUFB x, XTMP6;                    \
  MOVOU  XTMP6, x;                    \ //x = _mm_shuffle_epi8(m2h, x)
  PXOR y, x;                          \ //x = _mm_shuffle_epi8(m2h, x) ^ y; 

#define SM4_TAO_L1(x, y)         \
  SM4_SBOX(x, y);                     \
  ;                                   \ //####################  4 parallel L1 linear transforms ##################//
  MOVOU x, y;                         \
  PSHUFB r08_mask<>(SB), y;           \ //y = _mm_shuffle_epi8(x, r08)
  PXOR x, y;                          \ //y = x xor _mm_shuffle_epi8(x, r08)
  MOVOU x, XTMP6;                     \
  PSHUFB r16_mask<>(SB), XTMP6;       \ 
  PXOR XTMP6, y;                      \ //y = x xor _mm_shuffle_epi8(x, r08) xor _mm_shuffle_epi8(x, r16)
  MOVOU y, XTMP6;                     \
  PSLLL $2, XTMP6;                    \
  PSRLL $30, y;                       \
  POR XTMP6, y;                       \ //y = _mm_slli_epi32(y, 2) ^ _mm_srli_epi32(y, 30);  
  MOVOU x, XTMP7;                     \
  PSHUFB r24_mask<>(SB), XTMP7;       \
  PXOR y, x;                          \ //x = x xor y
  PXOR XTMP7, x                         //x = x xor y xor _mm_shuffle_epi8(x, r24);

#define SM4_TAO_L2(x, y)         \
  SM4_SBOX(x, y);                     \
  ;                                   \ //####################  4 parallel L2 linear transforms ##################//
  MOVOU x, y;                         \
  MOVOU x, XTMP6;                     \
  PSLLL $13, XTMP6;                   \
  PSRLL $19, y;                       \
  POR XTMP6, y;                      \ //y = X roll 13  
  PSLLL $10, XTMP6;                   \
  MOVOU x, XTMP7;                     \
  PSRLL $9, XTMP7;                    \
  POR XTMP6, XTMP7;                  \ //XTMP7 = x roll 23
  PXOR XTMP7, y;                      \
  PXOR y, x                        

#define SM4_ROUND(index, x, y, t0, t1, t2, t3)  \ 
  PINSRD $0, (index * 4)(AX)(CX*1), x;           \
  PSHUFD $0, x, x;                               \
  PXOR t1, x;                                    \
  PXOR t2, x;                                    \
  PXOR t3, x;                                    \
  SM4_TAO_L1(x, y);                              \
  PXOR x, t0

#define SM4_SINGLE_ROUND(index, x, y, t0, t1, t2, t3)  \ 
  PINSRD $0, (index * 4)(AX)(CX*1), x;           \
  PXOR t1, x;                                    \
  PXOR t2, x;                                    \
  PXOR t3, x;                                    \
  SM4_TAO_L1(x, y);                              \
  PXOR x, t0

#define SM4_EXPANDKEY_ROUND(index, x, y, t0, t1, t2, t3) \
  PINSRD $0, (index * 4)(BX)(CX*1), x;                   \
  PXOR t1, x;                                            \
  PXOR t2, x;                                            \
  PXOR t3, x;                                            \
  SM4_TAO_L2(x, y);                                      \
  PXOR x, t0;                                            \
  PEXTRD $0, t0, R8;                                     \
  MOVL R8, (index * 4)(DX)(CX*1);                        \
  MOVL R8, (12 - index * 4)(DI)(SI*1)

#define XDWORD0 Y4
#define XDWORD1 Y5
#define XDWORD2 Y6
#define XDWORD3 Y7

#define XWORD0 X4
#define XWORD1 X5
#define XWORD2 X6
#define XWORD3 X7

#define XTMP0 Y0
#define XTMP1 Y1
#define XTMP2 Y2
#define NIBBLE_MASK Y3
#define X_NIBBLE_MASK X3

#define BYTE_FLIP_MASK 	Y13 // mask to convert LE -> BE
#define XDWORD Y8
#define XWORD X8
#define YDWORD Y9
#define YWORD X9

#define TRANSPOSE_MATRIX(r0, r1, r2, r3) \
  VPUNPCKHDQ r1, r0, XTMP2;                \ // XTMP2 = [w15, w7, w14, w6, w11, w3, w10, w2]
  VPUNPCKLDQ r1, r0, r0;                   \ // r0 =    [w13, w5, w12, w4, w9, w1, w8, w0]
  VPUNPCKLDQ r3, r2, XTMP1;                \ // XTMP1 = [w29, w21, w28, w20, w25, w17, w24, w16]
  VPUNPCKHDQ r3, r2, r2;                   \ // r2 =    [w31, w27, w30, w22, w27, w19, w26, w18]
  VPUNPCKHQDQ XTMP1, r0, r1;               \ // r1 =    [w29, w21, w13, w5, w25, w17, w9, w1]
  VPUNPCKLQDQ XTMP1, r0, r0;               \ // r0 =    [w28, w20, w12, w4, w24, w16, w8, w0]
  VPUNPCKHQDQ r2, XTMP2, r3;               \ // r3 =    [w31, w27, w15, w7, w27, w19, w11, w3]
  VPUNPCKLQDQ r2, XTMP2, r2                  // r2 =    [w30, w22, w14, w6, w26, w18, w10, w2]

// https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html
#define AVX2_SM4_SBOX(x, y) \
  VBROADCASTI128 nibble_mask<>(SB), NIBBLE_MASK; \
  VPAND NIBBLE_MASK, x, XTMP1;                   \
  VBROADCASTI128 m1_low<>(SB), y;                \
  VPSHUFB XTMP1, y, y;                           \
  VPSRLQ $4, x, x;                               \
  VPAND NIBBLE_MASK, x, x;                       \
  VBROADCASTI128 m1_high<>(SB), XTMP1;           \
  VPSHUFB x, XTMP1, x;                           \
  VPXOR y, x, x;                                 \
  VBROADCASTI128 inverse_shift_rows<>(SB), XTMP1;\
  VPSHUFB XTMP1, x, x;                           \
  VEXTRACTI128 $1, x, YWORD                      \
  VAESENCLAST X_NIBBLE_MASK, XWORD, XWORD;       \
  VAESENCLAST X_NIBBLE_MASK, YWORD, YWORD;       \
  VINSERTI128 $1, YWORD, x, x;                   \
  VPANDN NIBBLE_MASK, x, XTMP1;                  \
  VBROADCASTI128 m2_low<>(SB), y;                \
  VPSHUFB XTMP1, y, y;                           \
  VPSRLQ $4, x, x;                               \
  VPAND NIBBLE_MASK, x, x;                       \
  VBROADCASTI128 m2_high<>(SB), XTMP1;           \
  VPSHUFB x, XTMP1, x;                           \
  VPXOR y, x, x

#define AVX2_SM4_TAO_L1(x, y) \
  AVX2_SM4_SBOX(x, y);                     \
  VBROADCASTI128 r08_mask<>(SB), XTMP0;    \
  VPSHUFB XTMP0, x, y;                     \
  VPXOR x, y, y;                           \        
  VBROADCASTI128 r16_mask<>(SB), XTMP0;    \
  VPSHUFB XTMP0, x, XTMP0;                 \
  VPXOR XTMP0, y, y;                       \
  VPSLLD $2, y, XTMP1;                     \
  VPSRLD $30, y, y;                        \
  VPXOR XTMP1, y, y;                       \
  VBROADCASTI128 r24_mask<>(SB), XTMP0;    \
  VPSHUFB XTMP0, x, XTMP0;                 \
  VPXOR y, x, x;                           \
  VPXOR x, XTMP0, x

#define AVX2_SM4_ROUND(index, x, y, t0, t1, t2, t3)  \ 
  VPBROADCASTD (index * 4)(AX)(CX*1), x;             \
  VPXOR t1, x, x;                                    \
  VPXOR t2, x, x;                                    \
  VPXOR t3, x, x;                                    \
  AVX2_SM4_TAO_L1(x, y);                             \  
  VPXOR x, t0, t0

// func expandKeyAsm(key *byte, ck, enc, dec *uint32)
TEXT ·expandKeyAsm(SB),NOSPLIT,$0
  MOVQ key+0(FP), AX
  MOVQ  ck+8(FP), BX
  MOVQ  enc+16(FP), DX
  MOVQ  dec+24(FP), DI

  MOVUPS 0(AX), t0
  PSHUFB flip_mask<>(SB), t0
  PXOR fk_mask<>(SB), t0
  PSHUFD $1, t0, t1
  PSHUFD $2, t0, t2
  PSHUFD $3, t0, t3

  XORL CX, CX
  MOVL $112, SI

loop:
  SM4_EXPANDKEY_ROUND(0, x, y, t0, t1, t2, t3)
  SM4_EXPANDKEY_ROUND(1, x, y, t1, t2, t3, t0)
  SM4_EXPANDKEY_ROUND(2, x, y, t2, t3, t0, t1)
  SM4_EXPANDKEY_ROUND(3, x, y, t3, t0, t1, t2)

  ADDL $16, CX
  SUBL $16, SI
  CMPL CX, $4*32
  JB loop

expand_end:  
  RET 

// func encryptBlocksAsm(xk *uint32, dst, src []byte)
TEXT ·encryptBlocksAsm(SB),NOSPLIT,$0
  MOVQ xk+0(FP), AX
  MOVQ dst+8(FP), BX
  MOVQ src+32(FP), DX
  MOVQ src_len+40(FP), DI
  
  CMPL DI, $64
  JBE non_avx2_start

  CMPB ·useAVX2(SB), $1
  JE   avx2

non_avx2_start:
  PINSRD $0, 0(DX), t0
  PINSRD $1, 16(DX), t0
  PINSRD $2, 32(DX), t0
  PINSRD $3, 48(DX), t0
  PSHUFB flip_mask<>(SB), t0

  PINSRD $0, 4(DX), t1
  PINSRD $1, 20(DX), t1
  PINSRD $2, 36(DX), t1
  PINSRD $3, 52(DX), t1
  PSHUFB flip_mask<>(SB), t1

  PINSRD $0, 8(DX), t2
  PINSRD $1, 24(DX), t2
  PINSRD $2, 40(DX), t2
  PINSRD $3, 56(DX), t2
  PSHUFB flip_mask<>(SB), t2

  PINSRD $0, 12(DX), t3
  PINSRD $1, 28(DX), t3
  PINSRD $2, 44(DX), t3
  PINSRD $3, 60(DX), t3
  PSHUFB flip_mask<>(SB), t3

  XORL CX, CX

loop:
  SM4_ROUND(0, x, y, t0, t1, t2, t3)
  SM4_ROUND(1, x, y, t1, t2, t3, t0)
  SM4_ROUND(2, x, y, t2, t3, t0, t1)
  SM4_ROUND(3, x, y, t3, t0, t1, t2)

  ADDL $16, CX
  CMPL CX, $4*32
  JB loop

  PSHUFB flip_mask<>(SB), t3
  PSHUFB flip_mask<>(SB), t2
  PSHUFB flip_mask<>(SB), t1
  PSHUFB flip_mask<>(SB), t0
  MOVUPS t3, 0(BX)
  MOVUPS t2, 16(BX)
  MOVUPS t1, 32(BX)
  MOVUPS t0, 48(BX)
  MOVL  4(BX), R8
  MOVL  8(BX), R9
  MOVL  12(BX), R10
  MOVL  16(BX), R11
  MOVL  32(BX), R12
  MOVL  48(BX), R13
  MOVL  R11, 4(BX)
  MOVL  R12, 8(BX)
  MOVL  R13, 12(BX)
  MOVL  R8, 16(BX)
  MOVL  R9, 32(BX)
  MOVL  R10, 48(BX)
  MOVL  24(BX), R8
  MOVL  28(BX), R9
  MOVL  36(BX), R10
  MOVL  52(BX), R11
  MOVL  R10, 24(BX)
  MOVL  R11, 28(BX)
  MOVL  R8, 36(BX)
  MOVL  R9, 52(BX)
  MOVL  44(BX), R8
  MOVL  56(BX), R9
  MOVL  R9, 44(BX)
  MOVL  R8, 56(BX)

done_sm4:
  RET

avx2:
  VMOVDQU 0(DX), XDWORD0
  VMOVDQU 32(DX), XDWORD1
  VMOVDQU 64(DX), XDWORD2
  VMOVDQU 96(DX), XDWORD3
  VBROADCASTI128 flip_mask<>(SB), BYTE_FLIP_MASK

	// Apply Byte Flip Mask: LE -> BE
	VPSHUFB BYTE_FLIP_MASK, XDWORD0, XDWORD0
	VPSHUFB BYTE_FLIP_MASK, XDWORD1, XDWORD1
	VPSHUFB BYTE_FLIP_MASK, XDWORD2, XDWORD2
	VPSHUFB BYTE_FLIP_MASK, XDWORD3, XDWORD3

  // Transpose matrix 4 x 4 32bits word
  TRANSPOSE_MATRIX(XDWORD0, XDWORD1, XDWORD2, XDWORD3)

  XORL CX, CX

avx2_loop:
  AVX2_SM4_ROUND(0, XDWORD, YDWORD, XDWORD0, XDWORD1, XDWORD2, XDWORD3)
  AVX2_SM4_ROUND(1, XDWORD, YDWORD, XDWORD1, XDWORD2, XDWORD3, XDWORD0)
  AVX2_SM4_ROUND(2, XDWORD, YDWORD, XDWORD2, XDWORD3, XDWORD0, XDWORD1)
  AVX2_SM4_ROUND(3, XDWORD, YDWORD, XDWORD3, XDWORD0, XDWORD1, XDWORD2)

  ADDL $16, CX
  CMPL CX, $4*32
  JB avx2_loop

  // Transpose matrix 4 x 4 32bits word
  TRANSPOSE_MATRIX(XDWORD0, XDWORD1, XDWORD2, XDWORD3)

  VBROADCASTI128 flip_mask2<>(SB), BYTE_FLIP_MASK
	VPSHUFB BYTE_FLIP_MASK, XDWORD0, XDWORD0
	VPSHUFB BYTE_FLIP_MASK, XDWORD1, XDWORD1
	VPSHUFB BYTE_FLIP_MASK, XDWORD2, XDWORD2
	VPSHUFB BYTE_FLIP_MASK, XDWORD3, XDWORD3
  
  VMOVDQU XDWORD0, 0(BX)
  VMOVDQU XDWORD1, 32(BX)
  VMOVDQU XDWORD2, 64(BX)
  VMOVDQU XDWORD3, 96(BX)

  VZEROUPPER
  RET

// func encryptBlockAsm(xk *uint32, dst, src *byte)
TEXT ·encryptBlockAsm(SB),NOSPLIT,$0
  MOVQ xk+0(FP), AX
  MOVQ dst+8(FP), BX
  MOVQ src+16(FP), DX
  
  PINSRD $0, 0(DX), t0
  PSHUFB flip_mask<>(SB), t0

  PINSRD $0, 4(DX), t1
  PSHUFB flip_mask<>(SB), t1

  PINSRD $0, 8(DX), t2
  PSHUFB flip_mask<>(SB), t2

  PINSRD $0, 12(DX), t3
  PSHUFB flip_mask<>(SB), t3

  XORL CX, CX

loop:
  SM4_SINGLE_ROUND(0, x, y, t0, t1, t2, t3)
  SM4_SINGLE_ROUND(1, x, y, t1, t2, t3, t0)
  SM4_SINGLE_ROUND(2, x, y, t2, t3, t0, t1)
  SM4_SINGLE_ROUND(3, x, y, t3, t0, t1, t2)

  ADDL $16, CX
  CMPL CX, $4*32
  JB loop

  PSHUFB flip_mask<>(SB), t3
  PSHUFB flip_mask<>(SB), t2
  PSHUFB flip_mask<>(SB), t1
  PSHUFB flip_mask<>(SB), t0
  MOVUPS t3, 0(BX)
  PEXTRD $0, t2, R8
  MOVL R8, 4(BX)
  PEXTRD $0, t1, R8
  MOVL R8, 8(BX)
  PEXTRD $0, t0, R8
  MOVL R8, 12(BX)
done_sm4:
	RET
