#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

int main(void) {
	int a = 5;
	int b = 10;
	if ((a > 6) >= (b > 7)) {
		printf("The material condition is true\n");
	} else {
		printf("The material condition is false\n");
	}
}
