# Echo — Custom Connectors

Three custom connectors for Copilot Studio. Import each as a separate connector under **Power Platform → Custom connectors → New → Import from OpenAPI file**.

| Connector | Purpose | Auth |
|---|---|---|
| `EchoSpeech` | Raw Azure AI Speech HD synthesis (rarely used directly) | Subscription key |
| `EchoPublisher` | Synthesize + store + publish + list episodes | Function key (Entra ID for v1.1) |
| `BedrockCatalogQA` | Cross-cloud Q&A over your podcast catalog (optional) | Entra Agent ID token (see `09-entra-agent-id-setup.md`) |

---

## Connector 1: SynthesizeSpeech (raw Speech)

Wraps Azure AI Speech's batch synthesis API. Takes SSML, returns an MP3 URL.

### OpenAPI spec (paste into a `.json` file and import)

```json
{
  "swagger": "2.0",
  "info": {
    "title": "Echo Speech",
    "description": "Synthesize SSML into an MP3 using Azure AI Speech HD voices.",
    "version": "1.0"
  },
  "host": "{SPEECH_REGION}.tts.speech.microsoft.com",
  "basePath": "/",
  "schemes": ["https"],
  "consumes": ["application/ssml+xml"],
  "produces": ["audio/mpeg"],
  "paths": {
    "/cognitiveservices/v1": {
      "post": {
        "summary": "Synthesize speech",
        "operationId": "SynthesizeSpeech",
        "parameters": [
          {
            "name": "X-Microsoft-OutputFormat",
            "in": "header",
            "type": "string",
            "required": true,
            "default": "audio-48khz-192kbitrate-mono-mp3"
          },
          {
            "name": "Content-Type",
            "in": "header",
            "type": "string",
            "required": true,
            "default": "application/ssml+xml"
          },
          {
            "name": "User-Agent",
            "in": "header",
            "type": "string",
            "required": true,
            "default": "echo-orchestrator"
          },
          {
            "name": "body",
            "in": "body",
            "required": true,
            "schema": {
              "type": "string",
              "description": "SSML payload"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "MP3 audio stream",
            "schema": { "type": "string", "format": "binary" }
          }
        }
      }
    }
  },
  "securityDefinitions": {
    "api_key": {
      "type": "apiKey",
      "in": "header",
      "name": "Ocp-Apim-Subscription-Key"
    }
  },
  "security": [{ "api_key": [] }]
}
```

### Wrap with a Function (recommended)

The raw Speech endpoint returns binary audio inline, which Copilot Studio can't easily route. Better: wrap it in your own Azure Function that:

1. Receives SSML
2. Calls Speech
3. Uploads the MP3 to Blob Storage
4. Returns the Blob URL as JSON

That wrapper is the **PublishEpisode** connector below.

---

## Connector 2: PublishEpisode

Single endpoint that handles speech synthesis + storage + RSS feed update. Your Publisher Azure Function exposes this. Connector points at your Function App.

### OpenAPI spec

```json
{
  "swagger": "2.0",
  "info": {
    "title": "Echo Publisher",
    "description": "Publishes a synthesized episode to a user's private podcast feed.",
    "version": "1.0"
  },
  "host": "{FUNCTION_APP_HOST}",
  "basePath": "/api",
  "schemes": ["https"],
  "consumes": ["application/json"],
  "produces": ["application/json"],
  "paths": {
    "/synthesize": {
      "post": {
        "summary": "Synthesize SSML to MP3 and store it",
        "operationId": "synthesize",
        "description": "Long-running operation. Returns 202 + a Location header; Power Platform auto-polls that URL until it returns a non-202 response, then surfaces the final 200 body (with mp3Url). This bypasses the connector's ~30s synchronous timeout, which full-episode HD synthesis can exceed.",
        "x-ms-long-running-operation": true,
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "schema": {
              "type": "object",
              "required": ["ssml", "userId"],
              "properties": {
                "ssml": { "type": "string" },
                "userId": { "type": "string", "description": "Requester email" }
              }
            }
          }
        ],
        "responses": {
          "202": {
            "description": "Accepted — job queued. The connector polls the Location header until it returns 200.",
            "headers": {
              "Location": {
                "type": "string",
                "description": "Status URL to poll. Anonymous, guarded by the unguessable jobId."
              }
            },
            "schema": {
              "type": "object",
              "properties": {
                "jobId": { "type": "string" },
                "status": { "type": "string" },
                "statusUrl": { "type": "string" }
              }
            }
          },
          "200": {
            "description": "Synthesis complete (final polled result).",
            "schema": {
              "type": "object",
              "properties": {
                "jobId": { "type": "string" },
                "status": { "type": "string" },
                "mp3Url": { "type": "string" },
                "durationSeconds": { "type": "integer" }
              }
            }
          }
        }
      }
    },
    "/synthesize/status/{jobId}": {
      "get": {
        "summary": "Poll synthesis job status",
        "description": "Called automatically by the long-running-operation poller. Anonymous: the function key is NOT required (and is not reattached to the polled Location URL), so this endpoint is guarded by the unguessable jobId instead.",
        "operationId": "SynthesizeStatus",
        "parameters": [
          { "name": "jobId", "in": "path", "type": "string", "required": true }
        ],
        "responses": {
          "202": { "description": "Still queued or running — keep polling." },
          "200": {
            "description": "Done.",
            "schema": {
              "type": "object",
              "properties": {
                "jobId": { "type": "string" },
                "status": { "type": "string" },
                "mp3Url": { "type": "string" },
                "durationSeconds": { "type": "integer" }
              }
            }
          },
          "500": { "description": "Synthesis failed." }
        }
      }
    },
    "/episodes": {
      "post": {
        "summary": "Publish an episode to the user's feed",
        "operationId": "PublishEpisode",
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "schema": {
              "type": "object",
              "required": ["mp3Url", "title", "description", "userId"],
              "properties": {
                "mp3Url": { "type": "string" },
                "title": { "type": "string" },
                "description": { "type": "string" },
                "userId": { "type": "string" },
                "durationSeconds": { "type": "integer" }
              }
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Episode published",
            "schema": {
              "type": "object",
              "properties": {
                "episodeId": { "type": "string" },
                "listenUrl": { "type": "string" },
                "rssFeedUrl": { "type": "string" }
              }
            }
          }
        }
      },
      "get": {
        "summary": "List a user's recent episodes",
        "operationId": "ListEpisodes",
        "parameters": [
          { "name": "userId", "in": "query", "type": "string", "required": true },
          { "name": "limit", "in": "query", "type": "integer", "default": 5 }
        ],
        "responses": {
          "200": {
            "description": "Episode list",
            "schema": {
              "type": "object",
              "properties": {
                "episodes": {
                  "type": "array",
                  "items": {
                    "type": "object",
                    "properties": {
                      "episodeId": { "type": "string" },
                      "title": { "type": "string" },
                      "publishedAt": { "type": "string" },
                      "durationSeconds": { "type": "integer" },
                      "listenUrl": { "type": "string" }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  },
  "securityDefinitions": {
    "function_key": {
      "type": "apiKey",
      "in": "header",
      "name": "x-functions-key"
    }
  },
  "security": [{ "function_key": [] }]
}
```

### Authentication

Use Function-level keys for the demo. For production, swap to Entra ID auth (Function App → Authentication → Add Microsoft identity provider) and remove the function key.

> **Note:** `SynthesizeSpeech` is a **long-running operation**. The `POST /synthesize` carries the function key, but the `202` `Location` URL it returns does **not**, and Power Platform does not reattach the key when auto-polling. The `/synthesize/status/{jobId}` endpoint is therefore **anonymous** (guarded by the unguessable jobId). If you ever switch the status endpoint back to `authLevel: 'function'`, the connector poll will get **401** and the orchestrator will fail with a generic "something went wrong" because it never receives `mp3Url`.

### Long-running operation (why synthesize is async)

Full-episode HD synthesis can take longer than the connector's ~30s synchronous limit. So `POST /synthesize` returns immediately with `202` + a `Location` header, and `x-ms-long-running-operation: true` tells Power Platform to poll that URL until it returns `200` with the final `mp3Url`. **If you import an older spec without the `202`/`x-ms-long-running-operation` declaration, the connector treats the `202` body (`{ jobId, status: "queued" }`) as the final result, `mp3Url` is null, and the downstream `PublishEpisode` call fails.** Re-import this connector after any change to the synthesize contract.

---

## Wiring up in Copilot Studio

1. Import each connector via **Custom connectors → New → Import OpenAPI file**.
2. Test the connection by running each operation with sample data. For `SynthesizeSpeech`, confirm the test eventually returns `200` with a populated `mp3Url` (it will sit on `202` for a few seconds while polling — that is expected).
3. In your Echo agent → **Tools → Add tool → Connector** → pick `EchoPublisher` (always) and `BedrockCatalogQA` (optional).
4. Map the operations: `synthesize`, `PublishEpisode`, `ListEpisodes`, `AskCatalog`. **The `operationId` must match what the agent already references** — Copilot Studio binds each tool action to a connector operation by its `operationId`, so changing it (e.g. via re-import) breaks the binding with `ConnectorOperationNotFound`. If a later step throws that error for `PublishEpisode`/`ListEpisodes`, align those ids the same way.
5. Set the auth: paste the Function key as the connection credential. For `BedrockCatalogQA`, follow `09-entra-agent-id-setup.md` to attach the Entra Agent ID token.
6. **After importing or editing the connector, re-publish the agent.** Teams serves the last *published* snapshot, so connector or topic changes do not reach Teams until you publish.

---

## Connector 3: BedrockCatalogQA (optional, cross-cloud)

Wraps the AWS API Gateway endpoint that fronts the Bedrock Q&A Lambda. Only useful when the AWS stack is deployed (`cdk deploy` in the `echo-bedrock-catalog` repo). When the stack is destroyed (`cdk destroy`), the connector returns 503 — Echo's orchestrator catches that and tells the user the catalog is offline.

### OpenAPI spec

```json
{
  "swagger": "2.0",
  "info": {
    "title": "Echo Bedrock Catalog Q&A",
    "description": "Cross-cloud Q&A over the Echo podcast catalog. Hosted in AWS (eu-central-1), governed by Microsoft Entra Agent ID.",
    "version": "1.0"
  },
  "host": "{BEDROCK_API_HOST}",
  "basePath": "/v1",
  "schemes": ["https"],
  "consumes": ["application/json"],
  "produces": ["application/json"],
  "paths": {
    "/ask": {
      "post": {
        "summary": "Ask a question about the podcast catalog",
        "operationId": "AskCatalog",
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "schema": {
              "type": "object",
              "required": ["question", "userId"],
              "properties": {
                "question": { "type": "string", "description": "Free-form question about the catalog" },
                "userId": { "type": "string", "description": "Requester email — scopes the answer to that user's episodes" },
                "maxEpisodes": { "type": "integer", "default": 50, "description": "How many recent episodes to consider" }
              }
            }
          }
        ],
        "responses": {
          "200": {
            "description": "Answer",
            "schema": {
              "type": "object",
              "properties": {
                "answer": { "type": "string" },
                "citedEpisodeIds": { "type": "array", "items": { "type": "string" } },
                "model": { "type": "string", "description": "e.g. anthropic.claude-haiku-4-5" }
              }
            }
          },
          "503": {
            "description": "Catalog agent is offline (cdk destroy was run). Re-deploy with cdk deploy."
          }
        }
      }
    },
    "/health": {
      "get": {
        "summary": "Liveness probe",
        "operationId": "Health",
        "responses": {
          "200": { "description": "OK" }
        }
      }
    }
  },
  "securityDefinitions": {
    "entra_agent_id": {
      "type": "oauth2",
      "flow": "application",
      "tokenUrl": "https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token",
      "scopes": {
        "api://echo-catalog/.default": "Invoke the catalog Q&A agent"
      }
    }
  },
  "security": [{ "entra_agent_id": ["api://echo-catalog/.default"] }]
}
```

### Auth notes

This connector is the cross-cloud governance moment in the demo. The token presented to AWS is issued by Microsoft Entra against the **Agent Identity Blueprint** registered in your tenant. The Lambda validates the token's `appid` claim matches the registered Agent Identity. End-to-end, the AWS workload runs only when a Microsoft-tenant identity says so. See `09-entra-agent-id-setup.md` for the setup.
