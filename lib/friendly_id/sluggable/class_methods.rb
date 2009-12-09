require "friendly_id/helpers"

module FriendlyId
  module Sluggable
    module ClassMethods

      include FriendlyId::Helpers

      # Finds a single record using the friendly id, or the record's id.
      def find_one(id_or_name, options) #:nodoc:#

        scope = options.delete(:scope)
        scope = scope.to_param if scope && scope.respond_to?(:to_param)

        if id_or_name.is_a?(Integer) || id_or_name.kind_of?(ActiveRecord::Base)
          return super(id_or_name, options)
        end

        find_options = {:select => "#{self.table_name}.*"}
        find_options[:joins] = :slugs unless Array(options[:include]).include?(:slugs)

        name, sequence = Slug.parse(id_or_name)

        find_options[:conditions] = {
          "#{Slug.table_name}.name"     => name,
          "#{Slug.table_name}.scope"    => scope,
          "#{Slug.table_name}.sequence" => sequence
        }

        if result = with_scope(:find => find_options) { find_initial(options) }
          result.finder_slug_name = id_or_name
          result
        elsif id_or_name.to_i.to_s != id_or_name
          raise ActiveRecord::RecordNotFound
        else
          super id_or_name, options
        end

      rescue ActiveRecord::RecordNotFound => e
        if friendly_id_options[:scope]
          raise ActiveRecord::RecordNotFound.new((scope \
            ? "%s and scope=#{scope}" \
            : "%s; expected scope but got none") % e.message)
        else
          raise
        end
      end

      # Finds multiple records using the friendly ids, or the records' ids.
      def find_some(ids_and_names, options) #:nodoc:#
        slugs, ids = get_slugs_and_ids(ids_and_names, options)

        find_options = {
          :select => "#{self.table_name}.*",
          :conditions =>
            "#{quoted_table_name}.#{primary_key} IN (#{ids.empty? ? 'NULL' : ids.join(',')}) " \
            "OR slugs.id IN (#{slugs.to_s(:db)})"
        }
        find_options[:joins] = :slugs unless Array(options[:include]).include?(:slugs)

        with_scope(:find => find_options) { find_every(options) }.uniq.tap do |results|
          enforce_size!(results, ids_and_names, options)
          assign_finder_slugs(slugs, results)
        end
      end

      def validate_find_options(options) #:nodoc:#
        options.assert_valid_keys([
          :conditions, :include, :joins, :limit, :offset,
          :order, :select, :readonly, :group, :from, :lock, :having, :scope
        ])
      end

      private

      # Assign finder slugs for the results found in find_some_with_friendly
      def assign_finder_slugs(slugs, results) #:nodoc:#
        slugs.each do |slug|
          results.select { |r| r.id == slug.sluggable_id }.each do |result|
            result.send(:finder_slug=, slug)
          end
        end
      end

      # Build arrays of slugs and ids, for the find_some_with_friendly method.
      def get_slugs_and_ids(ids_and_names, options) #:nodoc:#
        scope = options.delete(:scope)
        slugs = []
        ids = []
        ids_and_names.each do |id_or_name|
          name, sequence = Slug.parse id_or_name.to_s
          slug = Slug.find(:first, :conditions => {
            :name           => name,
            :scope          => scope,
            :sequence       => sequence,
            :sluggable_type => base_class.name
          })
          # If the slug was found, add it to the array for later use. If not, and
          # the id_or_name is a number, assume that it is a regular record id.
          slug ? slugs << slug : (ids << id_or_name if id_or_name.to_s =~ /\A\d*\z/)
        end
        return slugs, ids
      end

    end
  end
end
