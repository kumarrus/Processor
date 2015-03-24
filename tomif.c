#include <stdio.h>
#include <string.h>
#include <stdlib.h>

enum Assembly {
	mvi = 1,
	ld = 4,
	st = 5,
	sthex = 7,
	ldsw = 8
};

enum reg {
	r0,
	r1,
	r2,
	r3,
	r4,
	r5,
	r6,
	r7
};

int hexChipSel = 2;
int switchChipSel = 4;

void remove_newline(char *walker) {
	while(walker && *walker != '\n')
		walker++;
	if(walker)
		*walker = 0;
}

char* tokenize(char *walker) {
	while(walker && *walker != ' ')
		walker++;
	if(walker) {
		*walker=0;
		walker++;
	}
	return walker;
}

void mvi_func(int reg, int imm16) {
	int out=0;
	//mvi r5, addr
	out = (mvi<<3) + reg;
	out = (out<<10);
	printf("%d\n", out);

	out = imm16;
	printf("%d\n", out);
}

void gen_comm(int ass, char* rx, char* ry) {
	int regNum;
	int out = ass;

	sscanf(rx, "%*c%d", &regNum);
	out = (out<<3) + regNum;

	sscanf(ry, "%*c%d", &regNum);
	out = (out<<3) + regNum;

	out = (out<<7);	//padd with zeroes to make 16-bit
	printf("%d\n", out);
}

void main() {
	char code[50] = {0};
	fgets (code, 50, stdin);

	char *command = code;
	char *arg1 = tokenize(code);
	char *arg2 = tokenize(code);
	remove_newline(arg2);

	int regNum;
	int out=0;

	if(strcmp(command, "sthex")==0) { //store hex
		//uses r5 as addr	-	0010 0000 0000 0xxx
		//uses r6 as data	-	0000 0000 0xxx xxxx

		//mvi r5, addr
		int addr = (hexChipSel<<12) + atoi(arg1);
		mvi_func(r5, addr);

		//mvi r6, data
		mvi_func(r6, atoi(arg2));

		//pending st
	}
	else if(strcmp(command, "ldsw")==0) { //load switches
		//uses r5 as addr	-	0100 0000 0000 0000
		//uses r6 as target

		//mvi r5, addr
		int addr = (switchChipSel<<12);
		mvi_func(r5, addr);

		//ld r6, r5
		out = ld;
		out = (out<<3) + r6;
		out = (out<<3) + r5;
		out = (out<<7);
		printf("%d\n", out);
	}
	else {
		if(strcmp(command, "ld")==0)
			gen_comm(ld, arg1, arg2);
		else if(strcmp(command, "st")==0)
			gen_comm(st, arg1, arg2);
	}
}
