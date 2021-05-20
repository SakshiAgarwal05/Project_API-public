es_config = Rails.configuration.elasticsearch

Elasticsearch::Model.client = Elasticsearch::Client.new(
  url: es_config[:url],
  retry_on_failure: es_config[:retry_on_failure],
  log: es_config[:log]
)

puts "Adding elasticsearch pipeline"

Elasticsearch::Model.client.ingest.put_pipeline :id => 'attachment', :body => {
  description: "Extract attachment information from arrays",
  processors: [
    {
      foreach: {
        field: "attachments",
        processor: {
          attachment: {
            target_field: "_ingest._value.attachment",
            field: "_ingest._value.data"
          }
        }
      }
    }
  ]
}

