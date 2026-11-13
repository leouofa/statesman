# frozen_string_literal: true

module Api
  module V1
    class OpenapiSpec
      def self.generate
        {
          openapi: "3.1.0",
          info: {
            title: "Statesman Platform REST API",
            version: "1.0.0",
            description: "Full programmatic REST API for the Statesman comparative geopolitics, statecraft, and political-economy research platform."
          },
          servers: [
            { url: "/api/v1", description: "Default v1 endpoint" }
          ],
          paths: {
            "/status" => {
              get: {
                summary: "Platform status, health, and entity statistics",
                operationId: "getPlatformStatus",
                responses: {
                  "200" => { description: "Current platform status and counts" }
                }
              }
            },
            "/openapi.json" => {
              get: {
                summary: "OpenAPI 3.1 specification for Statesman",
                operationId: "getOpenapiSpec",
                responses: {
                  "200" => { description: "OpenAPI schema document" }
                }
              }
            },
            "/search" => {
              get: {
                summary: "Cross-resource semantic or keyword search across Countries and Cities",
                operationId: "searchAll",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[all country city], default: "all" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: {
                  "200" => { description: "Search results with similarity distances" }
                }
              }
            },
            "/continents" => {
              get: {
                summary: "List continents",
                operationId: "listContinents",
                parameters: [
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "include_countries", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of continents" } }
              },
              post: {
                summary: "Create a continent",
                operationId: "createContinent",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[name description],
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created continent" } }
              }
            },
            "/continents/{id}" => {
              get: {
                summary: "Get continent details",
                operationId: "getContinent",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_countries", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Continent details" } }
              },
              patch: {
                summary: "Update continent",
                operationId: "updateContinent",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated continent" } }
              },
              delete: {
                summary: "Delete continent",
                operationId: "deleteContinent",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Continent deleted" } }
              }
            },
            "/continents/upsert_batch" => {
              post: {
                summary: "Batch upsert continents",
                operationId: "batchUpsertContinents",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[continents],
                        properties: {
                          continents: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted continents" } }
              }
            },
            "/continents/populate" => {
              post: {
                summary: "Trigger LLM discovery of continents",
                operationId: "populateContinents",
                parameters: [
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Async job queued" } }
              }
            },
            "/continents/{id}/populate_countries" => {
              post: {
                summary: "Trigger LLM discovery of countries for a single continent",
                operationId: "populateContinentCountries",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Async job queued" } }
              }
            },
            "/countries" => {
              get: {
                summary: "List/filter countries",
                operationId: "listCountries",
                parameters: [
                  { name: "continent_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "continent", in: "query", required: false, schema: { type: "string" } },
                  { name: "theme", in: "query", required: false, schema: { type: "string" } },
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "embedded", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_cities", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of countries" } }
              },
              post: {
                summary: "Create a country",
                operationId: "createCountry",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[continent_id name description],
                        properties: {
                          continent_id: { type: "integer" },
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created country" } }
              }
            },
            "/countries/search" => {
              get: {
                summary: "Semantic or keyword search for countries",
                operationId: "searchCountries",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "continent_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "Country search results" } }
              }
            },
            "/countries/{id}" => {
              get: {
                summary: "Get country details",
                operationId: "getCountry",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_cities", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Country details" } }
              },
              patch: {
                summary: "Update country",
                operationId: "updateCountry",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } },
                          continent_id: { type: "integer" }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated country" } }
              },
              delete: {
                summary: "Delete country",
                operationId: "deleteCountry",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Country deleted" } }
              }
            },
            "/countries/{id}/neighbors" => {
              get: {
                summary: "Nearest-neighbor countries by cosine distance",
                operationId: "getCountryNeighbors",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 10 } },
                  { name: "continent_id", in: "query", required: false, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Nearest neighbors" } }
              }
            },
            "/countries/{id}/generate_embedding" => {
              post: {
                summary: "Generate vector embedding for country",
                operationId: "generateCountryEmbedding",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Embedding generated" }, "202" => { description: "Job queued" } }
              }
            },
            "/countries/{id}/populate_cities" => {
              post: {
                summary: "Discover/populate cities for a country via LLM",
                operationId: "populateCountryCities",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Cities created" }, "202" => { description: "Job queued" } }
              }
            },
            "/countries/populate" => {
              post: {
                summary: "Trigger bulk LLM country discovery",
                operationId: "populateAllCountries",
                parameters: [
                  { name: "continent_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Job queued" } }
              }
            },
            "/countries/upsert_batch" => {
              post: {
                summary: "Batch upsert countries for a continent",
                operationId: "batchUpsertCountries",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[continent_id countries],
                        properties: {
                          continent_id: { type: "integer" },
                          countries: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" },
                                themes: { type: "array", items: { type: "string" } }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted countries" } }
              }
            },
            "/cities" => {
              get: {
                summary: "List/filter cities",
                operationId: "listCities",
                parameters: [
                  { name: "country_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "continent_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "theme", in: "query", required: false, schema: { type: "string" } },
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "embedded", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of cities" } }
              },
              post: {
                summary: "Create a city for a country",
                operationId: "createCity",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[country_id name description],
                        properties: {
                          country_id: { type: "integer" },
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created city" } }
              }
            },
            "/cities/search" => {
              get: {
                summary: "Semantic or keyword search for cities",
                operationId: "searchCities",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "country_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "continent_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "City search results" } }
              }
            },
            "/cities/{id}" => {
              get: {
                summary: "Get city details",
                operationId: "getCity",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "City details" } }
              },
              patch: {
                summary: "Update city",
                operationId: "updateCity",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated city" } }
              },
              delete: {
                summary: "Delete city",
                operationId: "deleteCity",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "City deleted" } }
              }
            },
            "/cities/{id}/neighbors" => {
              get: {
                summary: "Nearest-neighbor cities by cosine distance",
                operationId: "getCityNeighbors",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 10 } },
                  { name: "country_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "continent_id", in: "query", required: false, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Nearest neighbors" } }
              }
            },
            "/cities/{id}/generate_embedding" => {
              post: {
                summary: "Generate vector embedding for city",
                operationId: "generateCityEmbedding",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Embedding generated" }, "202" => { description: "Job queued" } }
              }
            },
            "/cities/populate" => {
              post: {
                summary: "Trigger bulk LLM city discovery",
                operationId: "populateAllCities",
                parameters: [
                  { name: "country_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Job queued" } }
              }
            },
            "/cities/upsert_batch" => {
              post: {
                summary: "Batch upsert cities for a country",
                operationId: "batchUpsertCities",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[country_id cities],
                        properties: {
                          country_id: { type: "integer" },
                          cities: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" },
                                themes: { type: "array", items: { type: "string" } }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted cities" } }
              }
            },
            "/clusters" => {
              get: {
                summary: "Compute or fetch live clusters",
                operationId: "getLiveClusters",
                parameters: [
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[Country City], default: "Country" } },
                  { name: "level", in: "query", required: false, schema: { type: "integer", minimum: 1, maximum: 15, default: 5 } },
                  { name: "full_coverage", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "force", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Clustering result" } }
              }
            },
            "/clusters/snapshot" => {
              post: {
                summary: "Compute and save a cluster snapshot",
                operationId: "createSnapshotFromCluster",
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          target_type: { type: "string", enum: %w[Country City], default: "Country" },
                          level: { type: "integer", default: 5 },
                          full_coverage: { type: "boolean", default: false },
                          title: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Persisted ClusterSnapshot" } }
              }
            },
            "/cluster_snapshots" => {
              get: {
                summary: "List cluster snapshots",
                operationId: "listClusterSnapshots",
                parameters: [
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[Country City] } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of snapshots" } }
              },
              post: {
                summary: "Create and persist a snapshot",
                operationId: "createClusterSnapshot",
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          target_type: { type: "string", enum: %w[Country City], default: "Country" },
                          level: { type: "integer", default: 5 },
                          full_coverage: { type: "boolean", default: false },
                          title: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created snapshot" } }
              }
            },
            "/cluster_snapshots/{id}" => {
              get: {
                summary: "Get cluster snapshot details with groups",
                operationId: "getClusterSnapshot",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_groups", in: "query", required: false, schema: { type: "boolean", default: true } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } },
                  { name: "include_reports", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Snapshot details" } }
              },
              delete: {
                summary: "Delete cluster snapshot",
                operationId: "deleteClusterSnapshot",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Snapshot deleted" } }
              }
            },
            "/cluster_snapshots/{cluster_snapshot_id}/cluster_groups" => {
              get: {
                summary: "List cluster groups in a snapshot",
                operationId: "listSnapshotGroups",
                parameters: [
                  { name: "cluster_snapshot_id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "List of cluster groups" } }
              }
            },
            "/cluster_groups/{id}" => {
              get: {
                summary: "Get cluster group details with members",
                operationId: "getClusterGroup",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Cluster group details" } }
              }
            },
            "/cluster_reports" => {
              get: {
                summary: "List cluster reports",
                operationId: "listClusterReports",
                parameters: [
                  { name: "cluster_snapshot_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[Country City] } },
                  { name: "status", in: "query", required: false, schema: { type: "string" } },
                  { name: "is_detailed", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of cluster reports" } }
              },
              post: {
                summary: "Create a cluster synthesis report",
                operationId: "createClusterReport",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[cluster_snapshot_id],
                        properties: {
                          cluster_snapshot_id: { type: "integer" },
                          prompt: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created report" } }
              }
            },
            "/cluster_reports/{id}" => {
              get: {
                summary: "Get cluster report details",
                operationId: "getClusterReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_summaries", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_sub_reports", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Cluster report details" } }
              },
              delete: {
                summary: "Delete cluster report",
                operationId: "deleteClusterReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Report deleted" } }
              }
            },
            "/cluster_reports/{id}/deep_synthesis" => {
              post: {
                summary: "Create detailed 3-phase report from an existing report",
                operationId: "createDeepSynthesisReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          batch_size: { type: "integer", minimum: 2, maximum: 50, default: 5 }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created deep synthesis report" } }
              }
            },
            "/cluster_reports/{cluster_report_id}/summaries" => {
              get: {
                summary: "List Phase 1 per-cluster summaries",
                operationId: "listReportSummaries",
                parameters: [
                  { name: "cluster_report_id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "List of summaries" } }
              }
            },
            "/cluster_report_summaries/{id}" => {
              get: {
                summary: "Get a single cluster report summary",
                operationId: "getReportSummary",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Summary details" } }
              }
            },
            "/cluster_reports/{cluster_report_id}/sub_reports" => {
              get: {
                summary: "List Phase 2 batch sub-reports",
                operationId: "listReportSubReports",
                parameters: [
                  { name: "cluster_report_id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "List of sub-reports" } }
              }
            },
            "/cluster_sub_reports/{id}" => {
              get: {
                summary: "Get a single batch sub-report",
                operationId: "getReportSubReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Sub-report details" } }
              }
            },
            "/jobs" => {
              get: {
                summary: "List recent background jobs",
                operationId: "listJobs",
                parameters: [
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "Recent jobs" } }
              }
            },
            "/jobs/{id}" => {
              get: {
                summary: "Get status and progress of a background job",
                operationId: "getJobStatus",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "string" } }
                ],
                responses: { "200" => { description: "Job status" } }
              }
            },
            "/settings" => {
              get: {
                summary: "Get platform embedding and LLM settings",
                operationId: "getSettings",
                responses: { "200" => { description: "Settings and statistics" } }
              }
            },
            "/settings/context_window" => {
              patch: {
                summary: "Update LLM context window",
                operationId: "updateContextWindow",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[context_window],
                        properties: {
                          context_window: { type: "integer", minimum: 4096 }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated context window" } }
              }
            },
            "/settings/generate_embeddings" => {
              post: {
                summary: "Enqueue bulk embedding generation",
                operationId: "generateAllEmbeddings",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[model_type],
                        properties: {
                          model_type: { type: "string", enum: %w[Country City] },
                          only_missing: { type: "boolean", default: true }
                        }
                      }
                    }
                  }
                },
                responses: { "202" => { description: "Job enqueued" } }
              }
            }
          }
        }
      end
    end
  end
end
