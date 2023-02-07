let
  compression."in"          = "path";
  compression.description   = "The compression algorithm listed in the NarInfo object";
  compression.example       = "xz";
  compression.name          = "compression";
  compression.required      = true;
  compression.schema.enum   = ["xz" "bz2" "zst" "lzip" "lz4" "br"];
  compression.schema.type   = "string";
  deriver."in"              = "path";
  deriver.description       = "The full name of the deriver";
  deriver.example           = "bidkcs01mww363s4s7akdhbl6ws66b0z-ruby-2.7.3.drv";
  deriver.name              = "deriver";
  deriver.required          = true;
  deriver.schema.type       = "string";
  fileHash."in"             = "path";
  fileHash.description      = "The base32 cryptographic hash of the NAR.";
  fileHash.example          = "1w1fff338fvdw53sqgamddn1b2xgds473pv6y13gizdbqjv4i5p3";
  fileHash.name             = "fileHash";
  fileHash.required         = true;
  fileHash.schema.type      = "string";
  storePathHash."in"        = "path";
  storePathHash.description = "cryptographic hash of the store path";
  storePathHash.example     = "p4pclmv1gyja5kzc26npqpia1qqxrf0l";
  storePathHash.name        = "storePathHash";
  storePathHash.required    = true;
  storePathHash.schema.type = "string";
in {
  openapi = "3.0.1";
  info.title               = "Nix Binary Cache";
  info.description         = "This is a specification for a Nix binary cache";
  info.version             = "1.0.0";
  externalDocs.description = "Find out more about Nix & NixOS";
  externalDocs.url         = "http://nixos.org/";
  servers = [
    { url = "https://nix-cache.s3.amazonaws.com"; description = "The raw S3 bucket to fetch the Nix binary cache info"; }
    { url = "https://cache.nixos.org/";           description = "The CDN fronted Nix binary cache";}
  ];
  paths."/nix-cache-info".get = {
    summary     = "Get information about this Nix binary cache";
    operationId = "getNixCacheInfo";
    responses."200".description = "successful operation";
    responses."200".content."text/plain".schema."$ref" = "#/components/schemas/NixCacheInfo";
  };
  paths."/log/{deliver}".get = {
    summary     = ''
      Get the build logs for a particular deriver.
      This path exists if this binary cache is hydrated from Hydra.'';
    operationId = "getDeriverBuildLog";
    parameters  = [ deriver ];
    responses."200".description = "successful operation. This is usually compressed such as with brotli.";
    responses."200".content."text/plain".schema.type    = "string";
    responses."200".content."text/plain".schema.example = ''
      unpacking sources
      unpacking source archive /nix/store/x3ir0dv32r6603df7myx14s308sfsh0c-source
      source root is source
      patching sources
      applying patch /nix/store/073hhn64isdlfbsjyr0sw78gyr9g7llg-source/patches/ruby/2.7/head/railsexpress/01-fix-broken-tests-caused-by-ad.patch
      patching file spec/ruby/core/process/groups_spec.rb
      patching file spec/ruby/library/etc/getgrgid_spec.rb
      patching file spec/ruby/library/etc/struct_group_spec.rb
      patching file test/ruby/test_process.rb
      applying patch /nix/store/073hhn64isdlfbsjyr0sw78gyr9g7llg-source/patches/ruby/2.7/head/railsexpress/02-improve-gc-stats.pa'';
    responses."404".description = "Not found";
    responses."404".content     = {};
  };
  paths."/{storePathHash}.ls".get = {
    summary     = "Get the file listings for a particular store-path (once you expand the NAR).";
    operationId = "getNarFileListing";
    parameters  = [ storePathHash ];
    responses."200".description = "successful operation. This is usually compressed such as with brotli.";
    responses."200".content."application/json".schema."$ref" = "#/components/schemas/FileListing";
    responses."404".description = "Not found";
    responses."404".content     = {};
  };
  paths."/{storePathHash}.narinfo".head = {
    summary     = "Check if a particular path exists quickly";
    operationId = "doesNarInfoExist";
    parameters  = [ storePathHash ];
    responses."200".description = "successful operation";
    responses."404".description = "Not found";
  };
  paths."/{storePathHash}.narinfo".get = {
    summary     = "Get the NarInfo for a particular path";
    operationId = "getNarInfo";
    parameters  = [ storePathHash ];
    responses."200".description = "successful operation";
    responses."200".content."text/x-nix-narinfo".schema."$ref" = "#/components/schemas/NarInfo";
    responses."404".description = "Not found";
    responses."404".content     = {};
  };
  paths."/nar/{fileHash}.nar.{compression}".get = {
    summary     = "Get the compressed NAR object";
    operationId = "getCompressedNar";
    parameters  = [ fileHash compression ];
    responses."200".description = "successful operation";
    responses."200".content."application/x-nix-nar".schema.type   = "string";
    responses."200".content."application/x-nix-nar".schema.format = "binary";
    responses."404".description = "Not found";
    responses."404".content     = {};
  };
  components.schemas = {
    # see = "https://releases.nixos.org/nix/nix-1.11.9/manual/index.html#idm140737316141296";
    NixCacheInfo.type       = "object";
    NixCacheInfo.required   = [ "StoreDir" "WantMassQuery" "Priority" ];
    NixCacheInfo.properties = {
      StoreDir.type        = "string";
      StoreDir.example     = "/nix/store";
      StoreDir.description = ''
        The path of the Nix store to which this binary cache applies.
        Binaries are not relocatable — a binary built for /nix/store won’t generally work in /home/alice/store
        — so to prevent binaries from being used in a wrong store, a binary cache is only used if its StoreDir
        matches the local Nix configuration. The default is /nix/store.'';
      WantMassQuery.type        = "integer";
      WantMassQuery.description = ''
        Query operations such as nix-env -qas can cause thousands of cache queries,
        and thus thousands of HTTP requests, to determine which packages are available in binary form.
        While these requests are small, not every server may appreciate a potential onslaught of queries.
        If WantMassQuery is set to 0 (default), “mass queries” such as nix-env -qas will skip this cache.
        Thus a package may appear not to have a binary substitute. However, the binary will still be used
        when you actually install the package. If WantMassQuery is set to 1, mass queries will use this cache.'';
      Priority.type        = "integer";
      Priority.description = ''
        Each binary cache has a priority (defaulting to 50).
        Binary caches are checked for binaries in order of ascending priority;
        thus a higher number denotes a lower priority.
        The binary cache https://cache.nixos.org has priority 40.'';
    };
    FileListingEntryType.type            = "string";
    FileListingEntryType.enum            = ["directory" "regular" ];
    FileListingDirectoryEntry.type       = "object";
    FileListingDirectoryEntry.required   = ["type" "entries"];
    FileListingDirectoryEntry.properties = {
      type."$ref"  = "#/components/schemas/FileListingEntryType";
      entries.type = "object";
      entries.additionalProperties.oneOf = [
        { "$ref" = "#/components/schemas/FileListingFileEntry"; }
        { "$ref" = "#/components/schemas/FileListingDirectoryEntry"; }
      ];
    };
    FileListingFileEntry.type       = "object";
    FileListingFileEntry.required   = [ "type" "size" "narOffset" ];
    FileListingFileEntry.properties = {
      type."$ref" = "#/components/schemas/FileListingEntryType";
      size.type   = "integer";
      size.description       = "The size of the file";
      narOffset.type         = "integer";
      narOffset.description  = "The offset in bytes within the NAR";
      executable.type        = "boolean";
      executable.description = "Whether this file should be made executable";
    };
    FileListing.type       = "object";
    FileListing.properties = {
      version.type        = "integer";
      version.description = "The version of this current format";
      root.oneOf          = [
        { "$ref" = "#/components/schemas/FileListingDirectoryEntry"; }
        { "$ref" = "#/components/schemas/FileListingFileEntry"; }
      ];
    };
    NarInfo.type     = "object";
    NarInfo.required = [
      "StorePath"
      "URL"
      "FileHash"
      "NarHash"
      "FileSize"
      "NarSize"
      "Sig"
      "References"
    ];
    NarInfo.properties = {
      Compression.description = "The compression method; xz, bzip2, zstd, lzip, lz4, br.";
      Compression.example     = "zstd";
      Compression.type        = "string";
      Deriver.description     = "The deriver of the store path, without the Nix store prefix. This field is optional.";
      Deriver.example         = "bidkcs01mww363s4s7akdhbl6ws66b0z-ruby-2.7.3.drv";
      Deriver.type            = "string";
      FileHash.description    = "The cryptographic hash of the file to download in base32";
      FileHash.example        = "sha256:1w1fff338fvdw53sqgamddn1b2xgds473pv6y13gizdbqjv4i5p3";
      FileHash.type           = "string";
      FileSize.minimum        = 0;
      FileSize.type           = "integer";
      NarHash.description     = "The cryptographic hash of the NAR (decompressed) in base 32";
      NarHash.example         = "sha256:1impfw8zdgisxkghq9a3q7cn7jb9zyzgxdydiamp8z2nlyyl0h5h";
      NarHash.type            = "string";
      NarSize.minimum         = 0;
      NarSize.type            = "integer";
      References.description  = "Store paths for direct runtime dependencies";
      References.example      = "0d71ygfwbmy1xjlbj1v027dfmy9cqavy-libffi-3.3";
      References.items.type   = "string";
      References.type         = "array";
      StorePath.description   = "The full store path, including the name part (e.g., glibc-2.7). It must match the requested store path.";
      StorePath.example       = "/nix/store/p4pclmv1gyja5kzc26npqpia1qqxrf0l-ruby-2.7.3";
      StorePath.type          = "string";
      System.description      = "The Nix platform type of this binary, if known. This field is optional.";
      System.example          = "linux-x86-64";
      System.type             = "string";
      Sig.type                = "string";
      Sig.example             = "cache.nixos.org-1:GrGV/Ls10TzoOaCnrcAqmPbKXFLLSBDeGNh5EQGKyuGA4K1wv1LcRVb6/sU+NAPK8lDiam8XcdJzUngmdhfTBQ==";
      Sig.description         = ''
        A signature of the the form key-name:sig, where key-name is the symbolic name
        of the key pair used to sign and verify the cache (e.g. cache.example.org-1),
        and sig is the actual signature, computed over the StorePath, NarHash, NarSize
        and References fields using the Ed25519 public-key signature system.'';
      URL.description         = "The URL of the NAR, relative to the binary cache URL.";
      URL.example             = "nar/1w1fff338fvdw53sqgamddn1b2xgds473pv6y13gizdbqjv4i5p3.nar.xz";
      URL.type                = "string";
    };
  };
}
