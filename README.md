# ManualArtifactDownload.jl

The Downloads stdlib doesn't handle authentication very well at the moment. Until some improvements are made, this package provides a workaround. It will use the `scp` program to download artifacts with URLs starting with `scp://`. It will then install those artifacts. This allows Pkg to see that they are already installed, and so it won't need to use Downloads at all.

## Usage

```julia
using ManualArtifactDownload

download_artifacts("path/to/Artifacts.toml")
```

