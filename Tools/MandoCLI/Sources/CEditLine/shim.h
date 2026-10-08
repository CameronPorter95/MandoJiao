// libedit, the line editor macOS ships: readline with arrow keys and history.
#include <stdio.h>
#include <editline/readline.h>

// The newest history entry, or NULL. In C because Swift 6 will not read libedit's globals.
static inline const char *mando_last_history(void) {
    HIST_ENTRY *entry = history_get(history_base + history_length - 1);
    return entry ? entry->line : NULL;
}
