# SSH public key registry data — declares all keys for ncrmro and agents.
#
# This file only contains key DATA. The keystone.keys option definition
# comes from inputs.keystone.nixosModules.keys (imported in modules/keystone/os.nix).
#
# Import this file on any host that needs access to SSH public keys.
# Full keystone hosts get this via modules/keystone/os.nix; legacy hosts
# import it directly.
{ ... }:
{
  keystone.keys = {
    ncrmro = {
      hosts = {
        ncrmro-laptop-fw7k = {
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOyrDBVcGK+pUZOTUA7MLoD5vYK/kaPF6TNNyoDmwNl2 ncrmro@ncrmro-laptop-fw7k";
        };
        ncrmro-workstation = {
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGiFUbcDdzBGNgo7GdRvuRvZ9Yf195pIm2jbiM0uJwW0 ncrmro@ncrmro-workstation";
        };
        ocean = {
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEE6cFSyJoiaURB7+961zETflBNPJUZszH9xyowzbpNu ncrmro@ocean";
        };
        iphone-14-pro = {
          publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAGBpgX+4rqqVdHNnLWFXPOyVMf3Cp00VbUCLyR6tP15qHWTO9OKyjRbHIxmwFfw2hkfzCKD9MtN8vheH2NWWzg= ncrmro@iphone-14-pro";
        };
        ncrmro-laptop = {
          publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCUAyM7/owpfpJPuzQMmkmnlAcqB91QIfVsj1TueIU3hUtoHGR6FcKfFgJA5gkhww10A91M6iPSHD2kd/BNBGD4= ncrmro@ncrmro-laptop";
        };
      };
      hardwareKeys = {
        yubi-black = {
          description = "Primary YubiKey 5 NFC (USB-A, black)";
          publicKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAILEOo3uKwbDN1SJemQx8UPVXv0TjKn2VfZSTVFfp3tlcAAAACnNzaDpuY3Jtcm8=";
          handleSource = ../hardware-keys/yubi-black;
          handlePubSource = ../hardware-keys/yubi-black.pub;
        };
        yubi-green = {
          description = "Backup YubiKey 5C NFC (USB-C, green sticker)";
          publicKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDtwsz3zAJokZ3rnVyXUxmeUGba61b8KIW3u4aE52dK2AAAAFXNzaDpuY3Jtcm8teXViaS1ncmVlbg==";
          handleSource = ../hardware-keys/yubi-green;
          handlePubSource = ../hardware-keys/yubi-green.pub;
        };
      };
    };

    # Agent keys — one host key each, no hardware keys
    agent-drago = {
      hosts = {
        ncrmro-workstation = {
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID9TbHc93b0RWSekJcUmlDkw0UulfzkbJqdd0ejfuV2C agent-drago";
        };
      };
    };
    agent-luce = {
      hosts = {
        ocean = {
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIm+ClDj0CiLcYO3rxsQgRx7P0v3/bSw1QuCNdk87btp agent-luce";
        };
      };
    };
  };
}
