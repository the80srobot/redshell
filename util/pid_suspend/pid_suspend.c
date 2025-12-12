#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>

/* Suppress deprecation warning - syscall() is the only way to call pid_suspend/resume */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <--suspend|--resume|--check> <pid>\n", argv[0]);
        return 1;
    }

    const char *action = argv[1];
    pid_t pid = (pid_t)atoi(argv[2]);
    if (pid <= 0) {
        fprintf(stderr, "Invalid PID: %s\n", argv[2]);
        return 1;
    }

    int result;
    if (strcmp(action, "--suspend") == 0) {
        result = syscall(SYS_pid_suspend, pid);
        if (result == -1) {
            perror("pid_suspend failed");
            return 1;
        }
        printf("Successfully suspended process %d\n", pid);
    } else if (strcmp(action, "--resume") == 0) {
        result = syscall(SYS_pid_resume, pid);
        if (result == -1) {
            perror("pid_resume failed");
            return 1;
        }
        printf("Successfully resumed process %d\n", pid);
    } else if (strcmp(action, "--check") == 0) {
        /*
         * There's no direct API to check if a process is suspended via pid_suspend.
         * We probe by calling pid_resume - if the process is suspended, resume
         * succeeds (returns 0), then we re-suspend it. If not suspended, resume
         * fails with EINVAL.
         */
        result = syscall(SYS_pid_resume, pid);
        if (result == 0) {
            /* Was suspended, re-suspend it */
            syscall(SYS_pid_suspend, pid);
            printf("suspended\n");
        } else {
            /* Not suspended (or error - but most likely EINVAL meaning not suspended) */
            printf("running\n");
        }
        return 0;
    } else {
        fprintf(stderr, "Unknown action: %s (use '--suspend', '--resume', or '--check')\n", action);
        return 1;
    }

    return 0;
}

#pragma clang diagnostic pop
