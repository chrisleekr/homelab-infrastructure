#!/bin/sh

# Install required tools
apk add --no-cache curl jq

# Exit on error
set -e
# Print commands
# set -x

echo "Starting ElasticSearch post setup process..."

echo "Waiting for ElasticSearch to be ready..."
until curl -k --fail \
  -u "elastic:$ELASTIC_PASSWORD" \
  "$ELASTICSEARCH_URL/_cluster/health"; do
  sleep 10
done
echo "ElasticSearch is ready"

ls -al /scripts

# Delete existing index filebeat-custom if it exists
curl -k -X DELETE \
  -u "elastic:$ELASTIC_PASSWORD" \
  "$ELASTICSEARCH_URL/filebeat-custom" \
  --fail || true

# # Delete existing data stream if it exists
curl -k -X DELETE \
  -u "elastic:$ELASTIC_PASSWORD" \
  "$ELASTICSEARCH_URL/_data_stream/filebeat-custom" \
  --fail || true

# # Delete existing index template if it exists
curl -k -X DELETE \
  -u "elastic:$ELASTIC_PASSWORD" \
  "$ELASTICSEARCH_URL/_index_template/filebeat-custom" \
  --fail || true

# # Delete existing ILM policy if it exists
curl -k -X DELETE \
  -u "elastic:$ELASTIC_PASSWORD" \
  "$ELASTICSEARCH_URL/_ilm/policy/filebeat-custom" \
  --fail || true

# sleep 2

# Create ILM policy
curl -k -X PUT \
  -u "elastic:$ELASTIC_PASSWORD" \
  "$ELASTICSEARCH_URL/_ilm/policy/filebeat-custom" \
  -H "Content-Type: application/json" \
  --fail \
  -d '{
      "policy": {
        "phases": {
          "hot": {
            "min_age": "0ms",
            "actions": {
              "rollover": {
                "max_primary_shard_size": "10gb",
                "max_age": "12h",
                "max_docs": 500000
              },
              "set_priority": {
                "priority": 100
              }
            }
          },
          "warm": {
            "min_age": "6h",
            "actions": {
              "set_priority": {
                "priority": 50
              },
              "shrink": {
                "number_of_shards": 1
              },
              "forcemerge": {
                "max_num_segments": 1
              }
            }
          },
          "delete": {
            "min_age": "12h",
            "actions": {
              "delete": {
                "delete_searchable_snapshot": true
              }
            }
          }
        }
      }
    }
' || exit 1

# Create index template - filebeat-custom.json
curl -k -X PUT \
  -u "elastic:$ELASTIC_PASSWORD" \
  "$ELASTICSEARCH_URL/_index_template/filebeat-custom" \
  -H "Content-Type: application/json" \
  --fail \
  -d @/scripts/filebeat-custom.json || exit 1

# Create data stream - filebeat-custom if does not exist. Ok to fail
# https://www.elastic.co/docs/api/doc/elasticsearch/v8/operation/operation-indices-get-data-lifecycle
curl -k -X PUT \
  -u "elastic:$ELASTIC_PASSWORD" \
  "$ELASTICSEARCH_URL/_data_stream/filebeat-custom" \
  -H "Content-Type: application/json" \
  --fail || true

# Wait between requests
sleep 2

# Create user-agent pipeline
curl -k -X PUT \
  -u "elastic:$ELASTIC_PASSWORD" \
  "$ELASTICSEARCH_URL/_ingest/pipeline/user-agent-info" \
  -H "Content-Type: application/json" \
  --fail \
  -d '{
    "description": "Add user agent info",
    "processors": [
      {
        "user_agent": {
          "field": "nginx.ingress.agent",
          "target_field": "user_agent",
          "ignore_missing": true
        }
      }
    ]
  }' || exit 1

sleep 2

# Create geoip pipeline
curl -k -X PUT \
  -u "elastic:$ELASTIC_PASSWORD" \
  "$ELASTICSEARCH_URL/_ingest/pipeline/geoip-info" \
  -H "Content-Type: application/json" \
  --fail \
  -d '{
    "description": "Add geoip info",
    "processors": [
      {
        "geoip": {
          "field": "nginx.ingress.client_ip",
          "target_field": "geo",
          "ignore_missing": true
        }
      }
    ]
  }' || exit 1

sleep 2

# Create main pipeline that chains the others
curl -k -X PUT \
  -u "elastic:$ELASTIC_PASSWORD" \
  "$ELASTICSEARCH_URL/_ingest/pipeline/main-pipeline" \
  -H "Content-Type: application/json" \
  --fail \
  -d '{
    "description": "Main pipeline that chains other pipelines",
    "processors": [
      {
        "pipeline": {
          "name": "user-agent-info"
        }
      },
      {
        "pipeline": {
          "name": "geoip-info"
        }
      }
    ]
  }' || exit 1

# Check if pipelines exist
echo "Verifying pipelines..."
curl -k -s -u "elastic:$ELASTIC_PASSWORD" "$ELASTICSEARCH_URL/_ingest/pipeline/user-agent-info" --fail || exit 1
sleep 1
curl -k -s -u "elastic:$ELASTIC_PASSWORD" "$ELASTICSEARCH_URL/_ingest/pipeline/geoip-info" --fail || exit 1
sleep 1
curl -k -s -u "elastic:$ELASTIC_PASSWORD" "$ELASTICSEARCH_URL/_ingest/pipeline/main-pipeline" --fail || exit 1

echo "ElasticSearch post setup process completed successfully."
