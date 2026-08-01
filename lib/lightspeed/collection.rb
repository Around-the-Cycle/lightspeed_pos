# frozen_string_literal: true

# require 'uri'
require 'active_support/core_ext/string'
require 'active_support/core_ext/array/wrap'
# require 'active_support/core_ext/object/blank'

module Lightspeed
  class Collection
    PER_PAGE = 100 # the max page of records returned in a request

    attr_accessor :context, :resources, :next_page_url

    def initialize(context:, attributes: nil)
      self.context = context
      instantiate(attributes)
    end

    def account
      context.account
    end

    def unload
      @resources = {}
    end

    def client
      return context if context.is_a?(Lightspeed::Client)
      account.client
    end

    def first(params: {})
      params = params.merge(limit: 1)
      instantiate(get(params: params)).first
    end

    def size(params: {})
      params = params.merge(count: 1, load_relations: nil)
      params.delete(:sort)
      get(params: params)['@attributes']['count'].to_i
    end
    alias_method :length, :size

    def count(params: {})
      params = params.merge(count: 1, load_relations: nil)
      get(params: params).dig('@attributes', 'count').to_i
    end

    def each_loaded
      @resources ||= {}
      @resources.each_value
    end

    def all_loaded
      each_loaded.to_a
    end

    def first_loaded
      each_loaded.first
    end

    def size_loaded
      @resources.size
    end

    def all(params: {})
      enum_page(params: params).to_a.flatten(1)
    end

    def each_page(per_page: PER_PAGE, params: {}, &block)
      enum_page(per_page: per_page, params: params).each(&block)
    end

    def enum_page(per_page: PER_PAGE, params: {})
      Enumerator.new do |yielder|
        loop do
          resources = page(url: @next_page_url, per_page: per_page, params: params)
          yielder << resources
          raise StopIteration if resources.length < per_page
        end
      end
    end

    def enum(per_page: PER_PAGE, params: {})
      Enumerator.new do |yielder|
        each_page(per_page: per_page, params: params) do |page|
          page.each { |resource| yielder << resource }
        end
      end
    end

    def each(per_page: PER_PAGE, params: {}, &block)
      enum(per_page: per_page, params: params).each(&block)
    end

    def find(id)
      first(params: { resource_class.id_field => id }) || handle_not_found(id)
    end

    def create(attributes = {})
      instantiate(post(body: Yajl::Encoder.encode(attributes))).first
    end

    def update(id, attributes = {})
      instantiate(put(id, body: Yajl::Encoder.encode(attributes))).first
    end

    def destroy(id)
      instantiate(delete(id)).first
    end

    def self.collection_name
      name.demodulize
    end

    def self.resource_name
      collection_name.singularize
    end

    def self.resource_class
      "Lightspeed::#{resource_name}".constantize
    end

    def base_path
      "#{account.base_path}/#{resource_name}"
    end

    def inspect
      "#<#{self.class.name} API#{base_path}>"
    end

    def as_json
      return if all_loaded.empty?
      { resource_name => all_loaded.as_json }
    end
    alias_method :to_h, :as_json

    def to_json
      Yajl::Encoder.encode(as_json)
    end

    def page(url: nil, per_page: PER_PAGE, params: {})
      if !url
        # our first page
        instantiate(get(params: params))
      else
        # a cursor url
        instantiate(get(url: url))
      end
    end

    def load_relations_default
      'all'
    end

    private

    def handle_not_found(id)
      raise Lightspeed::Error::NotFound, "Could not find a #{resource_name} with #{resource_class.id_field}=#{id}"
    end

    def context_params
      if context.class.respond_to?(:id_field) &&
         resource_class.method_defined?(context.class.id_field.to_sym)
        { context.class.id_field => context.id }
      else
        {}
      end
    end

    def instantiate(response)
      return [] unless response.is_a?(Hash)
      @resources ||= {}
      attributes = response["@attributes"]
      @next_page_url = nil
      if attributes
        # API returns "next" => "" (not nil/omitted) when there is no next page, which is
        # truthy in Ruby, so it must be checked for blankness rather than falsiness.
        next_url = attributes["next"]
        @next_page_url = next_url unless next_url.nil? || next_url.empty?
      end
      Array.wrap(response[resource_name]).map do |resource|
        resource = resource_class.new(context: self, attributes: resource)
        @resources[resource.id] = resource
      end
    end

    def resource_class
      self.class.resource_class
    end

    def resource_name
      self.class.resource_name
    end

    def get(params: {}, url: nil)
      if url
        client.get(url: url)
      else
        params = { load_relations: load_relations_default }
          .merge(context_params)
          .merge(params)
          .compact
        client.get(
          path: collection_path,
          params: params
        )
      end
    end

    def post(body:)
      client.post(
        path: collection_path,
        body: body
      )
    end

    def put(id, body:)
      client.put(
        path: resource_path(id),
        body: body
      )
    end

    def delete(id)
      client.delete(
        path: resource_path(id)
      )
    end

    def collection_path
      "#{base_path}.json"
    end

    def resource_path(id)
      "#{base_path}/#{id}.json"
    end
  end
end
