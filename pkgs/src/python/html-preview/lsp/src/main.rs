// use std::collections::HashMap;
use tower_lsp::jsonrpc::Result;
use tower_lsp::lsp_types::*;
use tower_lsp::{async_trait, Client, LanguageServer, LspService, Server};
use reqwest::Client as HttpClient;
use serde_json::json;

#[derive(Debug)]
struct Backend {
    client: Client,
    http: HttpClient,
}

#[async_trait]
impl LanguageServer for Backend {
    async fn initialize(&self, _: InitializeParams) -> Result<InitializeResult> {
        // Important: We include "text_document_sync" with "save: Some(...)"
        // so that the client will notify us on didSave events.
        Ok(InitializeResult {
            capabilities: ServerCapabilities {
                text_document_sync: Some(TextDocumentSyncCapability::Options(
                    TextDocumentSyncOptions {
                        save: Some(tower_lsp::lsp_types::TextDocumentSyncSaveOptions::SaveOptions(SaveOptions::default())),
                        ..Default::default()
                    },
                )),
                ..Default::default()
            },
            ..Default::default()
        })
    }

    async fn initialized(&self, _: InitializedParams) {
        self.client
            .log_message(MessageType::INFO, "server initialized!")
            .await;
    }

    /// Called when a user *saves* a file in the editor.
    async fn did_save(&self, params: DidSaveTextDocumentParams) {
        let uri = params.text_document.uri.clone();
        let path = match uri.to_file_path() {
            Ok(p) => p,
            Err(_) => {
                self.client
                    .log_message(
                        MessageType::ERROR,
                        format!("Could not convert URI to file path: {}", uri),
                    )
                    .await;
                return;
            }
        };

        // If it is an HTML file, do the POST request
        if path.extension().map_or(false, |ext| ext == "html") {
            let path_str = path.to_string_lossy().to_string();
            let payload = json!({ "path": path_str });

            self.client
                .log_message(
                    MessageType::INFO,
                    format!("Sending path to preview server: {}", path_str),
                )
                .await;

            // Make the POST request
            match self.http.post("http://127.0.0.1:5000/update-path")
                .json(&payload)
                .send()
                .await
            {
                Ok(resp) => {
                    if resp.status().is_success() {
                        self.client
                            .log_message(
                                MessageType::INFO,
                                format!("Successfully updated preview for: {}", path_str),
                            )
                            .await;
                    } else {
                        self.client
                            .log_message(
                                MessageType::ERROR,
                                format!("Preview update failed, status: {}", resp.status()),
                            )
                            .await;
                    }
                }
                Err(err) => {
                    self.client
                        .log_message(
                            MessageType::ERROR,
                            format!("Failed to send preview update: {:?}", err),
                        )
                        .await;
                }
            }
        }
    }

    // Other callbacks you might or might not care about:
    async fn shutdown(&self) -> Result<()> {
        Ok(())
    }

    // If you don't need code actions anymore, you can remove this entirely.
    async fn code_action(&self, _: CodeActionParams) -> Result<Option<CodeActionResponse>> {
        Ok(None)
    }
}

#[tokio::main]
async fn main() {
    let stdin = tokio::io::stdin();
    let stdout = tokio::io::stdout();

    // Create the LSP backend with both an LSP client and an HTTP client.
    let (service, socket) = LspService::new(|client| Backend {
        client,
        http: reqwest::Client::new(),
    });

    Server::new(stdin, stdout, socket).serve(service).await;
}
