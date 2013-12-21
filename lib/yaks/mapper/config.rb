module Yaks
  class Mapper
    class Config
      include Equalizer.new(:attributes)

      def initialize(attributes = Hamster.list, links = Hamster.list, associations = Hamster.list)
        @attributes   = attributes
        @links        = links
        @associations = associations
        freeze
      end

      def new(updates)
        self.class.new(
          updates.fetch(:attributes)   { attributes   },
          updates.fetch(:links)        { links        },
          updates.fetch(:associations) { associations },
        )
      end

      def attributes(*attrs)
        return @attributes if attrs.empty?
        new(
          attributes: @attributes + attrs.to_list
        )
      end

      def link(rel, template, options = {})
        new(
          links: @links.cons(Link.new(rel, template, options))
        )
      end

      # key
      # embed_style
      # rel
      # (profile)

      def has_one(name, options = {})
        add_association(HasOne, name, options)
      end

      def has_many(name, options = {})
        add_association(HasMany, name, options)
      end

      def add_association(type, name, options = {})
        new(
          associations: @associations.cons(
            type.new(
              name,
              options.fetch(:as) { name },
              options.fetch(:mapper),
              options.fetch(:links) { Yaks::List() }
            )
          )
        )
      end

      def links
        @links
      end

      def associations
        @associations
      end
    end
  end
end
