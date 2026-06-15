# Manage SSH keys with Mac OS

## Store a passphrase in the Mac OS Keychain.

In MacOS 12.0 Monterey and newer, enter the following command:

`ssh-add --apple-use-keychain ~/.ssh/[your-private-key-file]`

## Configure `ssh-agent` to always use Keychain (in MacOS Sierra and later).

1. If you haven't already, complete Step 1 above to store the passphrase in the keychain.
2. If you haven't already, create an *~/.ssh/config* file.
   In other words, in the *.ssh* directory in your home dir (*~/*), make a file called *config*.
3. In the *~/.ssh/config* file from the previous step, add the following lines:

 ```sh
 Host *
   UseKeychain yes
   AddKeysToAgent yes
   IdentityFile ~/.ssh/[your-private-key-file]
```

The next time you make an SSH request, SSH will try the private keys specified in *~/.ssh/config*,
and then look for the passphrase in Keychain.

