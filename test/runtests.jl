using Test
using ManualArtifactDownload

@testset "ManualArtifactDownload" begin
    @testset "URIs -> SCP Remote Paths" begin
        @test ManualArtifactDownload.uri_to_scp_remote_path("scp://host/relative/path") == "host:relative/path"
        @test ManualArtifactDownload.uri_to_scp_remote_path("scp://host//absolute/path") == "host:/absolute/path"
        @test ManualArtifactDownload.uri_to_scp_remote_path("scp://user@host/relative/path") == "user@host:relative/path"
        @test ManualArtifactDownload.uri_to_scp_remote_path("scp://user@host//absolute/path") == "user@host:/absolute/path"
        @test ManualArtifactDownload.uri_to_scp_remote_path("scp://host") == "host:"
        @test ManualArtifactDownload.uri_to_scp_remote_path("scp://user@host") == "user@host:"
        @test_throws ErrorException ManualArtifactDownload.uri_to_scp_remote_path("https://host/some/path")
    end
end
