{ ... }:
{
  networking.hostName = "pcA";
  boot.isContainer = true; # Hack to have an easy time building

  bindfs = {
    enable = true;
    folders = {
      "/tmp/bindfs/target_mount_1" = {
        ensureExists = {
          target = true;
          source = true;
        };
        source = "/tmp/bindfs/source";
        map = {
          userGroup = {
            "sourceuser" = "targetuser";
            "@sourcegroup" = "@targetgroup";
          };
          passwdFile = null;
          groupFile = null;
          passwdFileRev = null;
          groupFileRev = null;
          uid-offset = null;
          gid-offset = null;
        };
        fileCreationPolicy = {
          as-user = false;
          as-mounter = false;
          for-user = "username";
          for-group = "groupname";
          with-perms = null;
        };
        force = {
          user = null; # user
          group = null; # group
        };
        perms = null; # permisssion spec

        mirror = {
          only = true;
          usersGroups = [
            "targetuser"
            "@targetgroup"
          ];
        };

        policies = {
          chown = "normal";
          chgrp = "normal";
          #chmod = "normal";
          chmod.filter = "";
          xattr = "rw";
        };
        denyFileOp = {
          delete = false;
          rename = false;
        };
        rateLimits = {
          read = "";
          write = "";
        };
        linkHandling = {
          hide-hard-links = false;
          resolve-symlinks = {
            enable = false;
            resolved-symlink-deletion = "symlink-first";
          };
        };
        no-allow-other = true;
        realistic-permissions = false;
        ctime-from-mtime = false;
        multithreaded = {
          enable = false;
          lock-forwarding = false;
        };

        enable-ioctl = false;
        block-devices-as-files = false;
        direct-io = false;
        forward-odirect = null; # alignment
        read-only = false;

        fsname = null; # string

      };
      "/tmp/bindfs/target_mount_2" = {
        ensureExists = {
          target = true;
          source = true;
        };
        source = "/tmp/bindfs/source2";
      };
    };
  };
}
