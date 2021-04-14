/*
 * grcat.c
 *
 * Generate a printable version of the group database.
 */
/*
 * Arnold Robbins, arnold@skeeve.com, May 1993
 * Public Domain
 * December 2010, move to ANSI C definition for main().
 */

#if HAVE_CONFIG_H
#include <config.h>
#endif

#if defined (STDC_HEADERS)
#include <stdlib.h>
#endif

#ifndef HAVE_GETGRENT
int main() { return 0; }
#else
#include <stdio.h>
#include <grp.h>

int
main(int argc, char **argv)
{
    struct group *g;
    int i;

    while ((g = getgrent()) != NULL) {
#ifdef HAVE_STRUCT_GROUP_GR_PASSWD
        printf("%s:%s:%ld:", g->gr_name, g->gr_passwd,
                                     (long) g->gr_gid);
#else
        printf("%s:*:%ld:", g->gr_name, (long) g->gr_gid);
#endif
        for (i = 0; g->gr_mem[i] != NULL; i++) {
            printf("%s", g->gr_mem[i]);
            if (g->gr_mem[i+1] != NULL)
                putchar(',');
        }
        putchar('\n');
    }
    endgrent();
    return 0;
}
#endif /* HAVE_GETGRENT */
