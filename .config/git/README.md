# Q&A
* Is storing the git-crypt-key here publicly is a dumb idea?
  * Yes.
  * But, its convenient as fck. I am sick of copying keys.txt to new machines.

# Usage
* Clone the repo
* Decrypt git-crypt-key to /tmp/git-crypt-key using a passphrase.
* Decrypt the git-crypt files using /tmp/git-crypt-key.
* Delete /tmp/git-crypt-key.


Never decrypt a file inplace. You might accidentally commit it.

## Encrypt a File
read -sp "Enter passphrase: " password && echo && (head -c8 ./git-crypt-key | grep -q '^Salted__' && { echo "File appears already encrypted."; exit 1; } || (openssl enc -aes-256-cbc -pbkdf2 -salt -in ./git-crypt-key -out ./git-crypt-key.tmp -pass pass:"$password" && mv ./git-crypt-key.tmp ./git-crypt-key && echo "Encryption complete.")) && unset password

## Decrypt a File
read -sp "Enter passphrase: " password && echo && (head -c8 ./git-crypt-key | grep -q '^Salted__' || { echo "File does not appear encrypted."; exit 1; }) && (openssl enc -d -aes-256-cbc -pbkdf2 -in ./git-crypt-key -out ./git-crypt-key.tmp -pass pass:"$password" && mv ./git-crypt-key.tmp ./git-crypt-key && echo "Decryption complete.") && unset password

