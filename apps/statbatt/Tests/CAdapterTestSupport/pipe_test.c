#include "AdapterTestSupport.h"
#include "StatBattAdapterControl.h"
#include <unistd.h>
#include <errno.h>
#include <sys/wait.h>

int sb_test_broken_pipe(void) {
    int descriptors[2];
    if (pipe(descriptors) != 0) return -1;
    close(descriptors[0]);
    pid_t child = fork();
    if (child == 0) {
        /* Only async-signal-safe operations; no Swift or Foundation after fork. */
        sb_control_ignore_broken_output();
        char byte = 1;
        ssize_t result = write(descriptors[1], &byte, 1);
        _exit(result == -1 && errno == EPIPE ? 0 : 2);
    }
    close(descriptors[1]);
    if (child < 0) return -1;
    int status = 0;
    while (waitpid(child, &status, 0) < 0) { if (errno != EINTR) return -1; }
    return status;
}
