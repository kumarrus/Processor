#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>

#define WIDTH 16
#define DEPTH 256

enum Assembly {
	mv = 0,
	mvi = 1,
	add = 2,
	sub = 3,
	ld = 4,
	st = 5,
	sthex = 7,
	ldsw = 8,
	stled = 8
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

int ledChipSel = 1;
int switchChipSel = 2;
int hexChipSel = 4;
FILE *outFile;
char *outFilename = "inst_mem.mif";
FILE *inFile;
char *inFilename = "assm_code.txt";
int instruction_no = 0;

void remove_newline(char *walker) {
	while(walker && *walker != '\n')
		walker++;
	if(walker)
		*walker = 0;
}

char* tokenize(char *walker) {
	while(walker && *walker != ' ' && *walker != ',' && *walker != '\t')
		walker++;
	while(walker && (*walker == ' ' || *walker == ',' || *walker == '\t')) {
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
	fprintf(outFile, "\t%d   :   %d;\n", instruction_no++, out);

	out = imm16;
	fprintf(outFile, "\t%d   :   %d;\n", instruction_no++, out);
}

void gen_comm(int ass, char* rx, char* ry) {
	int regNum;
	int out = ass;


	sscanf(rx, "%*c%d", &regNum);
	out = (out<<3) + regNum;

	sscanf(ry, "%*c%d", &regNum);
	out = (out<<3) + regNum;

	out = (out<<7);	//padd with zeroes to make 16-bit
	fprintf(outFile, "\t%d   :   %d;\n", instruction_no++, out);
}

void initialize_file()
{
	fprintf(outFile, "WIDTH=%d;\n", WIDTH);
	fprintf(outFile, "DEPTH=%d;\n\n", DEPTH);
	fprintf(outFile, "ADDRESS_RADIX=UNS;\nDATA_RADIX=UNS;\n\n");
	fprintf(outFile, "CONTENT BEGIN\n");
}


ssize_t getdelim(char **linep, size_t *n, int delim, FILE *fp){
    int ch;
    size_t i = 0;
    if(!linep || !n || !fp){
        errno = EINVAL;
        return -1;
    }
    if(*linep == NULL){
        if(NULL==(*linep = malloc(*n=128))){
            *n = 0;
            errno = ENOMEM;
            return -1;
        }
    }
    while((ch = fgetc(fp)) != EOF){
        if(i + 1 >= *n){
            char *temp = realloc(*linep, *n + 128);
            if(!temp){
                errno = ENOMEM;
                return -1;
            }
            *n += 128;
            *linep = temp;
        }
        (*linep)[i++] = ch;
        if(ch == delim)
            break;
    }
    (*linep)[i] = '\0';
    return !i && ch == EOF ? -1 : i;
}
ssize_t getline(char **linep, size_t *n, FILE *fp){
    return getdelim(linep, n, '\n', fp);
}

int main() {

	inFile = fopen(inFilename, "r");

	outFile = fopen(outFilename, "w");
	initialize_file();

	char * code = NULL;
	size_t len = 0;
	ssize_t read;
	//char code[50] = {0};

	while((read = getline(&code, &len, inFile)) != -1){
		//fgets (code, 50, stdin);

		if(code[0] == '#' || code[0] == '\n')
			continue;

		char *command = code;
		char *arg1 = tokenize(code);
		char *arg2 = tokenize(code);
		remove_newline(arg2);

		printf("::%s::%s::%s::\n", command, arg1, arg2);

		if(strcmp(command, "sthex")==0) { //store hex
			//uses r5 as addr	-	CCCC 0000 0000 0000
			//uses r6 as data	-	DDDD DDDD DDDD DDDD

			//mvi r5, addr
			int addr = (hexChipSel<<12);
			mvi_func(r5, addr);

            int num0, num1, num2, num3;
            int totalNum = 0;
			sscanf(arg1, "%x%x", &num3, &num2);
			sscanf(arg2, "%x%x", &num1, &num0);

            totalNum = (num3<<12) + (num2<<8) + (num1<<4) + num0;
			//mvi r6, data
			mvi_func(r6, totalNum);

			//st r6, r5
			gen_comm(st, "r6", "r5");
		}
		else if(strcmp(command, "ldsw")==0) { //load switches
			//uses rx as dest
			//uses ry as source -	CCCC 0000 0000 0000
			int rx, ry;
			sscanf(arg1, "%*c%d", &rx);
			sscanf(arg2, "%*c%d", &ry);

			//mvi ry, addr
			int addr = (switchChipSel<<12);
			mvi_func(ry, addr);

			//ld rx, ry
			gen_comm(ld, arg1, arg2);
		}
		else if(strcmp(command, "stled")==0) { //store leds
			//uses rx as source	-   0000 0000 0000 0000
			//uses ry as dest	-	CCCC 0000 0000 0000

            int rx, ry;
			sscanf(arg1, "%*c%d", &rx);
			sscanf(arg2, "%*c%d", &ry);

			//mvi ry, addr
			int addr = (ledChipSel<<12);
			mvi_func(ry, addr);

			//st rx, ry
			gen_comm(st, arg1, arg2);
		}
		else {
			if(strcmp(command, "mv")==0)
				gen_comm(mv, arg1, arg2);
			if(strcmp(command, "mvi")==0) {
				int reg, imm;
				sscanf(arg1, "%*c%d", &reg);
				imm = atoi(arg2);
				mvi_func(reg, imm);
			}
			if(strcmp(command, "add")==0)
				gen_comm(add, arg1, arg2);
			if(strcmp(command, "sub")==0)
				gen_comm(sub, arg1, arg2);
			else if(strcmp(command, "ld")==0)
				gen_comm(ld, arg1, arg2);
			else if(strcmp(command, "st")==0)
				gen_comm(st, arg1, arg2);
			else if(strcmp(command, "mvnz")==0)
				gen_comm(st, arg1, arg2);
		}
	}

	fprintf(outFile, "\t[%d..%d]  :   %d;\n", instruction_no, DEPTH-1, 0);
	fprintf(outFile, "END;\n");
	fclose(outFile);

	fclose(inFile);

	return 0;
}
