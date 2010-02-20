module Slog
  
  def self.solr
    @solr ||= RSolr::Ext.connect.extend SolrConnectionAddCallsToSolr
  end
  
  module SolrObject

    def self.included b
      b.extend ClassMethods
    end

    def initialize source
      super source
      each_pair do |k,v|
        self.class.fields.each do |f|
          if f.first.to_s == k.to_s or f.last.to_s == k.to_s
            send "#{f.first}=", v
          else
            # create setters/getters for fields that were not mapped with the #field method
            m = Module.new
            m.instance_eval <<-R
              def #{k}
                self[:#{k}]
              end
              def #{k}= v
                self[:#{k}] = v
              end
            R
            extend m
          end
        end
      end
    end

    def to_solr
      self.class.fields.inject({}) do |doc,f|
        doc.merge(f.last => self.send(f.first))
      end
    end

    module ClassMethods

      def fields
        @fields ||= []
      end

      def field name, solr_field=nil
        fields << [name, (solr_field || name)]
        attr_accessor name
      end

    end

  end

  module SolrConnectionAddCallsToSolr
    def add x, &blk
      super x.respond_to?(:to_solr) ? x.to_solr : x, &blk
    end
  end

  class Post

    include RSolr::Ext::Model
    include SolrObject

    field :id
    field :title
    field :body
    field :model
    field :created_at
    field :updated_at
    field :category
    
    def to_solr
      require 'date'
      require 'time'
      extras = {:model => 'post'}
      if self[:created_at]
        extras[:updated_at] = Time.parse( DateTime.now.to_s ).utc.iso8601
      end
      super.merge extras
    end
    
    def self.find params, &blk
      params[:qt] ||= 'posts'
      super params, &blk
    end
    
    def self.find_by_id id
      find :fq => %(id:"#{id}")
    end

  end
  
end