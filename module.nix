{ lib, ... }:
{
  options =
    let
      inherit (lib)
        stringLength
        mkOption
        mkEnableOption
        mkOptionType
        ;
      inherit (lib.types)
        attrsOf
        either
        path
        submodule
        passwdEntry
        nullOr
        str
        int
        listOf
        enum
        strMatching
        ;
      inherit (lib.options)
        mergeUniqueOption
        ;
      nullOrOpt =
        { type, ... }@args:
        mkOption (
          {
            type = nullOr type;
            default = null;
          }
          // args
        );
      nullOrPath =
        description:
        nullOrOpt {
          inherit description;
        };

      bandwithOpt =
        description:
        nullOrOpt {
          type = strMatching "[[:digit:]]*(k|M|G|T)?";

          inherit description;
        };
      userGroupType =
        what: message:
        mkOptionType {
          name = "userGroupType";
          description = "either a user or group name";
          check =
            x:
            stringLength x < 32
            || abort "${what} '${x}' is longer than 31 characters which is not allowed!\n${message}";
          #typeMerge = null;
          merge = mergeUniqueOption {
            inherit message;
            merge = str.merge;
          };

        };
      permissions =
        description:
        nullOrOpt {
          inherit description;
          type = either int str; # FIXME should add regex here
          default = 4;
        };
    in
    {
      #putting this here is most likely to not cause any collisions
      bindfs = {
        enable = mkEnableOption "wether to enable bindfs.nix";
        fs = mkOption {
          type = attrsOf (
            submodule (
              { ... }:
              {
                options = {
                  ensureExists =
                    let
                      mkOptDir = mkEnableOption "add activation Script that ensures dir exists";
                    in
                    {
                      target = mkOptDir;
                      source = mkOptDir;
                    };
                  source = mkOption {
                    type = path;
                  };
                  map = {
                    userGroup = mkOption {
                      type = attrsOf (passwdEntry str);
                      default = { };
                      description = ''
                        Given  a  mapping user1/user2, all files owned by user1 are shown as owned by user2. When user2 creates files, they are chowned to user1 in the underlying  directory.
                        When  files are  chowned to user2, they are chowned to user1 in the underlying directory. Works simi‐ larly for groups. A single user or group may appear no more than once on the left and once on the right  of a  slash  in  the  list of mappings.
                        Currently, the options --force-user, --force-group, --mirror, --create-for-*, --chown-* and --chgrp-* override the corresponding behavior  of this option.
                        Requires mounting as root.
                      '';
                      apply =
                        #FIXME edge case: group name is exactly 31 chars -> additional @ stretches it to 32
                        v:
                        map (
                          x:
                          assert (
                            stringLength x < 32
                            || abort "Username / Groupname '${x}' is longer than 31 characters which is not allowed!"
                          );
                          x
                        ) v;
                    };
                    passwdFile = nullOrPath ''
                      Like  --map=...,  but  reads  the  UID  (GID)  mapping  from  passwd  (group)  file (like /etc/passwd and /etc/group).
                      Maps UID (GID) provided in the <passwdfile> (<groupfile>) to its corresponding user (group) name.
                      Helpful to restore system backups  where  UIDs  and GIDs differ.

                      Example usage:

                          bindfs --map-passwd=/mnt/orig/etc/passwd \
                              --map-group=/mnt/orig/etc/group \
                              /mnt/orig /mnt/mapped

                      Requires mounting as root.
                    '';
                    groupFile = nullOrPath ''
                      Like  --map=...,  but  reads  the  UID  (GID)  mapping  from  passwd  (group)  file (like /etc/passwd and /etc/group).
                      Maps UID (GID) provided in the <passwdfile> (<groupfile>) to its corresponding user (group) name.
                      Helpful to restore system backups  where  UIDs  and GIDs differ.

                      Example usage:

                          bindfs --map-passwd=/mnt/orig/etc/passwd \
                              --map-group=/mnt/orig/etc/group \
                              /mnt/orig /mnt/mapped

                      Requires mounting as root.
                    '';
                    passwFileRev = nullOrPath ''
                      Reversed variant of --map-passwd and --map-group. Like --map=..., but reads the UID (GID) mapping  from  passwd  (group) files (like /etc/passwd and /etc/group).
                      Maps user (group) name provided in the <passwdfile> (<groupfile>) to its corresponding UID (GID).
                      Helpful to create compatible chroot environments where UIDs and GIDs differ.

                      Example usage:

                          bindfs --map-passwd-rev=/mnt/mapped/etc/passwd \
                              --map-group-rev=/mnt/mapped/etc/group \
                              /mnt/orig /mnt/mapped

                      Requires mounting as root.
                    '';
                    groupFileRev = nullOrPath ''
                      Reversed variant of --map-passwd and --map-group. Like --map=..., but reads the UID (GID) mapping  from  passwd  (group) files (like /etc/passwd and /etc/group).
                      Maps user (group) name provided in the <passwdfile> (<groupfile>) to its corresponding UID (GID).
                      Helpful to create compatible chroot environments where UIDs and GIDs differ.

                      Example usage:

                          bindfs --map-passwd-rev=/mnt/mapped/etc/passwd \
                              --map-group-rev=/mnt/mapped/etc/group \
                              /mnt/orig /mnt/mapped

                      Requires mounting as root.
                    '';

                    uid-offset = nullOrOpt {
                      type = int;
                      description = ''
                        Works  like  --map,  but adds the given number to all file owner user IDs. For instance, --uid-offset=100000 causes a file owned by user 123 to be shown as owned by user 100123.
                                              For now, this option cannot be used together with --map. Please file an  issue  with  the desired semantics if you have a case for using them together.

                        Requires mounting as root.
                      '';
                    };
                    gid-offset = nullOrOpt {
                      type = int;
                      description = "Works exactly like --uid-offset but for groups.";
                    };

                  };
                  fileCreationPolicy = {
                    as-user = mkEnableOption ''
                      Tries to change the owner and group of new files and directories to the uid  and  gid  of the  caller.
                      This can work only if the mounter is root.  It is also the default behavior (mimicking mount --bind) if the mounter is root.
                    '';
                    as-mounter = mkEnableOption ''
                      All new files and directories will be owned by the mounter.  This is the default behavior for non-root mounters.
                    '';
                    for-user = nullOrOpt {
                      type = userGroupType "user" "";
                      description = ''
                        Tries to change the owner of new files and directories to the user specified here.
                        This can  work  only  if  the mounter is root.  This option overrides the --create-as-user and --create-as-mounter options.
                      '';
                    };
                    for-group = nullOrOpt {
                      type = userGroupType "group" "";
                      description = ''
                                Tries to change the owning group of new files and  directories  to  the  group  specified
                        here.   This  can  work  only  if  the mounter is root.  This option overrides the --cre‐
                        ate-as-user and --create-as-mounter options.'';
                    };
                    with-perms = permissions ''
                      Works like --perms but is applied to the permission bits of new files get in  the  source directory. Normally the permissions of new files depend on the creating process's preferences and umask.
                      This option can be used to modify those permissions or override  them completely.
                      See PERMISSION SPECIFICATION below for details.
                    '';
                  };
                  force = {
                    user = nullOrOpt {
                      type = userGroupType "user" "";
                      description = ''Makes all files owned by the specified user.  Also causes chown on the mounted filesystem to always fail. '';
                    };

                    group = nullOrOpt {
                      type = userGroupType "group" "";
                      description = ''Makes all files owned by the specified group.  Also causes chgrp on the mounted  filesystem to always fail.'';
                    };
                  };
                  perms = permissions ''
                    Takes  a comma- or colon-separated list of chmod-like permission specifications to be ap‐ plied to the permission bits in order.
                    See PERMISSION SPECIFICATION below for details. This only affects how the permission bits of existing files are altered when shown in the mounted directory.
                    You can use --create-with-perms to change the permissions  that  newly created files get in the source directory.
                    Note  that, as usual, the root user isn't bound by the permissions set here.
                    You can get a truly read-only mount by using -r.'';

                  mirror = {
                    only = mkEnableOption ''
                      Like --mirror but disallows access for all other users (except root).
                    '';
                    usersGroups = mkOption {
                      type = listOf userGroupType "user / group" "";
                      default = [ ];
                      description = ''
                        Takes a comma- or colon-separated list of users who will see themselves as the owners  of all  files.
                        Users  who are not listed here will still be able to access the mount if the permissions otherwise allow them to.
                        You can also give a group name prefixed with an '@' to mirror all  members  of  a  group.
                        This will not change which group the files are shown to have.
                      '';
                    };
                  };
                  policies = {
                    chown = nullOrOpt {
                      type = enum [
                        "normal"
                        "ignore"
                        "deny"
                      ];
                      description = ''
                        The  behaviour  on  chown/chgrp  calls can be changed. By default they are passed through to the source directory even if bindfs is set to show a fake owner/group.
                        A chown/chgrp call will  only succeed  if  the user has enough mirrored permissions to chmod the mirrored file AND the mounter has enough permissions to chmod the real file.

                        --chown-normal, -o chown-normal Tries to chown the underlying file. This is the default.

                        --chown-ignore, -o chown-ignore Lets chown succeed (if the user has enough mirrored permissions) but actually does  nothing. A combined chown/chgrp is effectively turned into a chgrp-only request.

                        --chown-deny, -o chown-deny Makes chown always fail with a 'permission denied' error.  A combined chown/chgrp request will fail as well.
                      '';
                    };
                    chgrp = nullOrOpt {
                      type = enum [
                        "normal"
                        "ignore"
                        "deny"
                      ];
                      description = ''
                        The  behaviour  on  chown/chgrp  calls can be changed. By default they are passed through to the source directory even if bindfs is set to show a fake owner/group.
                        A chown/chgrp call will  only succeed  if  the user has enough mirrored permissions to chmod the mirrored file AND the mounter has enough permissions to chmod the real file.

                        --chgrp-normal, -o chgrp-normal Tries to chgrp the underlying file. This is the default.

                        --chgrp-ignore, -o chgrp-ignore Lets  chgrp succeed (if the user has enough mirrored permissions) but actually does nothing. A combined chown/chgrp is effectively turned into a chown-only request.

                        --chgrp-deny, -o chgrp-deny Makes chgrp always fail with a 'permission denied' error.  A combined chown/chgrp request will fail as well.
                      '';
                    };
                    chmod = nullOrOpt {
                      type =
                        either
                          (enum [
                            "normal"
                            "ignore"
                            "deny"
                            "allow-x"
                            "ignore-allow-x"
                            "deny-allow-x"
                          ])
                          (
                            submodule (
                              { ... }:
                              {
                                options = {
                                  filter = permissions ''
                                    Changes the permission bits of a chmod request before it is applied to the original file.
                                    Accepts the same permission syntax as --perms.  See PERMISSION  SPECIFICATION  below  for details.
                                  '';
                                };
                              }
                            )
                          );
                      description = ''
                        Chmod calls are forwarded to the source directory by default.
                        This may cause unexpected  behavour if bindfs is altering permission bits.

                        --chmod-normal, -o chmod-normal Tries  to  chmod  the  underlying file. This will succeed if the user has the appropriate mirrored permissions to chmod the mirrored file AND the mounter has enough permissions to chmod the real file.  This is the default (in order to behave like mount  --bind  by  default).

                        --chmod-ignore, -o chmod-ignore Lets  chmod succeed (if the user has enough mirrored permissions) but actually does nothing. --chmod-deny, -o chmod-deny Makes chmod always fail with a 'permission denied' error.

                        --chmod-filter=permissions, -o chmod-filter=... Changes the permission bits of a chmod request before it is applied to the original file. Accepts the same permission syntax as --perms.  See PERMISSION  SPECIFICATION  below  for details.

                        --chmod-allow-x, -o chmod-allow-x Allows setting and clearing the executable attribute on files (but not directories). When used  with  --chmod-ignore,  chmods will only affect execute bits on files and changes to other bits are discarded.  With --chmod-deny, all chmods that would change any  bits  except  execute bits on files will still fail with a 'permission denied'.
                        This option does nothing with --chmod-normal.
                      '';
                    };
                    xattr = nullOrOpt {
                      type = enum [
                        "none"
                        "ro"
                        "rw"
                      ];
                      description = ''
                        Extended attributes are mirrored by default, though not all underlying file systems support xattrs.

                        --xattr-none, -o xattr-none Disable extended attributes altogether. All operations will return  'Operation  not  supported'.

                        --xattr-ro, -o xattr-ro Let extended attributes be read-only.

                        --xattr-rw, -o xattr-rw Let  extended  attributes  be  read-write  (the default).  The read/write permissions are checked against the (possibly modified) file permissions inside the mount.
                      '';
                    };
                  };
                  denyFileOp = {
                    delete = mkEnableOption ''
                      Makes all file delete operations fail with a 'permission denied'.
                      By default, files  can still  be  modified if they have write permission, and renamed if the directory has write permission. '';
                    rename = mkEnableOption ''
                      Makes all file rename/move operations within the mountpoint fail with a  'permission  denied'.
                      Programs  that  move  files out of a mountpoint do so by copying and deleting the original.
                    '';
                  };

                  rateLimits = mkOption {
                    type = submodule (
                      { ... }:
                      {
                        options = {
                          read = bandwithOpt ''
                            Allow at most N bytes per second to be read. N may have one of the following (1024-based)
                            suffixes: k, M, G, T.'';
                          write = bandwithOpt ''
                            Allow at most N bytes per second to be written. N may have one of the following (1024-based)
                            suffixes: k, M, G, T.'';
                        };
                      }
                    );
                    description = ''
                      Reads and writes through the mount point can be throttled. Throttling works by sleeping the  required amount of time on each read or write request.
                      Throttling imposes one global limit on all readers/writers as opposed to a per-process or per-user limit.

                      Currently, the implementation is not entirely fair. See BUGS below.
                    '';
                  };
                  linkHandling = {
                    hide-hard-links = mkEnableOption "Shows the hard link count of all files as 1.";
                    resolve-symlinks = {
                      enable = mkEnableOption ''
                        Transparently resolves symbolic links.  Disables creation of new symbolic links.

                        With  the  following  exceptions, operations will operate directly on the target file instead of the symlink. Renaming/moving a resolved symlink (inside the  same  mount  point) will  move  the  symlink instead of the underlying file. Deleting a resolved symlink will delete the underlying symlink but not the destination file. This can be  configured  with --resolved-symlink-deletion.

                        Note  that  when  some programs, such as vim, save files, they actually move the old file out of the way, create a new file in its place, and finally delete the  old  file.  Doing these operations on a resolved symlink will replace it with a regular file.

                        Symlinks  pointing  outside  the source directory are supported with the following exception: accessing the mountpoint recursively through a resolved symlink  is  not  supported and  will  return an error. This is because a FUSE filesystem cannot reliably call itself recursively without deadlocking, especially in single-threaded mode.
                      '';
                    };
                    resolved-symlink-deletion = nullOrOpt {
                      type = enum [
                        "deny"
                        "symlink-only"
                        "symlink-first"
                        "target-first"
                      ];
                      description = ''
                        If --resolve-symlinks is enabled,  decides  what  happens  when  a  resolved  symlink  is deleted.   The options are: deny (resolved symlinks cannot be deleted), symlink-only (the underlying symlink is deleted, its target is not), symlink-first (the symlink is deleted, and if that succeeds, the target is deleted but no error is reported if  that  fails)  or target-first  (the  target  is deleted first, and the symlink is deleted only if deleting the target succeeded).  The default is symlink-only.
                        Note that deleting files inside symlinked directories is always possible  with  all  settings, including deny, unless something else protects those files. '';
                    };
                  };
                  no-allow-other = mkEnableOption ''
                    Does not add -o allow_other to FUSE options.
                    This causes the mount to be accessible only by the current user.
                    (The deprecated shorthand -n is also still accepted.)
                  '';
                  realistic-permissions = mkEnableOption ''
                    Hides read/write/execute permissions for a mirrored file when the  mounter  doesn't  have read/write/execute  access  to the underlying file.  Useless when mounting as root, since root will always have full access.
                    (Prior to version 1.10 this option was the default behavior.  I  felt  it  violated  the principle  of  least surprise badly enough to warrant a small break in backwards-compati‐ bility.)
                  '';
                  ctime-from-mtime = mkEnableOption ''
                    Recall that a unix file has three standard  timestamps:  atime  (last  access  i.e.  read time),  mtime  (last  content  modification time) ctime (last content or metadata (inode) change time)

                    With this option, the ctime of each file and directory is read from its mtime.  In  other words, only content modifications (as opposed to metadata changes) will be reflected in a mirrored file's ctime.  The underlying file's ctime will still be updated normally.
                  '';
                  multithreaded = {
                    enable = mkEnableOption ''
                      Run  bindfs  in multithreaded mode. While bindfs is designed to be otherwise thread-safe, there is currently a race condition that may pose a security risk for some use cases. See BUGS below.
                    '';
                    lock-forwarding = mkEnableOption ''
                      Forwards  flock  and fcntl locking requests to the source directory.  This way, locking a file in the bindfs mount will also lock the file in the source directory.

                      This option must be used with --multithreaded because otherwise bindfs will  deadlock  as soon  as  there  is  lock  contention. However, see BUGS below for caveats about --multithreaded with the current implementation.
                    '';
                  };
                  enable-ioctl = mkEnableOption ''
                    Enables  forwarding  of ioctl, which is needed for some advanced features such as appendonly files (chattr +a). Note that the ioctl action will be performed as the mounter,  not the  calling user. No efforts are made to check whether the calling user would ordinarily have the permissions to make the ioctl. This may be a security concern,  especially  when mounting as root.
                  '';
                  block-devices-as-files = mkEnableOption ''
                    Shows block devices as regular files.
                  '';
                  direct-io = mkEnableOption ''
                    Forwards each read/write operation 1:1 to  the  underlying  FS,  disabling  batching  and caching by the kernel. Some applications may require this, however it may be incompatible with other applications, as currently it has issues with mmap(2) calls, at least.
                  '';
                  forward-odirect = nullOrOpt {
                    type = str;
                    description = ''
                      Enable  experimental  O_DIRECT  forwarding,  with  all read/write requests rounded to the given alignment (in bytes). By default, the O_DIRECT flag is not forwarded to the  under‐ lying FS.  See open(2) for details about O_DIRECT.
                      Only works on Linux. Ignored on other platforms.
                    '';
                  };
                  read-only = mkEnableOption ''
                    Make  the mount strictly read-only.  This even prevents root from writing to it.  If this is all you need, then (since Linux 2.6.26) you can get a more efficient mount with  mount --bind and then mount -o remount,ro.
                  '';
                  fsname = nullOrOpt {
                    type = str;
                    description = ''
                      Sets  the  source  directory name in /proc/mounts (returned by mount).  This is automatically set as long as the source path has no special characters.
                    '';
                  };
                };
              }
            )
          );
        };
      };
    };

  #system.activationScripts.ensure-syncthing-dir-ownership.text = lib.mkForce "";
}
