require "friendly_id/helpers"

module FriendlyId
  module NonSluggable
    module ClassMethods

      include FriendlyId::Helpers

      protected

      def find_one(id, options) #:nodoc:#
        if id.respond_to?(:to_str) && result = send("find_by_#{ friendly_id_options[:method] }", id.to_str, options)
          result.instance_variable_set(:@found_using_friendly_id, true)
          result
        else
          super
        end
      end

      def find_some(ids_and_names, options) #:nodoc:#

        names, ids = ids_and_names.partition {|id_or_name| id_or_name.respond_to?(:to_str) && id_or_name.to_str }
        results = with_scope :find => options do
          find :all, :conditions => ["#{quoted_table_name}.#{primary_key} IN (?) OR #{friendly_id_options[:method]} IN (?)",
            ids, names]
        end

        expected = expected_size(ids_and_names, options)
        if results.size != expected
          raise ActiveRecord::RecordNotFound,
            "Couldn't find all #{ name.pluralize } with IDs (#{ ids_and_names * ', ' }) AND #{ sanitize_sql options[:conditions] } (found #{ results.size } results, but was looking for #{ expected })"
        end

        results.each {|r| r.instance_variable_set(:@found_using_friendly_id, true) if names.include?(r.friendly_id)}

        results

      end

    end
  end
end
