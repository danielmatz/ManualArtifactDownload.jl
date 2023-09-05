module ManualArtifactDownload

using Artifacts: select_downloadable_artifacts, artifact_exists, artifact_path
import Pkg.GitTools
using Pkg.PlatformEngines: unpack
using SHA: sha256
using Base: SHA1

export download_artifact, download_artifacts

function compute_tree_hash(root)
    SHA1(bytes2hex(GitTools.tree_hash(root)))
end

function sha256sum(path)
    return open(path, "r") do io
        return bytes2hex(sha256(io))
    end
end

# We can't use `Downloads.download`, because it relies on curl. We
# need to use the `scp` CLI, so that it uses SSH authentication
# properly. This is the entire point of this package!
function download(url)
    dest, _ = mktemp()
    success(`scp $url $dest`)
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
    hash == tarball_hash || error("hash of download did not match")
    mktempdir() do unpack_dest
        unpack(tarball_path, unpack_dest)
        hash = compute_tree_hash(unpack_dest)
        if hash != tree_hash
            @error "tree hash of download does not match" expected = tree_hash got = hash
            error("tree hash of download does not match")
        end
        cp(unpack_dest, artifact_path(tree_hash))
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
