require "active_support/concern"

module Searchkick
  module Model
    module Extension
      extend ActiveSupport::Concern

      included do
        class_attribute :searchkick_callbacks, instance_accessor: false
        class_attribute :searchkick_index_name, instance_accessor: false

        self.searchkick_callbacks = searchkick_options.fetch(:callbacks, true)
        self.searchkick_index_name = searchkick_options[:index_name] ||
            (searchkick_options[:index_prefix].respond_to?(:call) ?
              proc { [searchkick_options[:index_prefix].call, model_name.plural, Searchkick.env].compact.join("_") }
              : [searchkick_options[:index_prefix], model_name.plural, Searchkick.env].compact.join("_"))

        callback_name = searchkick_callbacks == :async ? :reindex_async : :reindex

        if respond_to?(:after_commit)
          after_commit callback_name, if: proc { self.class.search_callbacks? }
        elsif respond_to?(:after_save)
          after_save callback_name, if: proc { self.class.search_callbacks? }
          after_destroy callback_name, if: proc { self.class.search_callbacks? }
        end

        def reindex
          self.class.searchkick_index.reindex_record(self)
        end unless method_defined?(:reindex)

        def reindex_async
          self.class.searchkick_index.reindex_record_async(self)
        end unless method_defined?(:reindex_async)

        def similar(options = {})
          self.class.searchkick_index.similar_record(self, options)
        end unless method_defined?(:similar)

        def search_data
          respond_to?(:to_hash) ? to_hash : serializable_hash
        end unless method_defined?(:search_data)

        def should_index?
          true
        end unless method_defined?(:should_index?)
      end

      module ClassMethods
        def searchkick_search(term = nil, options = {}, &block)
          searchkick_index.search_model(self, term, options, &block)
        end

        def searchkick_index
          index = searchkick_index_name.respond_to?(:call) ? searchkick_index_name.call : searchkick_index_name
          Searchkick::Index.new(index, searchkick_options)
        end

        def enable_search_callbacks
          self.searchkick_callbacks = true
        end

        def disable_search_callbacks
          self.searchkick_callbacks = false
        end

        def search_callbacks?
          searchkick_callbacks && Searchkick.callbacks?
        end

        def searchkick_reindex(options = {})
          unless options[:accept_danger]
            if (respond_to?(:current_scope) && respond_to?(:default_scoped) && current_scope && current_scope.to_sql != default_scoped.to_sql) ||
              (respond_to?(:queryable) && queryable != unscoped.with_default_scope)
              raise Searchkick::DangerousOperation, "Only call reindex on models, not relations. Pass `accept_danger: true` if this is your intention."
            end
          end
          searchkick_index.reindex_scope(searchkick_klass, options)
        end

        def clean_indices
          searchkick_index.clean_indices
        end

        def searchkick_import(options = {})
          (options[:index] || searchkick_index).import_scope(searchkick_klass)
        end

        def searchkick_create_index
          searchkick_index.create_index
        end

        def searchkick_index_options
          searchkick_index.index_options
        end
      end
    end
  end
end
