# WeSecure: Attack chain

> Full spoilers. This maps the intended path end to end. Read it after your own attempt, or alongside the [walkthrough](WeSecure-walkthrough.md).

Each edge is the control or oversight that turns one step into the next. The two labelled edges in privilege escalation are the box's anchor ideas: a checksum is not an integrity control, and a confused deputy leaks the last secret.

```mermaid
flowchart TD
    subgraph recon [Recon]
        N["nmap -p-"] --> FTP["FTP · anonymous"]
        N --> WEB["HTTP · wesecure.vh"]
        FTP -->|"temp-password file left on the server"| CRED["temporary passwords"]
        WEB -->|"PDF metadata leaks a hidden path"| DIR["work-in-progress web dir"]
        DIR -->|"passkey-guarded steganography"| WHO["username discovered"]
    end
    subgraph foothold [Foothold]
        CRED --> S1["SSH as mmcarTney+0"]
        WHO --> S1
        S1 -->|"SSH key fragmented across a readable log"| KEY["reassemble + crack key"]
        KEY --> USER["SSH as john · user.txt"]
    end
    subgraph privesc [Privilege escalation]
        USER -->|"ACL write on a cron-trusted binary"| G["hijack grep"]
        G -->|"CRC32 forged: a checksum is not an integrity control"| R2["shell as root_2fa"]
        R2 -->|"SUID reader + web-writable dir = confused deputy"| LEAK["leak the 2FA passkey over HTTP"]
        LEAK --> ROOT[".escape passkey · root · root.txt"]
    end
```
