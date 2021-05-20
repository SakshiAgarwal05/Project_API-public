module Elasticsearch
  module Model
    module Indexing
      module InstanceMethods
        def update_document(options={})
          if as_indexed_json[:attachment] || as_indexed_json[:attachments]
            begin
              new_options = options.merge({ pipeline: :attachment })
              index_document(new_options)
            rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
              puts "---------attachment not indexed---------"
              puts e

              index_document(options)
            end
          else
            index_document(options)
          end
        end
      end
    end
  end
end
