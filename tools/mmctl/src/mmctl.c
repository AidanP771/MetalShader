/*
 * mmctl.c - Command-line client for MetalMix's dev control socket.
 *
 * Purpose: send one command to a running MetalMix core (Dev builds only) and
 * print the reply. Usually run on the test Mac over SSH:
 *
 *   ssh test-mac mmctl status
 *
 * Protocol (see core/src/control/README.md): send one line, read lines until the
 * server closes the connection. The first reply line is "ok" or "error: ...".
 *
 * Exit codes: 0 reply was ok, 1 reply was an error, 2 usage problem,
 * 3 could not reach MetalMix.
 */

#include "metalmix/mm_api.h"

#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

enum {
    kExitOk = 0,
    kExitServerError = 1,
    kExitUsage = 2,
    kExitUnreachable = 3,
    kMaxRequestBytes = 4096,
};

static void print_usage(void) {
    fputs("Usage: mmctl [--socket PATH] <command> [arguments...]\n"
          "\n"
          "Sends one command to a running MetalMix core (Dev builds only).\n"
          "Common commands: status, reload [effect], enable <effect>, disable <effect>,\n"
          "set <effect>.<param> <value>, screenshot, dump-passes [frames], capture.\n"
          "See tools/mmctl/README.md for the full list.\n",
          stderr);
}

/* Default socket: ~/Library/Application Support/MetalMix/ctl.sock */
static bool default_socket_path(char *out, size_t out_size) {
    const char *home = getenv("HOME");
    if (home == NULL) {
        return false;
    }
    int written = snprintf(out, out_size, "%s/Library/Application Support/%s/ctl.sock", home,
                           MM_SUPPORT_FOLDER_NAME);
    return written > 0 && (size_t)written < out_size;
}

/* Joins argv[first..argc) with single spaces and a trailing newline. */
static bool build_request(int argc, char **argv, int first, char *out, size_t out_size) {
    size_t used = 0;
    for (int i = first; i < argc; i++) {
        int written = snprintf(out + used, out_size - used, "%s%s", i > first ? " " : "", argv[i]);
        if (written < 0 || (size_t)written >= out_size - used) {
            return false;
        }
        used += (size_t)written;
    }
    if (used + 2 > out_size) {
        return false;
    }
    out[used++] = '\n';
    out[used] = '\0';
    return true;
}

int main(int argc, char **argv) {
    struct sockaddr_un address = {.sun_family = AF_UNIX};
    int first_command_arg = 1;

    if (argc >= 3 && strcmp(argv[1], "--socket") == 0) {
        if (strlen(argv[2]) >= sizeof address.sun_path) {
            fprintf(stderr, "mmctl: socket path is too long (max %zu characters).\n",
                    sizeof address.sun_path - 1);
            return kExitUsage;
        }
        strcpy(address.sun_path, argv[2]);
        first_command_arg = 3;
    } else if (!default_socket_path(address.sun_path, sizeof address.sun_path)) {
        fputs("mmctl: could not work out the socket path. Use --socket PATH.\n", stderr);
        return kExitUsage;
    }

    if (first_command_arg >= argc || strcmp(argv[first_command_arg], "--help") == 0 ||
        strcmp(argv[first_command_arg], "-h") == 0) {
        print_usage();
        return kExitUsage;
    }

    char request[kMaxRequestBytes];
    if (!build_request(argc, argv, first_command_arg, request, sizeof request)) {
        fputs("mmctl: command is too long.\n", stderr);
        return kExitUsage;
    }

    int connection = socket(AF_UNIX, SOCK_STREAM, 0);
    if (connection < 0) {
        fprintf(stderr, "mmctl: could not create a socket: %s\n", strerror(errno));
        return kExitUnreachable;
    }
    if (connect(connection, (const struct sockaddr *)&address, sizeof address) != 0) {
        fprintf(stderr,
                "mmctl: could not connect to %s: %s\n"
                "Is the game (or test host) running with a Dev build of MetalMix?\n",
                address.sun_path, strerror(errno));
        close(connection);
        return kExitUnreachable;
    }

    size_t request_length = strlen(request);
    if (write(connection, request, request_length) != (ssize_t)request_length) {
        fprintf(stderr, "mmctl: could not send the command: %s\n", strerror(errno));
        close(connection);
        return kExitUnreachable;
    }
    shutdown(connection, SHUT_WR); /* Tell the server the request is complete. */

    /* Print the reply as it arrives, remembering whether it started with "ok". */
    char buffer[4096];
    char first_bytes[3] = {0};
    size_t first_bytes_seen = 0;
    ssize_t received = 0;
    while ((received = read(connection, buffer, sizeof buffer)) > 0) {
        for (ssize_t i = 0; i < received && first_bytes_seen < 2; i++) {
            first_bytes[first_bytes_seen++] = buffer[i];
        }
        fwrite(buffer, 1, (size_t)received, stdout);
    }
    close(connection);

    if (received < 0) {
        fprintf(stderr, "mmctl: connection dropped: %s\n", strerror(errno));
        return kExitUnreachable;
    }
    return strcmp(first_bytes, "ok") == 0 ? kExitOk : kExitServerError;
}
