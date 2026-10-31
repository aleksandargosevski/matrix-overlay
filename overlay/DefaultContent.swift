import Foundation

enum DefaultContent {
    static let config = #"""
# matrix-overlay config
# Changes are picked up automatically, no restart needed.

animation = "random"      # "rain" | "typer" | "random"
idle_seconds = 60         # idle trigger delay (used by the launchd agent)
media_check = true        # skip idle trigger while video/calls are active
color = "#00ff41"         # main color (hex)
opacity = 0.92            # background darkness for rain (0 = transparent, 1 = black)
fps = 30

[rain]
font_size = 16

[typer]
font = ""                 # empty = SF Mono; e.g. "JetBrainsMono Nerd Font", "Menlo"
font_size = 18
text_file = "~/.config/matrix-overlay/typer.txt"   # snippets separated by a line with ---
chars_per_second = 14
typo_rate = 0.02          # 0 = perfect typist
loop = true               # move to the next snippet when done
opacity = 1.0
"""#

    static let snippets: [String] = [
        #"""
$ ssh root@10.13.37.1
Last login: Thu Oct 31 03:14:15 from 192.168.0.42
root@vault:~# vim detonate.c

#include <stdio.h>
#include "payload.h"

// countdown sequence, do NOT touch the red wire
static const int T_MINUS = 10;

int arm_device(device_t *dev, const char *code) {
    if (!verify_checksum(code)) {
        log_warn("invalid launch code: %s", code);
        return -EACCES;
    }
    dev->state = ARMED;
    dev->wire[RED]  = LIVE;
    dev->wire[BLUE] = DECOY;
    return 0;
}

int main(void) {
    device_t *bomb = device_open("/dev/payload0");
    if (arm_device(bomb, getenv("LAUNCH_CODE")) != 0)
        return 1;

    for (int t = T_MINUS; t > 0; t--) {
        printf("T-%02d ... \n", t);
        sleep(1);
    }

    // point of no return
    detonate(bomb, YIELD_MAX);
    printf("BOOM.\n");
    return 0;
}
"""#,
        #"""
$ ./breach --target mainframe.corp --port 443
[*] resolving mainframe.corp ... 203.0.113.7
[*] fingerprinting TLS stack ... OpenSSL 1.0.1f
[+] heartbleed: VULNERABLE
[*] leaking memory ... 64KB ... 128KB ... 512KB
[+] session key found: 9f86d081884c7d659a2feaa0c55ad015
[*] injecting shell ...

# escalate
sudo -l
sudo /usr/bin/find . -exec /bin/sh \; -quit
whoami
root

# cover tracks
shred -u /var/log/auth.log
history -c && exit

[+] access granted. welcome back, neo.
"""#,
        #"""
-- wake up, neo...
-- the matrix has you...
-- follow the white rabbit.

knock, knock, neo.
"""#,
    ]
}
