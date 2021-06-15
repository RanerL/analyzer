// SKIP PARAM: --sets solver td3 --set ana.activated "['base','threadid','threadflag','mallocWrapper']"
// Example from https://github.com/sosy-lab/sv-benchmarks/blob/master/c/bitvector-regression/signextension-1.c
// TODO: make this work for octApron by handling variable casts
#include "stdio.h"
int main() {

  unsigned short int allbits = -1;
  short int signedallbits = allbits;
  int unsignedtosigned = allbits;
  unsigned int unsignedtounsigned = allbits;
  int signedtosigned = signedallbits;
  unsigned int signedtounsigned = signedallbits;


  printf ("unsignedtosigned: %d\n", unsignedtosigned);
  printf ("unsignedtounsigned: %u\n", unsignedtounsigned);
  printf ("signedtosigned: %d\n", signedtosigned);
  printf ("signedtounsigned: %u\n", signedtounsigned);


  if (unsignedtosigned == 65535 && unsignedtounsigned == 65535
      && signedtosigned == -1 && signedtounsigned == 4294967295) {
    assert(1);
  }

  return (0);
}
