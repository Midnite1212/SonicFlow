import Foundation
import Testing

@testable import SonicFlowCore

private let listJSON = #"""
{"active": {"asr": "parakeet-v2", "cleanup": "qwen3-4b"}, "models": [
 {"id": "parakeet-v2", "kind": "asr", "family": "parakeet", "source": "mlx-community/parakeet-tdt-0.6b-v2",
  "title": "Parakeet TDT 0.6B v2", "group": "recommended", "size_bytes": 2470000000, "note": "Default.",
  "bench": {"p50_ms": 115, "wer": 0.049}, "installed": true, "download": null},
 {"id": "whisper-small", "kind": "asr", "family": "whisper", "source": "mlx-community/whisper-small-mlx",
  "title": "Whisper small", "group": "catalog", "size_bytes": 480000000, "note": "", "bench": null,
  "installed": false, "download": {"model_id": "whisper-small", "repo": "x", "state": "downloading",
  "total_bytes": 480000000, "error": null, "bytes": 120000000}},
 {"id": "whisper-tiny", "kind": "asr", "family": "whisper", "source": "mlx-community/whisper-tiny-mlx",
  "title": "Whisper tiny", "group": "catalog", "size_bytes": 70000000, "note": "", "bench": null,
  "installed": false, "download": {"model_id": "whisper-tiny", "repo": "x", "state": "error",
  "total_bytes": null, "error": "offline", "bytes": 0}},
 {"id": "ollama:llama3.2:3b", "kind": "cleanup", "family": "ollama", "source": "llama3.2:3b",
  "title": "llama3.2:3b", "group": "custom", "size_bytes": null, "note": "", "bench": null,
  "installed": false, "download": null},
 {"id": "qwen3-1.7b", "kind": "cleanup", "family": "mlx-lm", "source": "mlx-community/Qwen3-1.7B-4bit",
  "title": "Qwen3 1.7B", "group": "recommended", "size_bytes": 980000000, "note": "", "bench": null,
  "installed": true, "download": null}
]}
"""#

@Test func decodesModelListAndGroups() throws {
    let list = try JSONDecoder.engine.decode(ModelList.self, from: Data(listJSON.utf8))
    #expect(list.models(in: .recommended, kind: .asr).map(\.id) == ["parakeet-v2"])
    #expect(list.models(in: .catalog, kind: .asr).count == 2)
    #expect(list.model("parakeet-v2")?.bench?.p50Ms == 115)
    #expect(list.isDownloading)
}

@Test func rowActionsFollowState() throws {
    let list = try JSONDecoder.engine.decode(ModelList.self, from: Data(listJSON.utf8))
    func action(_ id: String) -> ModelInfo.Action {
        let model = list.model(id)!
        return model.action(isActive: list.isActive(model))
    }
    #expect(action("parakeet-v2") == .inUse)
    #expect(action("whisper-small") == .downloading(fraction: 0.25))
    #expect(action("whisper-tiny") == .failed("offline"))
    #expect(action("ollama:llama3.2:3b") == .unavailable)
    #expect(action("qwen3-1.7b") == .use)
}

@Test func decodesSearchAndOllama() throws {
    let search = try JSONDecoder.engine.decode(
        HubSearch.self,
        from: Data(#"{"results": [{"source": "a/b", "family": "mlx-lm", "kind": "cleanup", "downloads": 9, "added": false}]}"#.utf8)
    )
    #expect(search.results.first?.id == "a/b")
    let ollama = try JSONDecoder.engine.decode(
        OllamaStatus.self, from: Data(#"{"running": true, "models": [{"name": "m:1b", "size": 5, "added": true}]}"#.utf8)
    )
    #expect(ollama.running && ollama.models.first?.added == true)
    #expect(ModelInfo.size(nil) == nil)
    #expect(ModelInfo.size(0) == nil)
}
