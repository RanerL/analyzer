#include <pthread.h>
#include <assert.h>

int g;

int main() {
  void (*unknown)(void*);

  pthread_t id;
  pthread_create(&id, NULL, unknown, NULL);

  assert(g == 0); // UNKNOWN! (unknown thread may invalidate)
  return 0;
}
