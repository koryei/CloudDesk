# Contributing

Thanks for your interest in improving CloudDesk.

## How to contribute

1. Fork the repo
2. Create a branch: `git checkout -b fix/your-fix-name`
3. Make your changes
4. Test CloudDesk on a fresh Ubuntu 22.04+ x86_64 VPS before submitting
5. Open a pull request with a clear description of what changed and why

## Before submitting

- Run `bash -n clouddesk.sh` to validate syntax
- Test the full install end-to-end on a clean machine
- Do not commit tokens, keys, or `.pem` files

## Reporting bugs

Open an issue and include:
- Your Ubuntu version (`lsb_release -a`)
- The error output
- Contents of `/var/log/clouddesk.log`
