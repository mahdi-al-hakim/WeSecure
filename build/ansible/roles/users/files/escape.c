/*
 * WeSecure .escape: SUID "2FA" gate to root (ORIGINAL author source).
 * Compiled by the users role and installed at /home/root_2fa/.escape (---s--x--x root:root_2fa).
 * Reads the passkey from /etc/.esc-key; correct passkey -> root shell.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Function to read the secret key from /etc/.esc-key
char *read_secret_key(const char *filepath) {
    FILE *file = fopen(filepath, "r");
    if (!file) {
        perror("Error opening secret key file");
        exit(1);
    }

    static char secret_key[256];
    if (fgets(secret_key, sizeof(secret_key), file) == NULL) {
        perror("Error reading secret key");
        fclose(file);
        exit(1);
    }

    // Remove newline character if present
    secret_key[strcspn(secret_key, "\n")] = '\0';
    fclose(file);
    return secret_key;
}

int main(int argc, char *argv[]) {
    // Ensure exactly one argument is given
    if (argc != 2) {
        fprintf(stderr, "Error: This program accepts exactly one argument.\n");
        fprintf(stderr, "Use --help for usage information.\n");
        return 1;
    }

    // Display help if --help is passed
    if (strcmp(argv[1], "--help") == 0) {
        printf("Usage: .escape [escape-passkey]\n");
        return 0;
    }

    // Filepath to the secret key
    const char *key_filepath = "/etc/.esc-key";

    // Read the secret key
    char *secret_key = read_secret_key(key_filepath);

    // Compare the provided key with the secret key
    if (strcmp(argv[1], secret_key) == 0) {
        printf("Key accepted. Entering root...\n");

        // Change directory to /root
        if (chdir("/root") != 0) {
            perror("Failed to change directory to /root");
            return 1;
        }

        // Set the effective and real user ID to root
        if (setuid(0) != 0) {
            perror("Failed to set user ID to root");
            return 1;
        }

        // Execute a root shell
        execl("/bin/bash", "bash", NULL);
        perror("Failed to execute root shell");
        return 1;
    } else {
        fprintf(stderr, "Invalid key. Access denied.\n");
        return 1;
    }
}
