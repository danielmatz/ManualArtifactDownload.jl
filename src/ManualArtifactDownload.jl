module ManualArtifactDownload

using Artifacts: select_downloadable_artifacts, artifact_exists, artifact_path
import Pkg.GitTools
using Pkg.PlatformEngines: unpack
using SHA: sha256
using Base: SHA1
using URIs: URI

export download_artifact, download_artifacts

function compute_tree_hash(root)
    SHA1(bytes2hex(GitTools.tree_hash(root)))
end

function sha256sum(path)
    return open(path, "r") do io
        return bytes2hex(sha256(io))
    end
end

# Not all versions of scp support URIs. The lowest common denominator
# seems to be a remote path of the form user@host:path. With no
# leading slash, path is relative to the user's home directory. With a
# leading slash, it is an absolute path.
function uri_to_scp_remote_path(uri)
    (; scheme, userinfo, host, path) = URI(uri)

    # This only works for scp:// URIs
    scheme == "scp" || error("unsupported scheme: $scheme")

    # The host is required
    isempty(host) && error("no host in URI: $uri")

    # The URI `path` will start with "//" for an absolute path and "/"
    # for a relative one. The "host:path" format uses one less slash
    # in both cases. The path may also be empty, though, which means
    # the file is just copied into the user's home directory.
    if !isempty(path)
        startswith(path, "/") || error("invalid path in url: $path")
        path = path[2:end]
    end

    if isempty(userinfo)
        string(host, ":", path)
    else
        string(userinfo, "@", host, ":", path)
    end
end

# We can't use `Downloads.download`, because it relies on curl. We
# need to use the `scp` CLI, so that it uses SSH authentication
# properly. This is the entire point of this package!
function download(url)
    dest, _ = mktemp()
    remote_path = uri_to_scp_remote_path(url)
    run(`scp $remote_path $dest`)
    return dest
end

"""
    download_artifact(; url::String, tarball_hash::String, tree_hash::SHA1)

Downloads the artifact at `url`, confirms its hash matches
`tarball_hash`, unpacks it, confirms the hash of the unpacked tree
matches `tree_hash`, installs the artifact, and returns the path to
the artifact
"""
function download_artifact(; url::String, tarball_hash::String, tree_hash::SHA1)
    artifact_exists(tree_hash) && return artifact_path(tree_hash)
    tarball_path = download(url)
    hash = sha256sum(tarball_path)
    if !(hash == tarball_hash)
        @error "hash of download did not match" expected = tarball_hash got = hash path = tarball_path
        error("hash of download did not match")
    end
    mktempdir() do unpack_dest
        unpack(tarball_path, unpack_dest)
        hash = compute_tree_hash(unpack_dest)
        if hash != tree_hash
            @error "tree hash of download does not match" expected = tree_hash got = hash
            error("tree hash of download does not match")
        end

        # Sometimes the artifact directory hasn't been created, yet,
        # which causes the copy to fail. Let's make sure it exists.
        install_dest = artifact_path(tree_hash)
        mkpath(dirname(install_dest))

        cp(unpack_dest, install_dest)
    end
end

"""
    download_artifacts(artifacts_toml::String)

Downloads and installs any artifacts in the TOML file at the path
`artifacts_toml` that are appropriate for the current system.
"""
function download_artifacts(artifacts_toml::String)
    artifacts = select_downloadable_artifacts(artifacts_toml)
    for (name, meta) in artifacts
        for download_data in meta["download"]
            url = download_data["url"]
            # We only know how to download with `scp`
            if startswith(url, "scp://")
                download_artifact(
                    url = url,
                    tarball_hash = download_data["sha256"],
                    tree_hash = SHA1(meta["git-tree-sha1"]),
                )
            end
        end
    end
end

end
