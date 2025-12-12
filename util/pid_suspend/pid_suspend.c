#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <unistd.h>

/* Suppress deprecation warning - syscall() is the only way to call pid_suspend */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <pid>\n", argv[0]);
        return 1;
    }

    pid_t pid = (pid_t)atoi(argv[1]);
    if (pid <= 0) {
        fprintf(stderr, "Invalid PID: %s\n", argv[1]);
        return 1;
    }

    int result = syscall(SYS_pid_suspend, pid);
    if (result == -1) {
        perror("pid_suspend failed");
        return 1;
    }

    printf("Successfully suspended process %d\n", pid);
    return 0;
}

#pragma clang diagnostic pop
