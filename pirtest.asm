/*
*author:xim
*date:2019-11-1
*
*/
DEF:
    LOOPTAG EQU 60H;次数统计保存地址
    LOOPTIME EQU 59H;延时循环次数保存地址
    OFFSET1 EQU 58H;个位偏移地址记录
    OFFSET2 EQU 57H;十位偏移地址记录
    BALANCE EQU 56H;负载 均衡标记
    DEFAULTDT EQU 55H;
    THT EQU 0D8H;计数器高字节
    TLT EQU 0F0H;计数器低字节

    KEYBUF1 EQU 54H;键盘读入数据十位
    KEYBUF2 EQU 53H;键盘读入数据个位；
    KEYBUF3 EQU 52H;
    ADJUSTFLAG EQU 51H;

    ORG 0000H;
    AJMP MAIN;
    ORG 000BH;T0溢出中断入口地址
    AJMP DELAY;
    ORG 0013H;
    AJMP KBSCN;
    ORG 0060H;
    ;!!!!JNZ需要更改 JNZ 是为了测试


MAIN:
    MOV SP,#60H;
    
    MOV OFFSET1,#0AH;
    MOV OFFSET2,#03H;
    MOV DEFAULTDT,#30;
    MOV LOOPTIME,#05H;
    MOV ADJUSTFLAG,#1;
    MOV KEYBUF2,#00H;
    SETB EA;
	SETB EX1;
	SETB IT1;
    /*外部中断1最高优先级*/
    SETB PX1;
    
    LOOP:
        MOV LOOPTAG,#00H;
        MOV BALANCE,#0FFH;
        MOV ADJUSTFLAG,#1;

        MOV P1,#0FFH;p1为数据输出，点亮LED用
        MOV P0,#00H;

        MOV P3,#0FFH;p3为键盘输入口
        CLR P3.7;
        MOV P2,#0FFH;p2作为数据输入口
        ;LCALL DELAY4KBD;每秒100次

        ;MOV R7,#0AH;
        ;DTCNSPDCNRL:;DETECTION SPEED CONTROL 检测速度控制
        SETB IT1;进入键盘中断后把外部中断设置为电平触发，消除机械键盘毛刺影响；退出中断后再恢复；
            

        MOV A,P2;
        ANL A,#07H; 0  截取三位输入信号，只有输入信号是1，3，5才点亮
        CJNE A,#01H,CMP3;
        AJMP LIGHT;
        CMP3:
            CJNE A,#03H,CMP5;
            AJMP LIGHT;为3，直接跳转到LIGHT
        CMP5:
            CJNE A,#05H,LOOP;为5，执行LIGHT否则返回继续读取P2口

    LIGHT:
        CPL P1.0;
        NOP;
        NOP;
        MOV R5,DEFAULTDT;
        MOV R2,OFFSET2;存放数码管十位对应偏移地址
        MOV A,ADJUSTFLAG;
        CJNE A,#0,ADJUST;
        MOV R3,OFFSET1;存放数码管个位对应偏移地址
        
        AJMP LIGHTTIME;
        ADJUST:
            MOV A,KEYBUF2;
            CJNE A,#00H,ADJUST1;
            MOV R3,OFFSET1;
            AJMP LIGHTTIME;
            ADJUST1:
            MOV R3,A;
            MOV ADJUSTFLAG,#0;

        LIGHTTIME:
            LCALL DELAY1S;延时1s后数码管显示相应数字
            SETB IT1;进入键盘中断后把外部中断设置为电平触发，消除机械键盘毛刺影响；退出中断后再恢复；

            /********************************/
            ;MOV P2,#0FFH;p2作为数据输入口
            MOV P0,#00H;
            MOV A,P2;
            ANL A,#07H; 0  截取三位输入信号，只有输入信号是1，3，5才点亮
            ;JZ LIGHT;为0直接跳转到点亮led；
            CJNE A,#01H,CMP3INT;
            CLR TR0;
            CLR ET0;
            MOV ADJUSTFLAG,#1;
            AJMP LIGHT;
            CMP3INT:
                CJNE A,#03H,CMP5INT;
                CLR TR0;
                CLR ET0;
                MOV ADJUSTFLAG,#1;
                AJMP LIGHT;为2，直接跳转到LIGHT
            CMP5INT:
                CJNE A,#05H,NOINT;为4，执行LIGHT否则返回继续读取P2口
                CLR TR0;
                CLR ET0;
                MOV ADJUSTFLAG,#1;
                AJMP LIGHT;
                /**************************************/

            NOINT:
                DEC R3;
                MOV A,#00H;
                CJNE A,03H,CFG;
                DEC R2;
            CFG:
                CJNE R3,#00H,ASGTO;
                MOV R3,OFFSET1;
            ASGTO:
                DJNZ R5,LIGHTTIME;
                CPL P1.0;
                CLR P2.6;
                SETB P2.7;
                MOV P0,#00H;
                CLR P2.7;
                SETB P2.6;
                MOV P0,#00H;
                CLR P2.6;
                AJMP LOOP;

;延时1s子程序
DELAY1S:
        ;PUSH PSW;
        ;PUSH ACC;
        ;AJMP DELAY10MS;
    /*延时10ms子程序 65536-10000=55536=0D8F0H
    *设置延时10ms：数码管动态刷新频率需要高于50hz，人眼才能察觉不到变化；
    *中断服务程序里面数码管动态刷新采用负载均衡的思想，
    *即改变数码管动态刷新的顺序，以达到各个数码管上电时间的均衡，
    *
    *
    *       中断--------->数码管A------>数码管B
    *           .
    *           .
    *           .-------->数码管B------>数码管A
    *10ms延时刷新频率为50hz，不是100hz，因为是两次中断才刷新一次
    *
    *
    */
    DELAY10MS:
        MOV TMOD,#01H;计数器1工作于方式1
        MOV TH0,#THT;加一计数器高字节
        MOV TL0,#TLT;加一计数器低字节
        ;SETB EA;
        SETB TR0;
        SETB ET0;
        
    TIMEOUT:  
        MOV R6,LOOPTAG;
        CJNE R6,#64H,TIMEOUT;
        MOV LOOPTAG,#00H;
        ;POP ACC;
        ;POP PSW;
        RET;




;计数器1溢出中断出口
DELAY:
        PUSH PSW;
        PUSH ACC;
        MOV R6,LOOPTAG;
        INC R6;
        MOV LOOPTAG,R6;
        MOV TH0,#THT;加一计数器高字节
        MOV TL0,#TLT;加一计数器低字节

        
        ;点亮数码管
    NUMDIS:
    
        
        MOV A,R6;
        ANL A,#01H;
        MOV BALANCE,A;负载均衡
        JNZ BAL2;
    BAL1:
        MOV R4,#0FDH;R4存放数码管位置个位
        
        ;MOV R3,A;
        CLR P2.6;位选选中个位
        SETB P2.7;
        ;MOV P0,#0FFH;
        MOV P0,R4;
        CLR P2.7;

        MOV DPTR,#TIMETAB;
        MOV A,R3;
        MOVC A,@A+DPTR;查表得到相应数字对应值
        SETB P2.6;
        MOV P0,#00H;
        MOV P0,A;
        MOV A,BALANCE;
        JNZ BAL3;
        ;LCALL PWNWAT;延时1ms
        ;LCALL PWNWAT;
        
    BAL2:
        MOV R4,#0FEH;
    
        MOV DPTR, #TIMETAB;
        MOV A,R2;
        MOVC A,@A+DPTR;
        ;CALL PWNWAT;
        CLR P2.6;
        SETB P2.7;
        ;MOV P0,#0FFH;
        MOV P0,R4;
        CLR P2.7;
        SETB P2.6;
        MOV P0,#00H;
        MOV P0,A;
        MOV A,BALANCE;
        JNZ BAL1;
        ;LCALL PWNWAT;
    BAL3:
        CJNE R6,#64H,BREAK;
        CLR P2.6;
        
        CLR TR0;
        CLR ET0;
        ;CLR EA;
        MOV TMOD,#00H;
        ;MOV 60H,#00H;
        
    BREAK:
        POP ACC;
        POP PSW;
        RETI;



/*1号中断入口
*键盘响应
*   键盘模型
*   X       7       8       9   P3.0
*   X       4       5       6   P3.1
*   X       1       2       3   P3.2
*   X       *       0       #   P3.3
*
*   P3.4    P3.5    P3.6    P3.7
*
*   *作为确认设置按键
*   #作为‘设置’按键，按下‘#’就进入设置
*
*
*
*/
KBSCN:

        CPL P1.7;p1.7为键盘中断标志，灯亮说明正确进入键盘中断服务程序
        /*默认设置，倒计时30s*/
        MOV KEYBUF1,#03H;
        MOV KEYBUF2,#00H;
        MOV DEFAULTDT,#30;
        /*进入中断等待按键释放，*/
    WAT4RLS:;WAITE FOR REALSE
        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JNZ WAT4RLS;


        /*保护现场，PSW,ACC入栈，使用第二组寄存器*/
        PUSH PSW;
        PUSH ACC;
        SETB RS0;USE THE SECOND SET OF REGISTERS;
        CLR IT1;
        MOV R1,#0;R1用作标志，用来标记数据应该存入哪个buf。

    /*
    *扫描原理：截取P3口低四位，异或1111，哪一位为1说明这一位对应的按键被按下，
    *一次只能判断一位，若多位同时按下，则无法判断，
    *键盘事件响应的结果存入KEYBUF1和KEYBUF2，KEYBUF1存放十位，KEYBUF2存放个位，
    *循环移位存储，若顺序按下2，4，结果为(KEYBUF1)=2，(KEYBUF2)=4;
    *若顺序按下2，4，2，(KEYBUF1)=4,(KEYBUF2)=2;
    *C11对应第一列第一行；C12对应第一列第二行
    */

    /*第一列扫描，程序未使用第一列键盘，故此列键盘不响应*/
    KBSCNR1:
        MOV P3,#0FFH;
        CLR P3.4;
        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JZ KBSCNR2;
        /*键盘消抖*/
        CALL DELAY4KBD;

        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JZ KBSCNR2;
    C11:
        NOP;
    C12:
        NOP;
    C13:
        NOP;
    C14:
        NOP;
    /*等待按键释放*/
    WAT4RLS1:;WAITE FOR REALSE
        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JNZ WAT4RLS1;

    KBSCNR2:
        MOV P3,#0FFH;
        CLR P3.5;
        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JZ KBSCNR3;
        CALL DELAY4KBD;

        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JZ KBSCNR3;

    C21:
        CJNE A,#01H,C22;0001左上角被按下
        /*
        *条件判断，选择存数据到哪个KEYBUF
        */
        CJNE R1,#0,C21BUF2;
        MOV KEYBUF1,#07H;
        CPL P1.0;
        MOV R1,#1;
        AJMP WAT4RLS2;
    C21BUF2:
        MOV KEYBUF2,#07H;
        MOV R1,#0;
        AJMP WAT4RLS2;
    C22:
        CJNE A,#02H,C23;
        CJNE R1,#0,C22BUF2;
        MOV KEYBUF1,#04H;
        MOV R1,#1;
        AJMP WAT4RLS2;
    C22BUF2:
        MOV KEYBUF2,#04H;
        MOV R1,#0;
        AJMP WAT4RLS2;
    C23:
        CJNE A,#04H,C24;
        CJNE R1,#0,C23BUF2;
        MOV KEYBUF1,#01H;
        MOV R1,#1;
        AJMP WAT4RLS2;
    C23BUF2:
        MOV KEYBUF2,#01H;
        MOV R1,#0;
        AJMP WAT4RLS2;
    C24:
        CJNE A,#08H,WAT4RLS2;
        ;MOV KEYBUF1,#0FFH;
        AJMP EXITSET;

    WAT4RLS2:;WAITE FOR REALSE
        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JNZ WAT4RLS2;




    KBSCNR3:
        MOV P3,#0FFH;
        CLR P3.6;
        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JZ KBSCNR4;
        CALL DELAY4KBD;

        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JZ KBSCNR4;

    C31:
        CJNE A,#01H,C32;0001左上角被按下
        CJNE R1,#0,C31BUF2;
        MOV KEYBUF1,#08H;
        MOV R1,#1;
        AJMP WAT4RLS3;
    C31BUF2:
        MOV KEYBUF2,#08H;
        MOV R1,#0;
        AJMP WAT4RLS3;
    C32:
        CJNE A,#02H,C33;
        CJNE R1,#0,C32BUF2;
        MOV KEYBUF1,#05H;
        MOV R1,#1;
        AJMP WAT4RLS3;
    C32BUF2:
        MOV KEYBUF2,#05H;
        MOV R1,#0;
        AJMP WAT4RLS3;
    C33:
        CJNE A,#04H,C34;
        CJNE R1,#0,C33BUF2;
        MOV KEYBUF1,#02H;
        MOV R1,#1;
        AJMP WAT4RLS3;
    C33BUF2:
        MOV KEYBUF2,#02H;
        MOV R1,#0;
        AJMP WAT4RLS3;
    C34:
        CJNE A,#08H,WAT4RLS2;
        CJNE R1,#0,C34BUF2;
        MOV KEYBUF1,#00H;
        MOV R1,#1;
        AJMP WAT4RLS3;
    C34BUF2:
        MOV KEYBUF2,#00H;
        MOV R1,#0;

    WAT4RLS3:;WAITE FOR REALSE
        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JNZ WAT4RLS3;

    KBSCNR4:
        MOV P3,#0FFH;
        CLR P3.7;
        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JZ KBSCNEND;
        CALL DELAY4KBD;

        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JZ KBSCNEND;

    C41:
        CJNE A,#01H,C42;0001左上角被按下
        CJNE R1,#0,C41BUF2;
        MOV KEYBUF1,#09H;
        MOV R1,#1;
        AJMP WAT4RLS4;
    C41BUF2:
        MOV KEYBUF2,#09H;
        MOV R1,#0;
        AJMP WAT4RLS4;
    C42:
        CJNE A,#02H,C43;
        CJNE R1,#0,C42BUF2;
        MOV KEYBUF1,#06H;
        MOV R1,#1;
        AJMP WAT4RLS4;
    C42BUF2:
        MOV KEYBUF2,#06H;
        MOV R1,#0;
        AJMP WAT4RLS4;
    C43:
        CJNE A,#04H,C44;
        CJNE R1,#0,C43BUF2;
        MOV KEYBUF1,#03H;
        MOV R1,#1;
        AJMP WAT4RLS4;
    C43BUF2:
        MOV KEYBUF2,#03H;
        MOV R1,#0;
        AJMP WAT4RLS4;
    C44:
        CJNE A,#08H,WAT4RLS4;
        NOP;

    WAT4RLS4:;WAITE FOR REALSE
        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JNZ WAT4RLS4;



    KBSCNEND:

        CLR P2.6;
        SETB P2.7;
        MOV P0,#0FEH;
        CALL DELAY4KBD;
        CLR P2.7;
        SETB P2.6;
        MOV DPTR,#TIMETAB;
        MOV A,R1;
        JZ DISBUF2; 
        MOV A,KEYBUF1;
        INC A;
        MOVC A,@A+DPTR;
        MOV P0,A;
        CALL DELAY4KBD;
        AJMP DISBUFEND;
        DISBUF2:
            MOV A,KEYBUF2;
            INC A;
            MOVC A,@A+DPTR;
            MOV P0,A;
            CALL DELAY4KBD;
        DISBUFEND:

        AJMP KBSCNR1;
    EXITSET:
        CPL P1.7;
        ;CPL P1.1;
    /*退出中断，等待键盘释放，*/
    WAT4EXIT:;WAITE FOR REALSE
        MOV A,P3;
        ANL A,#0FH;
        XRL A,#0FH;
        JNZ WAT4EXIT;

        /*需要设置offset1 offset2 第一组寄存器的R5，R5存放定时秒数
        *OFFSET1为个位，offset2为十位
        *buf2为个位，buf1为十位
        */

        MOV A,KEYBUF1;
        MOV B,#10;
        MUL AB;
        ADD A,KEYBUF2;
        MOV KEYBUF3,A;

        CLR RS0;USE THE DEFAULT SET OF REGISTERS;
        POP ACC;
        POP PSW;

        MOV OFFSET2,KEYBUF1;
        /*为什么要用R4,因为r6,r5,r3,r2都为专用寄存器，不要改变他们的值
        R7,R1,R0都可以用
        这里是第一组寄存器

        为什么整数十的倍数不需要加一，因为在主程序里面判断了计数值是不是十的倍数
        */
        MOV R4,KEYBUF2;
        CJNE R4,#00H,NDINC;
        MOV DEFAULTDT,KEYBUF3;
        AJMP NDINCBK;
        NDINC:
        ;MOV R5,KEYBUF3;
        INC OFFSET2;为什么要加1，因为存放数码管对应16进制的表最前面多加了一个00H;
        MOV DEFAULTDT,KEYBUF3;
        NDINCBK:
        MOV ADJUSTFLAG,#1;
        ;SETB IT1;
        MOV P3,#0FFH;
        CLR P3.7;
        RETI;


    DELAY4KBD:
        MOV R6,#10
    D1:        
        MOV R7,#248
        DJNZ R7,$
        DJNZ R6,D1
        RET






/*废弃，未使用*/
PWNWAT: ;power on wait
        PUSH PSW;
        PUSH ACC;
        SETB RS0;
        MOV R1,#40;
        MOV R2,#10;
    PW1:
        NOP;
        NOP;
        DJNZ R1,PW1;
        MOV R1,#40;
        DJNZ R2,PW1;
        POP ACC;
        POP PSW;
        RET;


TIMETAB:
    DB 00H,3FH,06H,5BH;
    DB 4FH,66H,6DH,7DH;
    DB 07H,7FH,6FH;
    ;DB 6FH,7FH,07H,7DH;
    ;DB 6DH,66H,4FH,5BH;
    ;DB 06H,3FH;
END;