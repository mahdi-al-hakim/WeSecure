# build/: reproducible build automation

Infrastructure-as-code that builds **WeSecure** from scratch: **Packer** creates a clean Ubuntu 24.04 image via unattended autoinstall, **Ansible** injects every vulnerability, and the box is exported as an ISO-free OVA. **Vagrant** gives a fast local iteration loop.

> Each Ansible role maps to one stage of the intended exploit chain; see [`../writeup/WeSecure-walkthrough.md`](../writeup/WeSecure-walkthrough.md).

## Layout
```
packer/
  wesecure.pkr.hcl          # VMware build: ISO -> autoinstall -> Ansible -> OVA
  http/{user-data,meta-data}# Ubuntu 24.04 autoinstall seed
  build.pkrvars.hcl.example
ansible/
  site.yml                  # main playbook (roles in dependency order)
  requirements.yml          # community.general + ansible.posix
  group_vars/all.yml        # non-secret config
  secrets.example.yml       # copy -> secrets.yml, fill in (git-ignored)
  roles/
    base/     packages, hostname, ufw (80/2222/61676), sshd on 2222, ship-clean cleanup
    users/    john / mmcarTney+0 / root_2fa, passwords, root->root_2fa 2FA gate, .escape (compiled)
    web/      apache vhost wesecure.vh, site, PDF metadata leak, .part01 stego image
    ftp/      vsftpd :61676 anon (active-mode only), temporary_pass.txt
    foothold/ john keypair -> fragmented into /var/log/.activity.trace
    privesc/  grep ACL, verified_run/monitor/setup_checksums, cron, checksum store
    flags/    user.txt / root.txt
Vagrantfile                 # local build/test loop
```

## Prerequisites
- Packer, Ansible, VMware Workstation + `ovftool` (or VirtualBox, swapping the Packer source).
- `ansible-galaxy collection install -r ansible/requirements.yml`

## 1. Configure secrets
```bash
cp ansible/secrets.example.yml ansible/secrets.yml
$EDITOR ansible/secrets.yml            # set passwords, passkey, and 32-hex flags
ansible-vault encrypt ansible/secrets.yml   # recommended
```
Keep `stego_passphrase` (`a5dam.`) and `john_key_passphrase` (`142536`) crackable (both are in rockyou) if you want the documented path to hold.

**`.escape` source:** the build compiles `ansible/roles/users/files/escape.c` (the SUID-root gate).

## 2a. Full build (Packer -> OVA)
```bash
cd packer
packer init .
packer validate -var-file=build.pkrvars.hcl.example .
packer build   -var-file=build.pkrvars.hcl.example .
# -> WeSecure.ova (ISO-free, compressed, DHCP)
```

## 2b. Fast local iteration (Vagrant)
```bash
cd build
vagrant up            # build on a stock ubuntu-24.04 base box
vagrant provision     # re-apply after editing a role
```

## 3. Verify
Boot the result and work through the writeup end to end: FTP credentials, PDF metadata, steganography, SSH-key reassembly, the user flag, the CRC-forge cron job, `.escape`, and root.

## Notes
Cosmetic assets (the site HTML, the Terms PDF, and the stego *cover* image) are generated at build time rather than shipped as binaries, so the repo stays text-only and the build is the single source of truth for the machine.
