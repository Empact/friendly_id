module FriendlyId

  module Helpers
    # Calculate expected result size for find_some_with_friendly (taken from
    # active_record/base.rb)
    def expected_size(ids_and_names, options) #:nodoc:#
      size =  ids_and_names.size - (options[:offset] || 0)
      size = options[:limit] if options[:limit] && size > options[:limit]
      size
    end
  end
end
