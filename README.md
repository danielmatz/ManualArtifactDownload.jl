# ManualArtifactDownload.jl

The Downloads stdlib doesn't handle authentication very well at the moment. Until some improvements are made, this package provides a workaround. It uses the `scp` program to download artifacts with URLs starting with `scp://` and then installs those artifacts just as Pkg would. This allows Pkg to see that they are already installed, and so it won't try to download anything with Downloads.

## Usage

```julia
using ManualArtifactDownload

download_artifacts("path/to/Artifacts.toml")
```

