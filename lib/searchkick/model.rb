require "searchkick/model/extension"

module Searchkick
  module Model
    def searchkick(options = {})
      raise "Only call searchkick once per model" if respond_to?(:searchkick_index)

      Searchkick.models << self

      cattr_reader :searchkick_options do
        options.dup
      end

      cattr_reader :searchkick_klass do
        self
      end

      class_eval do
        include Searchkick::Model::Extension

        class << self
          alias_method Searchkick.search_method_name, :searchkick_search if Searchkick.search_method_name
          alias_method :reindex, :searchkick_reindex unless method_defined?(:reindex)
        end
      end
    end
  end
end